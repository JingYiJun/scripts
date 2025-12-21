#!/usr/bin/env bash
# 一键初始化 Ubuntu 系统环境
# 步骤：
# 1. 换源为清华 TUNA
# 2. apt 更新升级
# 3. 设置时区 Asia/Shanghai
# 4. 安装 zsh + oh-my-zsh + 常用插件
# 5. 设置 zh_CN.UTF-8 locale

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
  # 优先从 /etc/os-release 读取版本代号
  if [[ -f /etc/os-release ]]; then
    # 尝试读取 VERSION_CODENAME（Ubuntu 使用此字段）
    codename="$(grep -E '^VERSION_CODENAME=' /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' || true)"
    # 如果没有 VERSION_CODENAME，尝试 UBUNTU_CODENAME
    if [[ -z "$codename" ]]; then
      codename="$(grep -E '^UBUNTU_CODENAME=' /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' || true)"
    fi
  fi
  
  # 如果从 /etc/os-release 读取失败，尝试使用 lsb_release
  if [[ -z "$codename" ]]; then
    if command -v lsb_release >/dev/null 2>&1; then
      codename="$(lsb_release -cs 2>/dev/null || true)"
    fi
  fi
  
  # 如果都失败，使用默认值
  if [[ -z "$codename" ]]; then
    codename="noble"
    log_warn "无法检测发行版代号，使用默认值：noble"
  else
    log_info "检测到发行版代号：${codename}"
  fi

  local src="/etc/apt/sources.list"

  if [[ -f "$src" ]]; then
    local i=0
    while [[ -f "${src}.bak.${i}" ]]; do
      ((i++)) || true  # 防止算术表达式失败导致脚本退出
    done
    if cp "$src" "${src}.bak.${i}"; then
      log_ok "已备份原 sources.list 为 ${src}.bak.${i}"
    else
      log_error "备份 sources.list 失败"
      return 1
    fi
  fi

  if cat >"$src" <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-security main restricted universe multiverse
EOF
  then
    log_ok "APT 源已切换到清华 TUNA（${codename}）"
  else
    log_error "写入 sources.list 失败"
    return 1
  fi
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
  local timezone="${TIMEZONE:-Asia/Shanghai}"
  log_info "正在设置时区为 ${timezone} ..."

  # 方案 A：systemd 环境（timedatectl）
  if command -v timedatectl >/dev/null 2>&1; then
    if timedatectl set-timezone "${timezone}" 2>/dev/null; then
      log_ok "时区已设置为 ${timezone}"
      return 0
    fi
    log_warn "timedatectl 设置时区失败，某些环境可能不允许修改时区，尝试不依赖 systemd 的方案"
  fi

  # 方案 B：不依赖 systemd（写 /etc/localtime + /etc/timezone）
  local zoneinfo="/usr/share/zoneinfo/${timezone}"
  if [[ ! -e "${zoneinfo}" ]]; then
    log_warn "未找到时区文件：${zoneinfo}（可能未安装 tzdata），跳过时区设置"
    log_warn "可尝试：apt-get install -y tzdata"
    return 0
  fi

  # /etc/localtime 可能是文件或软链接；用 ln -sf 覆盖即可
  if ln -sf "${zoneinfo}" /etc/localtime 2>/dev/null; then
    log_ok "已设置 /etc/localtime -> ${zoneinfo}"
  else
    log_warn "写入 /etc/localtime 失败（可能是只读文件系统/受限容器），无法持久化设置时区"
    log_warn "临时方案：在当前进程/容器里设置环境变量 TZ=${timezone}"
    return 0
  fi

  # 某些程序会读取 /etc/timezone（Debian/Ubuntu 常见）
  if [[ -w /etc/timezone ]] || [[ ! -e /etc/timezone && -w /etc ]]; then
    echo "${timezone}" >/etc/timezone 2>/dev/null || true
  fi

  log_ok "时区已设置为 ${timezone}（无需 systemd）"
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
    sh -c "$(curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log_ok "oh-my-zsh 安装完成"
  else
    log_info "检测到已安装 oh-my-zsh，跳过安装"
  fi

  # 安装插件
  local zsh_custom="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
  mkdir -p "${zsh_custom}/plugins"

  if [[ ! -d "${zsh_custom}/plugins/zsh-syntax-highlighting" ]]; then
    log_info "正在安装插件 zsh-syntax-highlighting ..."
    git clone https://gh-proxy.org/https://github.com/zsh-users/zsh-syntax-highlighting.git \
      "${zsh_custom}/plugins/zsh-syntax-highlighting"
  else
    log_info "插件 zsh-syntax-highlighting 已存在，跳过"
  fi

  if [[ ! -d "${zsh_custom}/plugins/zsh-autosuggestions" ]]; then
    log_info "正在安装插件 zsh-autosuggestions ..."
    git clone https://gh-proxy.org/https://github.com/zsh-users/zsh-autosuggestions.git \
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
  # 注意：脚本启用了 set -u，$USER 在某些非登录/容器环境可能未定义
  # 优先使用 sudo 传入的原始用户，其次尝试 LOGNAME/USER，最后回退到 id -un
  local target_user="${SUDO_USER:-${LOGNAME:-${USER:-}}}"
  if [[ -z "${target_user}" ]]; then
    target_user="$(id -un)"
  fi
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ -n "$zsh_path" ]]; then
    if chsh -s "$zsh_path" "$target_user" 2>/dev/null; then
      log_ok "已将用户 ${target_user} 的默认 shell 设置为 zsh (${zsh_path})"
    else
      log_warn "chsh 设置默认 shell 失败（可能环境不允许或 /etc/shells 未包含 zsh），请稍后手动执行：chsh -s ${zsh_path} ${target_user}"
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
# 主流程
#######################################
main() {
  check_root

  log_info "开始初始化 Ubuntu 系统环境..."

  change_apt_source_to_tuna
  apt_update_upgrade
  set_timezone
  install_zsh_and_omz
  setup_locale_zh_cn

  log_ok "全部步骤执行完成！建议重新登录终端以生效 zsh / locale 等配置。"
}

main "$@"

