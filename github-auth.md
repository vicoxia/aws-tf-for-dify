# GitHub 身份验证指南

自2021年8月13日起，GitHub不再支持使用密码进行Git操作的身份验证。本指南提供了设置和使用GitHub推荐的身份验证方式的步骤。

## 目录

- [使用个人访问令牌（PAT）](#使用个人访问令牌pat)
- [使用SSH密钥](#使用ssh密钥)
- [使用GitHub CLI](#使用github-cli)
- [使用凭证管理器](#使用凭证管理器)

## 使用个人访问令牌（PAT）

个人访问令牌（Personal Access Token, PAT）是最简单的替代密码的方式。

### 1. 创建个人访问令牌

1. 登录到GitHub
2. 点击右上角的头像，选择"Settings"（设置）
3. 在左侧边栏中，点击"Developer settings"（开发者设置）
4. 在左侧边栏中，点击"Personal access tokens"（个人访问令牌）
5. 点击"Generate new token"（生成新令牌）
6. 给令牌一个描述性的名称
7. 选择令牌的有效期
8. 选择令牌的权限范围（至少需要`repo`权限）
9. 点击"Generate token"（生成令牌）
10. 复制生成的令牌（**重要：这是你唯一能看到令牌的机会**）

### 2. 使用个人访问令牌

当你执行需要身份验证的Git操作时，使用你的个人访问令牌作为密码：

```bash
# 克隆仓库
git clone https://github.com/username/repo.git
# 当提示输入密码时，输入你的个人访问令牌

# 或者，你可以在URL中包含令牌
git clone https://username:personal-access-token@github.com/username/repo.git

# 如果你已经克隆了仓库，可以更新远程URL
git remote set-url origin https://username:personal-access-token@github.com/username/repo.git
```

### 3. 存储凭证

为了避免每次都输入令牌，你可以启用凭证缓存：

```bash
# 缓存凭证（默认15分钟）
git config --global credential.helper cache

# 设置缓存时间（例如，1小时）
git config --global credential.helper 'cache --timeout=3600'

# 或者，在macOS上使用钥匙串
git config --global credential.helper osxkeychain

# 在Windows上使用凭证管理器
git config --global credential.helper manager
```

## 使用SSH密钥

SSH密钥提供了一种更安全的身份验证方式。

### 1. 检查现有的SSH密钥

```bash
ls -la ~/.ssh
```

如果你看到类似`id_rsa.pub`、`id_ecdsa.pub`或`id_ed25519.pub`的文件，你已经有SSH密钥了。

### 2. 生成新的SSH密钥

如果没有现有的SSH密钥，或者你想创建一个新的：

```bash
# 使用Ed25519算法（推荐）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 或者，如果你使用的是不支持Ed25519的旧系统
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

按照提示操作，可以接受默认文件位置，并设置一个安全的密码短语。

### 3. 将SSH密钥添加到ssh-agent

```bash
# 启动ssh-agent
eval "$(ssh-agent -s)"

# 添加SSH私钥
ssh-add ~/.ssh/id_ed25519  # 或 ~/.ssh/id_rsa
```

### 4. 将SSH公钥添加到GitHub账户

1. 复制SSH公钥：

```bash
# 对于Ed25519密钥
cat ~/.ssh/id_ed25519.pub | pbcopy  # macOS
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard  # Linux with xclip
cat ~/.ssh/id_ed25519.pub  # 手动复制输出

# 对于RSA密钥
cat ~/.ssh/id_rsa.pub  # 然后手动复制
```

2. 登录到GitHub
3. 点击右上角的头像，选择"Settings"（设置）
4. 在左侧边栏中，点击"SSH and GPG keys"（SSH和GPG密钥）
5. 点击"New SSH key"（新建SSH密钥）
6. 给密钥一个描述性的标题
7. 将复制的公钥粘贴到"Key"字段
8. 点击"Add SSH key"（添加SSH密钥）

### 5. 测试SSH连接

```bash
ssh -T git@github.com
```

如果看到"Hi username! You've successfully authenticated..."的消息，说明SSH连接成功。

### 6. 使用SSH URL

更新你的仓库URL以使用SSH而不是HTTPS：

```bash
# 检查当前远程URL
git remote -v

# 更改远程URL为SSH
git remote set-url origin git@github.com:username/repo.git

# 验证更改
git remote -v
```

现在，你可以使用SSH进行Git操作，而无需输入密码。

## 使用GitHub CLI

GitHub CLI（命令行界面）提供了一种简单的方式来与GitHub交互。

### 1. 安装GitHub CLI

```bash
# macOS
brew install gh

# Windows
winget install --id GitHub.cli

# Ubuntu/Debian
sudo apt install gh

# Fedora/CentOS
sudo dnf install gh
```

### 2. 认证GitHub CLI

```bash
gh auth login
```

按照提示选择GitHub.com，然后选择HTTPS或SSH协议，并完成身份验证过程。

### 3. 使用GitHub CLI

一旦认证，你可以使用`gh`命令执行各种GitHub操作，包括克隆仓库、创建问题等。

```bash
# 克隆仓库
gh repo clone username/repo

# 创建拉取请求
gh pr create

# 查看问题
gh issue list
```

## 使用凭证管理器

Git凭证管理器可以安全地存储你的凭证。

### 1. 安装Git凭证管理器

```bash
# macOS（已内置）
git config --global credential.helper osxkeychain

# Windows
# 安装Git for Windows时会自动安装凭证管理器

# Linux
sudo apt install libsecret-1-0 libsecret-1-dev
cd /usr/share/doc/git/contrib/credential/libsecret
sudo make
git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
```

### 2. 使用凭证管理器

一旦设置了凭证管理器，当你首次执行需要身份验证的Git操作时，你需要输入你的GitHub用户名和个人访问令牌。之后，凭证管理器会记住这些信息，你就不需要再次输入了。

## 结论

选择适合你的身份验证方式：

- **个人访问令牌**：简单易用，适合临时访问
- **SSH密钥**：更安全，适合长期使用
- **GitHub CLI**：提供全面的GitHub功能
- **凭证管理器**：方便存储凭证

无论选择哪种方式，都比使用密码更安全，并且符合GitHub的最新身份验证要求。
