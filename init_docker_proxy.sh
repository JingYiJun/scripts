#!/usr/bin/env bash
# 配置 Docker 代理设置
# 功能：
# 1. 创建 systemd 服务目录
# 2. 配置 Docker HTTP/HTTPS 代理
# 3. 配置 NO_PROXY 环境变量
# 4. 重载 systemd 并重启 Docker 服务
# 5. 验证配置是否生效

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
# 配置变量
#######################################
DOCKER_SERVICE_DIR="/etc/systemd/system/docker.service.d"
PROXY_CONF_FILE="${DOCKER_SERVICE_DIR}/http-proxy.conf"
HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:7890/}"
HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:7890/}"
NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12}"

#######################################
# 前置检查
#######################################
check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "请使用 root 权限运行此脚本（例如：sudo bash $0）"
    exit 1
  fi
}

check_docker_installed() {
  if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker 未安装，请先安装 Docker"
    exit 1
  fi
  log_ok "检测到 Docker 已安装"
}

check_docker_service() {
  if ! systemctl is-active --quiet docker 2>/dev/null; then
    log_warn "Docker 服务未运行，将尝试启动"
    if systemctl start docker 2>/dev/null; then
      log_ok "Docker 服务已启动"
    else
      log_error "无法启动 Docker 服务，请检查 Docker 安装状态"
      exit 1
    fi
  else
    log_ok "Docker 服务正在运行"
  fi
}

#######################################
# 1. 创建 systemd 服务目录
#######################################
create_service_directory() {
  log_info "正在创建 Docker systemd 服务目录..."
  
  if [[ ! -d "$DOCKER_SERVICE_DIR" ]]; then
    mkdir -p "$DOCKER_SERVICE_DIR"
    log_ok "已创建目录：$DOCKER_SERVICE_DIR"
  else
    log_info "目录已存在：$DOCKER_SERVICE_DIR"
  fi
}

#######################################
# 2. 配置代理配置文件
#######################################
configure_proxy() {
  log_info "正在配置 Docker 代理设置..."
  
  # 备份现有配置文件（如果存在）
  if [[ -f "$PROXY_CONF_FILE" ]]; then
    local backup_file="${PROXY_CONF_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$PROXY_CONF_FILE" "$backup_file"
    log_ok "已备份现有配置文件为：$backup_file"
  fi
  
  # 创建代理配置文件
  cat >"$PROXY_CONF_FILE" <<EOF
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY}"
Environment="HTTPS_PROXY=${HTTPS_PROXY}"
Environment="NO_PROXY=${NO_PROXY}"
EOF
  
  log_ok "代理配置已写入：$PROXY_CONF_FILE"
  log_info "配置内容："
  echo "  HTTP_PROXY=${HTTP_PROXY}"
  echo "  HTTPS_PROXY=${HTTPS_PROXY}"
  echo "  NO_PROXY=${NO_PROXY}"
}

#######################################
# 3. 重载 systemd 并重启 Docker
#######################################
reload_and_restart_docker() {
  log_info "正在重载 systemd 配置..."
  
  if systemctl daemon-reload; then
    log_ok "systemd 配置已重载"
  else
    log_error "systemd 配置重载失败"
    exit 1
  fi
  
  log_info "正在重启 Docker 服务..."
  
  if systemctl restart docker; then
    log_ok "Docker 服务已重启"
  else
    log_error "Docker 服务重启失败"
    exit 1
  fi
  
  # 等待服务启动
  sleep 2
  
  if systemctl is-active --quiet docker; then
    log_ok "Docker 服务运行正常"
  else
    log_error "Docker 服务启动失败，请检查配置"
    exit 1
  fi
}

#######################################
# 4. 验证配置
#######################################
verify_configuration() {
  log_info "正在验证 Docker 代理配置..."
  
  local env_output
  env_output=$(systemctl show --property=Environment docker 2>/dev/null || echo "")
  
  if [[ -z "$env_output" ]]; then
    log_warn "无法获取 Docker 环境变量，请手动验证"
    return
  fi
  
  log_ok "Docker 环境变量配置："
  echo "$env_output" | sed 's/Environment=//' | tr ' ' '\n' | sed 's/^/  /'
  
  # 检查关键环境变量是否存在
  if echo "$env_output" | grep -q "HTTP_PROXY=" && \
     echo "$env_output" | grep -q "HTTPS_PROXY=" && \
     echo "$env_output" | grep -q "NO_PROXY="; then
    log_ok "代理配置验证成功"
  else
    log_warn "部分代理环境变量可能未正确设置"
  fi
}

#######################################
# 主流程
#######################################
main() {
  check_root
  check_docker_installed
  check_docker_service
  
  log_info "开始配置 Docker 代理..."
  log_info "代理地址：HTTP_PROXY=${HTTP_PROXY}, HTTPS_PROXY=${HTTPS_PROXY}"
  log_info "NO_PROXY=${NO_PROXY}"
  
  create_service_directory
  configure_proxy
  reload_and_restart_docker
  verify_configuration
  
  log_ok "Docker 代理配置完成！"
  log_info "提示：如需修改代理地址，可以编辑 $PROXY_CONF_FILE 后执行："
  log_info "  sudo systemctl daemon-reload && sudo systemctl restart docker"
}

main "$@"

