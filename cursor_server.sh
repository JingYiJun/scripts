#!/usr/bin/env bash
# Cursor Remote Server 部署脚本
# 功能：
# - 支持 SSH 别名和 user@host 格式
# - 自动检测远程服务器架构和操作系统
# - 下载并部署 Cursor CLI 和 Server 到远程服务器

set -euo pipefail

#######################################
# 彩色输出
#######################################
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[34m"
COLOR_RESET="\033[0m"

log_info()    { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET}    $*"; }
log_ok()      { echo -e "${COLOR_GREEN}[OK]${COLOR_RESET}      $*"; }
log_warn()    { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET}   $*"; }
log_error()   { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET}  $*" >&2; }

#######################################
# 打印用法
#######################################
print_usage() {
  log_error "参数不正确"
  echo "用法: $0 [选项] <ssh_alias | user@host>"
  echo "  <ssh_alias|user@host>: 目标主机 (必需)"
  echo ""
  echo "选项:"
  echo "  -y, --yes:  跳过确认提示，直接执行"
  echo "  -h, --help:  显示此帮助信息"
  exit 1
}

#######################################
# 前置检查
#######################################
check_command() {
  if ! command -v "$1" &> /dev/null; then
    log_error "命令 '$1' 未找到，请先安装"
    exit 1
  fi
}

check_requirements() {
  check_command "cursor"
  check_command "ssh"
  check_command "scp"
  if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
    log_error "需要安装 wget 或 curl 用于下载文件"
    exit 1
  fi
}

#######################################
# 获取本地 Cursor 版本信息
#######################################
get_cursor_version() {
  log_info "正在获取本地 Cursor 版本信息..."
  
  local version_info
  if ! version_info=$(cursor --version 2>/dev/null); then
    log_error "'cursor' 命令执行失败，请确保 Cursor 已正确安装并位于 PATH 中"
    exit 1
  fi
  
  export CURSOR_VERSION=$(echo "$version_info" | sed -n '1p')
  export CURSOR_COMMIT=$(echo "$version_info" | sed -n '2p')
  export LOCAL_ARCH=$(echo "$version_info" | sed -n '3p')
  
  log_ok "成功获取 Cursor 信息 (版本: ${CURSOR_VERSION}, Commit: ${CURSOR_COMMIT})"
}

#######################################
# 检测远程服务器架构和操作系统
#######################################
detect_remote_arch_and_os() {
  log_info "正在检测远程服务器架构和操作系统..."
  
  local arch_info
  arch_info=$(ssh "$REMOTE_TARGET" "uname -m" 2>/dev/null || echo "")
  
  if [[ -z "$arch_info" ]]; then
    log_error "无法连接到远程服务器或获取架构信息"
    exit 1
  fi
  
  # 将架构映射到 Cursor 支持的格式
  case "$arch_info" in
    x86_64|amd64)
      export REMOTE_ARCH="x64"
      ;;
    aarch64|arm64)
      export REMOTE_ARCH="arm64"
      ;;
    *)
      log_error "不支持的架构: $arch_info"
      log_error "支持的架构: x86_64/amd64 (x64), aarch64/arm64 (arm64)"
      exit 1
      ;;
  esac
  
  # 检测操作系统
  local os_info
  os_info=$(ssh "$REMOTE_TARGET" "uname -s | tr '[:upper:]' '[:lower:]'" 2>/dev/null || echo "")
  
  if [[ -z "$os_info" ]]; then
    log_error "无法获取远程服务器操作系统信息"
    exit 1
  fi
  
  case "$os_info" in
    linux)
      export REMOTE_OS="linux"
      ;;
    darwin)
      export REMOTE_OS="darwin"
      ;;
    *)
      log_warn "检测到操作系统: $os_info，默认使用 linux"
      export REMOTE_OS="linux"
      ;;
  esac
  
  log_ok "远程服务器架构: ${REMOTE_ARCH}, 操作系统: ${REMOTE_OS}"
}

#######################################
# 下载文件到临时目录
#######################################
download_packages() {
  log_info "正在下载 Cursor 服务器包..."
  
  local cli_url="https://cursor.blob.core.windows.net/remote-releases/${CURSOR_COMMIT}/cli-alpine-${REMOTE_ARCH}.tar.gz"
  local vscode_url="https://cursor.blob.core.windows.net/remote-releases/${CURSOR_VERSION}-${CURSOR_COMMIT}/vscode-reh-${REMOTE_OS}-${REMOTE_ARCH}.tar.gz"
  
  log_info "下载 CLI: ${cli_url}"
  if command -v wget &> /dev/null; then
    wget -O "${TMP_DIR}/cursor-cli.tar.gz" "${cli_url}" || {
      log_error "CLI 下载失败"
      exit 1
    }
  else
    curl -L "${cli_url}" -o "${TMP_DIR}/cursor-cli.tar.gz" || {
      log_error "CLI 下载失败"
      exit 1
    }
  fi
  
  log_info "下载 VSCODE Server: ${vscode_url}"
  if command -v wget &> /dev/null; then
    wget -O "${TMP_DIR}/cursor-vscode-server.tar.gz" "${vscode_url}" || {
      log_error "VSCODE Server 下载失败"
      exit 1
    }
  else
    curl -L "${vscode_url}" -o "${TMP_DIR}/cursor-vscode-server.tar.gz" || {
      log_error "VSCODE Server 下载失败"
      exit 1
    }
  fi
  
  log_ok "所有包下载完成"
}

#######################################
# 上传文件到远程服务器
#######################################
upload_packages() {
  log_info "正在上传包到远程服务器..."
  
  scp "${TMP_DIR}/cursor-cli.tar.gz" "${REMOTE_TARGET}:~/.cursor-server/cursor-cli.tar.gz" || {
    log_error "CLI 上传失败"
    exit 1
  }
  
  scp "${TMP_DIR}/cursor-vscode-server.tar.gz" "${REMOTE_TARGET}:~/.cursor-server/cursor-vscode-server.tar.gz" || {
    log_error "VSCODE Server 上传失败"
    exit 1
  }
  
  log_ok "所有包上传完成"
}

#######################################
# 在远程服务器上安装
#######################################
install_on_remote() {
  log_info "正在远程服务器上安装..."
  
  ssh "$REMOTE_TARGET" "
    set -e
    mkdir -p ~/.cursor-server/cli/servers/Stable-${CURSOR_COMMIT}/server/
    tar -xzf ~/.cursor-server/cursor-cli.tar.gz -C ~/.cursor-server/
    mv ~/.cursor-server/cursor ~/.cursor-server/cursor-${CURSOR_COMMIT} || true
    tar -xzf ~/.cursor-server/cursor-vscode-server.tar.gz -C ~/.cursor-server/cli/servers/Stable-${CURSOR_COMMIT}/server/ --strip-components=1
    rm -f ~/.cursor-server/cursor-cli.tar.gz ~/.cursor-server/cursor-vscode-server.tar.gz
  " || {
    log_error "远程安装失败"
    exit 1
  }
  
  log_ok "远程安装完成"
}

#######################################
# 清理临时文件
#######################################
cleanup() {
  log_info "正在清理临时文件..."
  if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
    log_ok "临时目录已删除: ${TMP_DIR}"
  fi
}

#######################################
# 主流程
#######################################
main() {
  local REMOTE_TARGET=""
  local SKIP_CONFIRM=false
  
  # 参数解析
  if [[ "$#" -eq 0 ]]; then
    print_usage
  fi
  
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -y|--yes)
        SKIP_CONFIRM=true
        shift
        ;;
      -h|--help)
        print_usage
        ;;
      -*)
        log_error "未知选项: $1"
        print_usage
        ;;
      *)
        if [[ -n "$REMOTE_TARGET" ]]; then
          log_error "只能指定一个目标主机"
          print_usage
        fi
        REMOTE_TARGET="$1"
        shift
        ;;
    esac
  done
  
  if [[ -z "$REMOTE_TARGET" ]]; then
    print_usage
  fi
  
  # 检查前置条件
  check_requirements
  
  # 获取版本信息
  get_cursor_version
  
  # 检测远程架构和操作系统
  detect_remote_arch_and_os
  
  # 创建临时目录
  TMP_DIR=$(mktemp -d)
  trap cleanup EXIT
  
  # 确认操作
  log_info "--------------------------------------------------"
  log_info "目标主机: ${REMOTE_TARGET}"
  log_info "Cursor 版本: ${CURSOR_VERSION}"
  log_info "Cursor Commit: ${CURSOR_COMMIT}"
  log_info "远程架构: ${REMOTE_ARCH}"
  log_info "远程操作系统: ${REMOTE_OS}"
  log_info "--------------------------------------------------"
  
  if [[ "$SKIP_CONFIRM" = false ]]; then
    read -p "$(echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET}   是否继续? [y/N]: ")" -r confirmation
    
    if [[ ! $confirmation =~ ^[Yy]$ ]]; then
      log_warn "操作已取消"
      exit 0
    fi
  fi
  
  # 执行部署流程
  download_packages
  upload_packages
  install_on_remote
  
  log_ok "Cursor Server 部署完成！"
}

main "$@"
