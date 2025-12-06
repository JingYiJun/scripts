#!/usr/bin/env bash
# 一键初始化 Proxmox VE 上的 Ubuntu 24.04 LXC 容器
# 步骤：
# 1. 换源为清华 TUNA
# 2. apt 更新升级
# 3. 设置时区 Asia/Shanghai
# 4. 安装 zsh + oh-my-zsh + 常用插件
# 5. 设置 zh_CN.UTF-8 locale
# 6. 安装 Docker（使用 TUNA 镜像）
# 7. 下载 pproxy，添加 vpn/dvpn 代理 alias

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
# 前置检查
#######################################
check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "请使用 root 权限运行此脚本（例如：sudo bash $0）"
    exit 1
  fi
}

#######################################
# 1. 换源为清华 TUNA
#######################################
change_apt_source_to_tuna() {
  log_info "正在配置 APT 源为清华 TUNA..."

  local codename
  codename="$(lsb_release -cs 2>/dev/null || echo noble)"

  local src="/etc/apt/sources.list"

  if [[ -f "$src" ]]; then
    local i=0
    while [[ -f "${src}.bak.${i}" ]]; do
      ((i++))
    done
    cp "$src" "${src}.bak.${i}"
    log_ok "已备份原 sources.list 为 ${src}.bak.${i}"
  fi

  cat >"$src" <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-security main restricted universe multiverse
EOF

  log_ok "APT 源已切换到清华 TUNA（${codename}）"
}

#######################################
# 2. 更新系统
#######################################
apt_update_upgrade() {
  log_info "正在执行 apt update && apt upgrade -y ..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y
  log_ok "apt 更新与升级完成"
}

#######################################
# 3. 设置时区为 Asia/Shanghai
#######################################
set_timezone() {
  log_info "正在设置时区为 Asia/Shanghai ..."
  if command -v timedatectl >/dev/null 2>&1; then
    if timedatectl set-timezone Asia/Shanghai 2>/dev/null; then
      log_ok "时区已设置为 Asia/Shanghai"
    else
      log_warn "timedatectl 设置时区失败，LXC 环境可能不允许修改宿主机时区"
    fi
  else
    log_warn "timedatectl 不存在，跳过时区设置"
  fi
}

#######################################
# 4. 安装 zsh + oh-my-zsh + 插件
#######################################
install_zsh_and_omz() {
  log_info "正在安装 zsh / git / curl ..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y zsh git curl

  # 安装 oh-my-zsh（非交互模式）
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    log_info "正在安装 oh-my-zsh ..."
    # 如需走代理，可改成 github.akams.cn 形式
    RUNZSH=no CHSH=no \
    sh -c "$(REMOTE=https://github.akams.cn/https://github.com/ohmyzsh/ohmyzsh curl -fsSL https://github.akams.cn/https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log_ok "oh-my-zsh 安装完成"
  else
    log_info "检测到已安装 oh-my-zsh，跳过安装"
  fi

  # 安装插件
  local zsh_custom="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
  mkdir -p "${zsh_custom}/plugins"

  if [[ ! -d "${zsh_custom}/plugins/zsh-syntax-highlighting" ]]; then
    log_info "正在安装插件 zsh-syntax-highlighting ..."
    git clone https://github.akams.cn/https://github.com/zsh-users/zsh-syntax-highlighting.git \
      "${zsh_custom}/plugins/zsh-syntax-highlighting"
  else
    log_info "插件 zsh-syntax-highlighting 已存在，跳过"
  fi

  if [[ ! -d "${zsh_custom}/plugins/zsh-autosuggestions" ]]; then
    log_info "正在安装插件 zsh-autosuggestions ..."
    git clone https://github.akams.cn/https://github.com/zsh-users/zsh-autosuggestions.git \
      "${zsh_custom}/plugins/zsh-autosuggestions"
  else
    log_info "插件 zsh-autosuggestions 已存在，跳过"
  fi

  # 修改 ~/.zshrc 的 plugins 配置
  local zshrc="${HOME}/.zshrc"
  if [[ ! -f "$zshrc" ]]; then
    log_warn "~/.zshrc 不存在，将创建一个基本配置"
    cat >"$zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)

source $ZSH/oh-my-zsh.sh
EOF
  fi

  if grep -q '^plugins=' "$zshrc"; then
    sed -i 's/^plugins=.*/plugins=(git ssh zsh-syntax-highlighting zsh-autosuggestions)/' "$zshrc"
  else
    echo 'plugins=(git ssh zsh-syntax-highlighting zsh-autosuggestions)' >>"$zshrc"
  fi
  log_ok "~/.zshrc 中 plugins 已设置为：git ssh zsh-syntax-highlighting zsh-autosuggestions"

  # 设置默认 shell 为 zsh
  local target_user="${SUDO_USER:-$USER}"
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ -n "$zsh_path" ]]; then
    if chsh -s "$zsh_path" "$target_user" 2>/dev/null; then
      log_ok "已将用户 ${target_user} 的默认 shell 设置为 zsh (${zsh_path})"
    else
      log_warn "chsh 设置默认 shell 失败（可能 LXC 不允许或 /etc/shells 未包含 zsh），请稍后手动执行：chsh -s ${zsh_path} ${target_user}"
    fi
  fi
}

#######################################
# 5. 设置 zh_CN.UTF-8 locale
#######################################
setup_locale_zh_cn() {
  log_info "正在安装并配置 locale 为 zh_CN.UTF-8 ..."

  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y locales

  # 确保 /etc/locale.gen 中有 zh_CN.UTF-8
  if ! grep -q '^zh_CN.UTF-8 UTF-8' /etc/locale.gen; then
    echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
  fi

  locale-gen zh_CN.UTF-8

  cat >/etc/default/locale <<'EOF'
LANG=zh_CN.UTF-8
LC_CTYPE=zh_CN.UTF-8
LC_ALL=
EOF

  log_ok "locale 已配置为 LANG=zh_CN.UTF-8, LC_CTYPE=zh_CN.UTF-8"
}

#######################################
# 6. 安装 Docker（使用 TUNA Docker 源）
#######################################
install_docker_from_tuna() {
  log_info "正在安装 Docker（使用清华 TUNA Docker 源）..."

  export DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"

  # 使用 github.akams.cn 代理 raw.githubusercontent.com
  if curl -fsSL https://github.akams.cn/https://raw.githubusercontent.com/docker/docker-install/master/install.sh \
    | sh; then
    log_ok "Docker 安装完成"
  else
    log_error "Docker 安装脚本执行失败，请检查网络或稍后手动重试"
  fi
}

#######################################
# 7. 下载 pproxy 并设置 vpn/dvpn alias
#######################################
setup_pproxy_and_alias() {
  log_info "正在下载 pproxy 脚本到 \$HOME ..."

  local proxy_script="${HOME}/proxy.sh"

  if [[ ! -f "$proxy_script" ]]; then
    if wget -O "$proxy_script" \
      "https://github.akams.cn/https://raw.githubusercontent.com/w568w/pproxy/main/proxy.sh"; then
      chmod +x "$proxy_script"
      log_ok "已下载 pproxy 脚本到 $proxy_script"
    else
      log_warn "下载 pproxy 脚本失败，将仅配置环境变量 alias"
    fi
  else
    log_info "检测到已存在 $proxy_script，跳过下载"
  fi

  local zshrc="${HOME}/.zshrc"

  # 这里直接通过 alias 设置代理环境变量，确保：
  # - 代理地址：127.0.0.1:7890
  # - no_proxy 包含内网与回环地址
  local alias_block
  alias_block=$(cat <<'EOF'

# ====== VPN aliases (自动添加 by init-lxc script) ======
vpn() {
  export http_proxy="http://127.0.0.1:7890"
  export https_proxy="http://127.0.0.1:7890"
  export all_proxy="socks5://127.0.0.1:7890"
  # 所有内网和回环都走 no_proxy
  export no_proxy="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
  echo "已开启代理：127.0.0.1:7890"
}

dvpn() {
  unset http_proxy
  unset https_proxy
  unset all_proxy
  unset no_proxy
  echo "已关闭代理环境变量"
}
# ====== END VPN aliases ======
EOF
)

  if ! grep -q 'VPN aliases (自动添加 by init-lxc script)' "$zshrc" 2>/dev/null; then
    echo "$alias_block" >>"$zshrc"
    log_ok "已在 ~/.zshrc 中添加 vpn/dvpn alias"
  else
    log_info "~/.zshrc 中已存在 vpn/dvpn alias，跳过"
  fi
}

#######################################
# 主流程
#######################################
main() {
  check_root

  log_info "开始初始化 Proxmox VE Ubuntu 24.04 LXC 容器环境..."

  change_apt_source_to_tuna
  apt_update_upgrade
  set_timezone
  install_zsh_and_omz
  setup_locale_zh_cn
  install_docker_from_tuna
  setup_pproxy_and_alias

  log_ok "全部步骤执行完成！建议重新登录终端以生效 zsh / locale / alias 等配置。"
}

main "$@"