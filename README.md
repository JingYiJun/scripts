# JingYiJun Scripts 脚本仓库

这个仓库用于备份和分享我的环境配置脚本，方便在不同机器上快速部署和恢复开发环境。

## 📁 脚本列表

- **init_lxc_noble.sh** - 一键初始化 Proxmox VE 上的 Ubuntu 24.04 LXC 容器环境
  - 换源为清华 TUNA
  - 更新系统
  - 设置时区
  - 安装 zsh + oh-my-zsh + 常用插件
  - 配置中文 locale
  - 安装 Docker
  - 配置代理 alias

- **init_ubuntu.sh** - 一键初始化 Ubuntu 系统环境（通用版本）
  - 换源为清华 TUNA
  - 更新系统
  - 设置时区
  - 安装 zsh + oh-my-zsh + 常用插件
  - 配置中文 locale

- **init_docker_proxy.sh** - 配置 Docker 代理设置
  - 创建 systemd 服务目录
  - 配置 HTTP/HTTPS 代理
  - 配置 NO_PROXY 环境变量
  - 重载 systemd 并重启 Docker
  - 验证配置是否生效

- **cursor_server.sh** - Cursor Remote Server 部署脚本
  - 支持 SSH 别名和 user@host 格式
  - 自动检测远程服务器架构和操作系统
  - 下载并部署 Cursor CLI 和 Server 到远程服务器
  - 支持跳过确认提示（-y 选项）

## 📥 如何下载脚本

### 方法一：使用 curl 直接下载并执行

```bash
# 下载并执行 init_lxc_noble.sh
curl -fsSL https://raw.githubusercontent.com/jingyijun/scripts/main/init_lxc_noble.sh | bash

# 镜像
curl -fsSL https://github.akams.cn/https://raw.githubusercontent.com/jingyijun/scripts/main/init_lxc_noble.sh | bash

# 或者先下载到本地再执行
curl -fsSL https://raw.githubusercontent.com/jingyijun/scripts/main/init_lxc_noble.sh -o init_lxc_noble.sh
chmod +x init_lxc_noble.sh
sudo bash init_lxc_noble.sh
```

### 方法二：使用 wget 下载

```bash
# 下载脚本
wget https://raw.githubusercontent.com/jingyijun/scripts/main/init_lxc_noble.sh

# 添加执行权限
chmod +x init_lxc_noble.sh

# 执行脚本（需要 root 权限）
sudo bash init_lxc_noble.sh
```

### 方法三：克隆整个仓库

```bash
# 克隆仓库
git clone https://github.com/jingyijun/scripts.git
cd scripts

# 执行脚本
sudo bash init_lxc_noble.sh
```

## 🔧 脚本使用说明

### init_lxc_noble.sh

用于在 Proxmox VE 的 Ubuntu 24.04 LXC 容器中快速初始化开发环境。

**功能包括：**
- ✅ 配置 APT 源为清华 TUNA 镜像
- ✅ 更新和升级系统包
- ✅ 设置时区为 Asia/Shanghai
- ✅ 安装并配置 zsh、oh-my-zsh 及常用插件
- ✅ 配置中文 locale (zh_CN.UTF-8)
- ✅ 安装 Docker（使用 TUNA 镜像源）
- ✅ 下载 pproxy 并配置 vpn/dvpn 代理 alias

**使用方法：**

```bash
# 需要 root 权限运行
sudo bash init_lxc_noble.sh
```

**注意事项：**
- 脚本需要 root 权限执行
- 部分操作（如设置默认 shell）在 LXC 环境中可能受限
- 执行完成后建议重新登录终端以生效所有配置

### init_ubuntu.sh

用于在 Ubuntu 系统中快速初始化基础开发环境，适用于物理机、虚拟机或容器环境。

**功能包括：**
- ✅ 配置 APT 源为清华 TUNA 镜像
- ✅ 更新和升级系统包
- ✅ 设置时区为 Asia/Shanghai
- ✅ 安装并配置 zsh、oh-my-zsh 及常用插件
- ✅ 配置中文 locale (zh_CN.UTF-8)

**使用方法：**

```bash
# 需要 root 权限运行
sudo bash init_ubuntu.sh
```

**注意事项：**
- 脚本需要 root 权限执行
- 适用于所有 Ubuntu 版本（自动检测发行版代号）
- 部分操作（如设置默认 shell）在某些环境中可能受限
- 执行完成后建议重新登录终端以生效所有配置

### init_docker_proxy.sh

用于配置 Docker 的 HTTP/HTTPS 代理设置，适用于需要通过代理访问 Docker Hub 或其他镜像仓库的场景。

**功能包括：**
- ✅ 创建 Docker systemd 服务配置目录
- ✅ 配置 HTTP_PROXY 和 HTTPS_PROXY 环境变量
- ✅ 配置 NO_PROXY 环境变量（排除内网地址）
- ✅ 自动备份现有配置文件
- ✅ 重载 systemd 并重启 Docker 服务
- ✅ 验证配置是否生效

**使用方法：**

```bash
# 使用默认代理地址（127.0.0.1:7890）
sudo bash init_docker_proxy.sh

# 或通过环境变量自定义代理地址
sudo HTTP_PROXY=http://proxy.example.com:8080/ \
     HTTPS_PROXY=http://proxy.example.com:8080/ \
     NO_PROXY=localhost,127.0.0.1,10.0.0.0/8 \
     bash init_docker_proxy.sh
```

**注意事项：**
- 脚本需要 root 权限执行
- 需要先安装 Docker
- 默认代理地址为 `http://127.0.0.1:7890/`
- 配置完成后会重启 Docker 服务
- 如需修改配置，可编辑 `/etc/systemd/system/docker.service.d/http-proxy.conf`

### cursor_server.sh

用于将 Cursor Remote Server 部署到远程服务器，支持自动检测远程服务器架构和操作系统，并下载对应的 Cursor CLI 和 Server 包。

**功能包括：**
- ✅ 自动获取本地 Cursor 版本信息
- ✅ 自动检测远程服务器架构（x64/arm64）和操作系统（linux/darwin）
- ✅ 下载 Cursor CLI 和 VSCODE Server 包到临时目录
- ✅ 上传并部署到远程服务器
- ✅ 支持 SSH 别名和 user@host 格式
- ✅ 支持跳过确认提示（-y 选项）
- ✅ 自动清理临时文件

**使用方法：**

```bash
# 基本用法（需要确认）
./cursor_server.sh user@host
# 或使用 SSH 别名
./cursor_server.sh my-server

# 跳过确认提示，直接执行
./cursor_server.sh -y user@host
# 或
./cursor_server.sh --yes my-server

# 显示帮助信息
./cursor_server.sh -h
```

**注意事项：**
- 需要本地已安装 Cursor 并可通过 `cursor --version` 获取版本信息
- 需要配置好 SSH 免密登录或使用密码认证
- 远程服务器需要安装 wget 或 curl
- 脚本会自动检测远程服务器架构，支持 x64 和 arm64
- 脚本会自动检测远程操作系统，支持 linux 和 darwin
- 部署路径为 `~/.cursor-server/cli/servers/Stable-{COMMIT}/server/`

## 📝 通用下载格式

所有脚本都可以通过以下格式从 GitHub 直接下载：

```
https://raw.githubusercontent.com/jingyijun/scripts/main/{脚本文件名}
```

例如：
- `https://raw.githubusercontent.com/jingyijun/scripts/main/init_lxc_noble.sh`
- `https://raw.githubusercontent.com/jingyijun/scripts/main/init_ubuntu.sh`
- `https://raw.githubusercontent.com/jingyijun/scripts/main/init_docker_proxy.sh`
- `https://raw.githubusercontent.com/jingyijun/scripts/main/cursor_server.sh`

## 🔗 相关链接

- [GitHub 仓库](https://github.com/jingyijun/scripts)
- [清华 TUNA 镜像站](https://mirrors.tuna.tsinghua.edu.cn/)
- [oh-my-zsh](https://ohmyz.sh/)

## 📄 许可证

本项目采用 [MIT License](LICENSE) 许可证。

Copyright (c) 2025 JingYiJun

