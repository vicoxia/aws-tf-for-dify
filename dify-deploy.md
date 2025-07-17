# Dify 企业版部署手册

本文档提供了在使用Terraform部署的AWS基础设施上，通过Helm部署Dify企业版的详细步骤。

## 目录

- [前提条件](#前提条件)
- [获取访问凭证](#获取访问凭证)
- [准备Helm Chart](#准备helm-chart)
- [配置values.yaml](#配置valuesyaml)
- [部署Dify企业版](#部署dify企业版)
- [验证部署](#验证部署)
- [访问Dify企业版](#访问dify企业版)
- [故障排除](#故障排除)
- [升级和维护](#升级和维护)

## 前提条件

确保已经使用Terraform成功部署了以下AWS资源：

- EKS集群（Kubernetes版本 >= 1.24）
- Aurora PostgreSQL无服务器v2数据库
- ElastiCache Redis
- OpenSearch服务
- S3存储桶

同时，确保本地环境已安装以下工具：

```bash
# 检查kubectl版本
kubectl version --client

# 检查Helm版本（需要v3.x）
helm version

# 确保已配置kubectl访问EKS集群
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# 验证集群连接
kubectl get nodes
```

### 在Amazon Linux 2023上安装Helm

如果您使用的是Amazon Linux 2023，可以按照以下步骤安装Helm：

```bash
# 下载最新版本的Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

# 添加执行权限
chmod 700 get_helm.sh

# 执行安装脚本
./get_helm.sh

# 验证安装
helm version

# 添加常用的Helm仓库
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

或者，您也可以使用以下手动安装方法：

```bash
# 下载最新版本的Helm（替换x.x.x为最新版本号，如3.12.3）
wget https://get.helm.sh/helm-v3.12.3-linux-amd64.tar.gz

# 解压缩
tar -zxvf helm-v3.12.3-linux-amd64.tar.gz

# 移动helm二进制文件到/usr/local/bin
sudo mv linux-amd64/helm /usr/local/bin/helm

# 验证安装
helm version

# 清理下载的文件
rm -rf linux-amd64 helm-v3.12.3-linux-amd64.tar.gz
```

如果您需要特定版本的Helm，请访问[Helm GitHub Releases](https://github.com/helm/helm/releases)页面获取相应版本的下载链接。

## 获取访问凭证

### 1. 获取数据库连接信息

```bash
# 获取Aurora PostgreSQL连接信息
export DB_HOST=$(terraform output -raw rds_endpoint)
export DB_PORT=$(terraform output -raw rds_port)
export DB_NAME=$(terraform output -raw rds_database_name)
export DB_USER=$(terraform output -raw rds_username)
export DB_PASSWORD=$(terraform output -raw rds_password)

echo "数据库连接信息:"
echo "主机: $DB_HOST"
echo "端口: $DB_PORT"
echo "数据库名: $DB_NAME"
echo "用户名: $DB_USER"
```

### 2. 获取Redis连接信息

```bash
# 获取Redis连接信息
export REDIS_HOST=$(terraform output -raw redis_endpoint)
export REDIS_PORT=$(terraform output -raw redis_port)

echo "Redis连接信息:"
echo "主机: $REDIS_HOST"
echo "端口: $REDIS_PORT"
```

### 3. 获取OpenSearch连接信息

```bash
# 获取OpenSearch连接信息
export OPENSEARCH_HOST=$(terraform output -raw opensearch_endpoint)
export OPENSEARCH_USER=$(terraform output -raw opensearch_admin_name)
export OPENSEARCH_PASSWORD=$(terraform output -raw opensearch_password)

echo "OpenSearch连接信息:"
echo "主机: $OPENSEARCH_HOST"
echo "用户名: $OPENSEARCH_USER"
```

### 4. 获取S3存储桶信息

```bash
# 获取S3存储桶信息
export S3_BUCKET=$(terraform output -raw s3_bucket_name)
export AWS_REGION=$(terraform output -raw aws_region)

echo "S3存储桶: $S3_BUCKET"
echo "AWS区域: $AWS_REGION"
```

## 准备Helm Chart

### 1. 添加Dify Helm仓库

```bash
# 添加Dify Helm仓库
helm repo add dify https://langgenius.github.io/dify-helm
helm repo update
```

### 2. 创建命名空间

```bash
# 创建专用命名空间
kubectl create namespace dify
```

### 3. 获取默认values配置

在自定义配置之前，可以先获取Dify Helm Chart的默认values配置：

```bash
# 显示Dify的默认values配置
helm show values dify/dify

# 将默认values配置保存到values.yaml文件中
helm show values dify/dify > values.yaml

# 查看保存的values.yaml文件
cat values.yaml
```

这样您可以查看所有可配置的选项，然后根据需要进行修改。

## 配置values.yaml

创建一个自定义的values.yaml文件：

```bash
# 生成随机密钥
APP_SECRET_KEY=$(openssl rand -hex 32)
INNER_API_KEY=$(openssl rand -hex 32)
ADMIN_API_SECRET_KEY_SALT=$(openssl rand -hex 32)

# 创建自定义values.yaml
cat > values.yaml << EOF
###################################
# 全局配置
###################################
global:
  appSecretKey: '${APP_SECRET_KEY}'
  consoleApiDomain: "console.dify.example.com"  # 替换为您的实际域名
  consoleWebDomain: "console.dify.example.com"  # 替换为您的实际域名
  serviceApiDomain: "api.dify.example.com"      # 替换为您的实际域名
  appApiDomain: "app.dify.example.com"          # 替换为您的实际域名
  appWebDomain: "app.dify.example.com"          # 替换为您的实际域名
  filesDomain: "upload.dify.example.com"        # 替换为您的实际域名
  enterpriseDomain: "enterprise.dify.example.com"  # 替换为您的实际域名

ingress:
  enabled: true
  className: "alb"  # 使用AWS ALB Ingress Controller
  annotations: {
    kubernetes.io/ingress.class: alb,
    alb.ingress.kubernetes.io/scheme: internet-facing,
    alb.ingress.kubernetes.io/target-type: ip,
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]',
    alb.ingress.kubernetes.io/ssl-redirect: '443',
    # 设置文件上传大小限制
    nginx.ingress.kubernetes.io/proxy-body-size: "15m"
  }

api:
  replicas: 3
  serverWorkerAmount: 1
  innerApi:
    apiKey: "${INNER_API_KEY}"
worker:
  replicas: 3
  celeryWorkerAmount: 1
web:
  replicas: 1
sandbox:
  replicas: 1
  apiKey: "${INNER_API_KEY}"
enterpriseAudit:
  replicas: 1
enterprise:
  replicas: 1
  appSecretKey: "${APP_SECRET_KEY}"
  adminAPIsSecretKeySalt: "${ADMIN_API_SECRET_KEY_SALT}"
  innerApi:
    apiKey: "${INNER_API_KEY}"
enterpriseFrontend:
  replicas: 1
ssrfProxy:
  enabled: true
  replicas: 1
unstructured:
  enabled: true
  replicas: 1
plugin_daemon:
  replicas: 1
  apiKey: "${INNER_API_KEY}"
plugin_controller:
  replicas: 1
plugin_connector:
  replicas: 1
  apiKey: "${INNER_API_KEY}"
gateway:
  replicas: 1

###################################
# 持久化存储配置
###################################
persistence:
  type: "s3"
  s3:
    endpoint: ""  # 使用AWS S3默认端点
    accessKey: ""  # 使用IRSA，无需填写
    secretKey: ""  # 使用IRSA，无需填写
    region: "${AWS_REGION}"
    bucketName: "${S3_BUCKET}"
    addressType: ""
    useAwsManagedIam: true
    useAwsS3: true

###################################
# 外部PostgreSQL配置
###################################
externalPostgres:
  enabled: true
  address: "${DB_HOST}"
  port: ${DB_PORT}
  credentials:
    dify:
      database: "${DB_NAME}"
      username: "${DB_USER}"
      password: "${DB_PASSWORD}"
      sslmode: "require"
    plugin_daemon:
      database: "${DB_NAME}_plugin_daemon"
      username: "${DB_USER}"
      password: "${DB_PASSWORD}"
      sslmode: "require"
    enterprise:
      database: "${DB_NAME}_enterprise"
      username: "${DB_USER}"
      password: "${DB_PASSWORD}"
      sslmode: "require"
    audit:
      database: "${DB_NAME}_audit"
      username: "${DB_USER}"
      password: "${DB_PASSWORD}"
      sslmode: "require"

###################################
# 外部Redis配置
###################################
externalRedis:
  enabled: true
  host: "${REDIS_HOST}"
  port: ${REDIS_PORT}
  username: ""
  password: ""  # 如果Redis设置了密码，请填写
  useSSL: false

###################################
# 外部向量数据库配置
###################################
vectorDB:
  useExternal: true
  externalType: "opensearch"
  externalOpensearch:
    endpoint: "https://${OPENSEARCH_HOST}"
    username: "${OPENSEARCH_USER}"
    password: "${OPENSEARCH_PASSWORD}"
    indexName: "dify"

imagePullSecrets: []
EOF

echo "values.yaml文件已创建"
```

> **注意**：请根据您的实际情况修改域名和其他配置。

## 部署Dify企业版

使用Helm安装Dify企业版：

```bash
# 部署Dify
helm upgrade -i dify -f values.yaml dify/dify -n dify
```

## 验证部署

### 1. 检查Pod状态

```bash
# 检查所有Pod是否正常运行
kubectl get pods -n dify

# 检查服务状态
kubectl get services -n dify

# 检查Ingress配置
kubectl get ingress -n dify
```

### 2. 检查日志

如果某个Pod未能正常启动，可以查看其日志：

```bash
# 查看特定Pod的日志
kubectl logs <pod-name> -n dify

# 查看部署事件
kubectl get events -n dify
```

## 访问Dify企业版

### 1. 获取访问地址

```bash
# 获取Ingress地址
kubectl get ingress -n dify

# 或者，如果使用LoadBalancer类型的服务
kubectl get service -n dify
```

### 2. 配置DNS

将您的域名（如console.dify.example.com）指向ALB的地址。

### 3. 访问Dify控制台

在浏览器中访问您配置的域名（如https://console.dify.example.com）。

## 故障排除

### 1. 数据库连接问题

- 检查数据库连接字符串是否正确
- 确认安全组允许从EKS节点到数据库的连接
- 验证数据库用户名和密码

```bash
# 测试数据库连接
kubectl run -it --rm --image=postgres:14 postgres-client -- psql -h $DB_HOST -U $DB_USER -d $DB_NAME
```

### 2. Redis连接问题

- 检查Redis连接信息是否正确
- 确认安全组允许从EKS节点到Redis的连接

```bash
# 测试Redis连接
kubectl run -it --rm --image=redis:7 redis-client -- redis-cli -h $REDIS_HOST -p $REDIS_PORT
```

### 3. OpenSearch连接问题

- 检查OpenSearch连接信息是否正确
- 确认安全组允许从EKS节点到OpenSearch的连接

```bash
# 测试OpenSearch连接
kubectl run -it --rm --image=curlimages/curl curl-client -- curl -u "${OPENSEARCH_USER}:${OPENSEARCH_PASSWORD}" https://$OPENSEARCH_HOST
```

### 4. S3访问问题

- 确认EKS节点有权限访问S3存储桶
- 检查IAM角色和策略配置

```bash
# 检查S3存储桶是否可访问
kubectl run -it --rm --image=amazon/aws-cli aws-cli -- aws s3 ls s3://$S3_BUCKET
```

### 5. Ingress问题

- 检查ALB Ingress Controller是否正常运行
- 验证Ingress资源配置是否正确

```bash
# 检查ALB Ingress Controller状态
kubectl get pods -n kube-system | grep alb-ingress-controller
```

## 升级和维护

### 1. 升级Dify版本

```bash
# 更新Helm仓库
helm repo update

# 升级Dify
helm upgrade dify -f values.yaml dify/dify -n dify
```

### 2. 备份数据

定期备份重要数据：

```bash
# 备份数据库
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > dify_backup_$(date +%Y%m%d).sql

# 备份S3数据
aws s3 sync s3://$S3_BUCKET s3://$S3_BUCKET-backup
```

### 3. 监控

设置监控和告警：

```bash
# 部署Prometheus和Grafana（可选）
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### 4. 扩展资源

根据负载情况扩展资源：

```bash
# 扩展API副本数
kubectl scale deployment dify-api -n dify --replicas=5

# 或者通过更新values.yaml并重新部署
# 修改values.yaml中的replicas值，然后运行：
helm upgrade dify -f values.yaml dify/dify -n dify
```

## 结论

现在您已经成功在AWS上部署了Dify企业版。请确保定期更新和维护您的部署，以保持系统的安全性和稳定性。

如需更多帮助，请参考[Dify官方文档](https://docs.dify.ai/)或联系Dify支持团队。
