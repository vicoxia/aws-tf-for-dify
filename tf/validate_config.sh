#!/bin/bash

# Dify Helm配置验证脚本

echo "🔍 验证Dify Helm配置..."

# 检查必需文件
echo "📁 检查文件结构..."

if [ ! -f "helm-values/values.yaml" ]; then
    echo "❌ 错误: helm-values/values.yaml 文件不存在"
    exit 1
fi

if [ -f "helm-values/dify-values.yaml" ]; then
    echo "❌ 错误: helm-values/dify-values.yaml 文件仍然存在，应该已被删除"
    exit 1
fi

if [ -f "helm-values/dify-ee-values.yaml" ]; then
    echo "❌ 错误: helm-values/dify-ee-values.yaml 文件仍然存在，应该已被删除"
    exit 1
fi

echo "✅ 文件结构正确"

# 检查values.yaml文件内容
echo "📄 检查values.yaml文件内容..."

if ! grep -q "global:" helm-values/values.yaml; then
    echo "❌ 错误: values.yaml 缺少global配置段"
    exit 1
fi

if ! grep -q "enterprise:" helm-values/values.yaml; then
    echo "❌ 错误: values.yaml 缺少enterprise配置"
    exit 1
fi

if ! grep -q "plugin_daemon:" helm-values/values.yaml; then
    echo "❌ 错误: values.yaml 缺少plugin_daemon配置"
    exit 1
fi

if ! grep -q "externalPostgres:" helm-values/values.yaml; then
    echo "❌ 错误: values.yaml 缺少externalPostgres配置"
    exit 1
fi

echo "✅ values.yaml 内容验证通过"

# 检查terraform文件
echo "🔧 检查terraform配置..."

if grep -q "dify_helm_values" *.tf; then
    echo "❌ 错误: terraform文件中仍然引用了已删除的变量 dify_helm_values"
    exit 1
fi

if grep -q "dify_ee_helm" *.tf; then
    echo "❌ 错误: terraform文件中仍然引用了已删除的变量 dify_ee_helm*"
    exit 1
fi

if grep -q "install_dify_ee_plugins" *.tf; then
    echo "❌ 错误: terraform文件中仍然引用了已删除的变量 install_dify_ee_plugins"
    exit 1
fi

if ! grep -q 'values = \[file("${path.module}/helm-values/values.yaml")\]' helm.tf; then
    echo "❌ 错误: helm.tf 中的values配置不正确"
    exit 1
fi

echo "✅ terraform配置验证通过"

# 检查必需的变量
echo "🔑 检查必需变量..."

required_vars=(
    "dify_app_secret_key"
    "dify_admin_api_secret_key_salt"
    "dify_sandbox_api_key"
    "dify_inner_api_key"
    "dify_plugin_inner_api_key"
)

for var in "${required_vars[@]}"; do
    if ! grep -q "variable \"$var\"" variables.tf; then
        echo "❌ 错误: 缺少必需变量 $var"
        exit 1
    fi
done

echo "✅ 必需变量验证通过"

# 检查helm.tf中的关键配置
echo "⚙️  检查helm配置..."

key_configs=(
    "global.edition"
    "global.appSecretKey"
    "externalPostgres.enabled"
    "enterprise.enabled"
    "plugin_daemon.enabled"
    "plugin_controller.replicas"
    "plugin_connector.replicas"
)

for config in "${key_configs[@]}"; do
    if ! grep -q "name.*=.*\"$config\"" helm.tf; then
        echo "❌ 错误: helm.tf 中缺少关键配置 $config"
        exit 1
    fi
done

echo "✅ helm配置验证通过"

echo ""
echo "🎉 所有验证通过！配置已正确更新。"
echo ""
echo "📋 下一步操作:"
echo "1. 设置必需的环境变量:"
echo "   export TF_VAR_dify_app_secret_key=\"\$(openssl rand -base64 42)\""
echo "   export TF_VAR_dify_admin_api_secret_key_salt=\"\$(openssl rand -base64 32)\""
echo "   export TF_VAR_dify_sandbox_api_key=\"\$(openssl rand -base64 32)\""
echo "   export TF_VAR_dify_inner_api_key=\"\$(openssl rand -base64 32)\""
echo ""
echo "2. 运行terraform验证:"
echo "   terraform init"
echo "   terraform validate"
echo "   terraform plan"
echo ""
echo "3. 应用配置:"
echo "   terraform apply"