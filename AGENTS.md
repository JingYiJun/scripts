# Repository Guidelines

## Project Structure & Module Organization
仓库采用扁平结构：根目录仅包含 `init_lxc_noble.sh`, `init_ubuntu.sh`, `init_docker_proxy.sh`, `cursor_server.sh`，以及 `README.md` 与 `LICENSE`。所有新增脚本都应位于根目录，命名为清晰的小写蛇形加 `.sh`（如 `install_cursor_agent.sh`），并在 README 的“脚本列表”内追加条目，描述用途和关键步骤。若脚本依赖临时资产，请将文件放在 `/tmp` 或脚本内部动态创建的目录，并在结束时清理。

## Build, Test, and Development Commands
本仓库没有复杂的构建流程，直接执行脚本即可：`bash init_ubuntu.sh` 负责通用初始化，`sudo bash init_docker_proxy.sh` 需要 root 以写入 systemd，`sudo bash init_lxc_noble.sh` 用于 Proxmox LXC。远程快速复用可用 `curl -fsSL https://raw.githubusercontent.com/jingyijun/scripts/main/init_ubuntu.sh | bash`；在国内网络环境中可替换为 `github.akams.cn` 镜像。提交前务必运行 `shellcheck *.sh` 捕获引用、未定义变量和可移植性问题。

## Coding Style & Naming Conventions
所有脚本以 `#!/usr/bin/env bash` 开头，并紧随 `set -euo pipefail`。函数、变量、文件统一使用小写蛇形命名，示例：`setup_locale_zh_cn`, `log_warn`, `docker_proxy_url`。日志输出复用 `log_info`, `log_warn`, `log_error` 之类函数，保持颜色与格式一致。缩进使用两个空格或单个制表保持一致，不要混合。访问外部安装器优先使用 TUNA 或 `github.akams.cn` 镜像，并为可配置参数暴露环境变量以避免硬编码。

## Testing Guidelines
当前缺少自动化测试，需在目标环境手动演练。每个脚本在 README 或 PR 中附上复现命令（如 `sudo bash init_docker_proxy.sh`），并记录关键验证：`timedatectl status` 确认时区、`docker info` 验证代理、`cursor --version` 校验远程部署。若 LXC 与物理机行为不同，请记录 TODO 或兼容性说明，必要时在脚本中加入条件分支并打印提示。

## Commit & Pull Request Guidelines
提交信息采用祈使句并包含作用域，例如 `init: refresh noble defaults` 或 `cursor: retry uploads on failure`。PR 描述需覆盖目的、关键改动、手动测试记录（含 `shellcheck` 和脚本执行输出），以及远程部署日志或截图；如关联 issue，请在正文引用。拒绝混入无关格式化更改，必要调整请单独提交以便审核。

## Security & Configuration Tips
多数脚本需 root 或免密 sudo，请在文件顶部说明，并尽量避免交互式输入。文档中的代理、主机地址使用占位符（如 `proxy.example.com`）代替真实值；若脚本失败，提示用户清理临时目录（`~/.cursor-server/` 等）以免遗留。处理用户凭据时只依赖环境变量或现有配置，不要写入明文文件。
