#!/usr/bin/env bash
#
# ecs-secops.sh
#
# 阿里云 ECS 主机侧初始化与安全检查工具（MVP）。
#
# 设计原则：
# 1. 默认只处理“主机内”的用户、SSH、sudo、auditd 等配置；云侧安全组、ActionTrail、SLS 需要另行用控制台或 aliyun CLI 核验。
# 2. 初始化和检查分离：check 不做任何修改；init-target / user-add 才会修改系统。
# 3. 支持 --dry-run：只打印将要执行的动作，不实际修改。
# 4. SSH 收敛是高风险操作：默认写入配置但不重启 sshd，除非显式传入 --restart-sshd。
# 5. 所有危险动作尽量通过确认提示保护；自动化流水线可使用 --yes 跳过交互确认。
#
# 典型用法：
#   ./ecs-secops.sh check --role target
#   ./ecs-secops.sh init-target --user xugw --pubkey-file ./xugw.pub --dry-run
#   ./ecs-secops.sh init-target --user xugw --pubkey-file ./xugw.pub --restart-sshd
#   ./ecs-secops.sh user-add --user xugw --pubkey-file ./xugw.pub --groups ops,app
#
# 注意：
# - 建议先在目标 ECS 的现有 SSH 会话内执行，不要断开当前会话。
# - init-target 只面向“目标业务 ECS”，不是跳板机。
# - 跳板机与目标机的 AllowTcpForwarding 基线不同：目标机通常 no，跳板机通常 yes。

set -Eeuo pipefail

VERSION="0.1.0"
COMMAND="${1:-help}"
[[ $# -gt 0 ]] && shift || true

ROLE="target"
USERNAME=""
PUBKEY_FILE=""
GROUPS="ops"
HOSTNAME_TO_SET=""
REPORT_FILE=""
DRY_RUN=0
YES=0
INSTALL_PACKAGES=0
RESTART_SSHD=0
NO_SSHD_CHANGE=0

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
ecs-secops.sh - 阿里云 ECS 主机侧初始化与安全检查工具

用法：
  ecs-secops.sh check --role target|jump [--report ./report.md]
  ecs-secops.sh init-target --user USER --pubkey-file FILE [--hostname HOST] [--restart-sshd] [--dry-run] [--yes]
  ecs-secops.sh user-add --user USER --pubkey-file FILE [--groups ops,app] [--dry-run] [--yes]
  ecs-secops.sh help

命令：
  check        只检查，不修改。输出 Markdown 报告。
  init-target 目标业务 ECS 初始化：基础用户、ops 组、sudoers、目标机 sshd 基线。
  user-add    新增或更新人员账号、公钥、组归属。

常用参数：
  --role ROLE          check 使用。target=目标业务 ECS；jump=跳板机。
  --user USER          要创建或维护的 Linux 用户。
  --pubkey-file FILE   SSH 公钥文件。必须是 .pub 内容，不要传私钥。
  --groups LIST        user-add 使用，逗号分隔，例如 ops,app。默认 ops。
  --hostname HOST      init-target 可选，设置主机名。
  --report FILE        check 报告输出路径。
  --install-packages   init-target 可选，安装常用基础工具。默认不更新/安装，避免无意变更。
  --restart-sshd       init-target 可选，sshd -t 成功后重启 sshd。默认不重启，避免锁出。
  --no-sshd-change     init-target 可选，不写入 sshd 基线配置。
  --dry-run            只打印动作，不实际执行。
  --yes                跳过交互确认。
  -h, --help           显示帮助。

重要提醒：
  1. init-target 执行前，请确认新账号公钥可用，并保留当前 SSH 会话。
  2. 默认不做云侧安全组、ActionTrail、SLS 自动检查；这些会在报告里列为人工核验项。
  3. 目标业务 ECS 的 SSH 基线会设置 AllowTcpForwarding no；跳板机不要使用 init-target。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --role=*) ROLE="${1#*=}"; shift ;;
    --user) USERNAME="${2:-}"; shift 2 ;;
    --user=*) USERNAME="${1#*=}"; shift ;;
    --pubkey-file) PUBKEY_FILE="${2:-}"; shift 2 ;;
    --pubkey-file=*) PUBKEY_FILE="${1#*=}"; shift ;;
    --groups) GROUPS="${2:-}"; shift 2 ;;
    --groups=*) GROUPS="${1#*=}"; shift ;;
    --hostname) HOSTNAME_TO_SET="${2:-}"; shift 2 ;;
    --hostname=*) HOSTNAME_TO_SET="${1#*=}"; shift ;;
    --report) REPORT_FILE="${2:-}"; shift 2 ;;
    --report=*) REPORT_FILE="${1#*=}"; shift ;;
    --install-packages) INSTALL_PACKAGES=1; shift ;;
    --restart-sshd) RESTART_SSHD=1; shift ;;
    --no-sshd-change) NO_SSHD_CHANGE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) COMMAND="help"; shift ;;
    *) fail "未知参数：$1。执行 ecs-secops.sh help 查看用法。" ;;
  esac
done

confirm() {
  local msg="$1"
  if [[ "$YES" -eq 1 ]]; then
    return 0
  fi
  printf '%s [y/N]: ' "$msg" >&2
  local ans=""
  read -r ans || true
  [[ "$ans" == "y" || "$ans" == "Y" || "$ans" == "yes" || "$ans" == "YES" ]]
}

# 用 root 权限执行简单命令。dry-run 时只打印，不执行。
root_argv() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run root]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# 用 root 权限执行 shell 片段。仅用于需要管道、重定向或条件判断的场景。
root_shell() {
  local script="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run root-shell] %s\n' "$script"
    return 0
  fi
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    bash -lc "$script"
  else
    sudo bash -lc "$script"
  fi
}

require_user_and_key() {
  [[ -n "$USERNAME" ]] || fail "缺少 --user USER"
  [[ -n "$PUBKEY_FILE" ]] || fail "缺少 --pubkey-file FILE"
  [[ -f "$PUBKEY_FILE" ]] || fail "公钥文件不存在：$PUBKEY_FILE"
  grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)' "$PUBKEY_FILE" || \
    fail "公钥文件格式不像 SSH 公钥，请确认不要传私钥：$PUBKEY_FILE"
}

read_pubkey() {
  # 只取第一行非空内容；authorized_keys 多行管理可在后续版本增强。
  awk 'NF {print; exit}' "$PUBKEY_FILE"
}

ensure_group() {
  local group="$1"
  if getent group "$group" >/dev/null 2>&1; then
    log "组已存在：$group"
  else
    log "创建组：$group"
    root_argv groupadd "$group"
  fi
}

ensure_user() {
  local user="$1"
  if id "$user" >/dev/null 2>&1; then
    log "用户已存在：$user"
  else
    log "创建用户：$user"
    root_argv useradd -m -s /bin/bash "$user"
    warn "用户 $user 已创建；如需 sudo 交互提权，请执行：sudo passwd $user"
  fi
}

add_user_to_group() {
  local user="$1"
  local group="$2"
  ensure_group "$group"
  log "将用户 $user 加入组 $group"
  root_argv usermod -aG "$group" "$user"
}

install_authorized_key() {
  local user="$1"
  local key="$2"
  local home_dir=""
  home_dir="$(getent passwd "$user" | cut -d: -f6)"
  [[ -n "$home_dir" ]] || fail "无法获取用户家目录：$user"

  log "配置 $user 的 authorized_keys"
  root_argv install -d -m 700 -o "$user" -g "$user" "$home_dir/.ssh"
  root_argv touch "$home_dir/.ssh/authorized_keys"
  root_argv chown "$user:$user" "$home_dir/.ssh/authorized_keys"
  root_argv chmod 600 "$home_dir/.ssh/authorized_keys"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run root-shell] append public key to %s/.ssh/authorized_keys if absent\n' "$home_dir"
  else
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
      grep -qxF "$key" "$home_dir/.ssh/authorized_keys" || printf '%s\n' "$key" >> "$home_dir/.ssh/authorized_keys"
    else
      sudo sh -c 'grep -qxF "$1" "$2" || printf "%s\n" "$1" >> "$2"' sh "$key" "$home_dir/.ssh/authorized_keys"
    fi
  fi

  root_argv chown "$user:$user" "$home_dir/.ssh/authorized_keys"
  root_argv chmod 600 "$home_dir/.ssh/authorized_keys"
}

write_root_file() {
  local path="$1"
  local mode="$2"
  local content="$3"
  local tmp=""
  tmp="$(mktemp)"
  printf '%s' "$content" > "$tmp"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run write] %s mode=%s\n' "$path" "$mode"
    sed 's/^/  | /' "$tmp"
    rm -f "$tmp"
    return 0
  fi

  root_argv cp "$tmp" "$path"
  root_argv chmod "$mode" "$path"
  rm -f "$tmp"
}

ensure_ops_sudoers() {
  local content
  content='%ops ALL=(ALL) ALL
'
  log "写入 sudoers：/etc/sudoers.d/ops"
  write_root_file "/etc/sudoers.d/ops" "440" "$content"
  log "校验 sudoers"
  root_argv visudo -cf /etc/sudoers.d/ops
}

maybe_set_hostname() {
  if [[ -n "$HOSTNAME_TO_SET" ]]; then
    log "设置主机名：$HOSTNAME_TO_SET"
    root_argv hostnamectl set-hostname "$HOSTNAME_TO_SET"
  fi
}

maybe_install_packages() {
  if [[ "$INSTALL_PACKAGES" -ne 1 ]]; then
    log "跳过系统更新和基础包安装；如需执行，请传入 --install-packages"
    return 0
  fi
  warn "即将执行系统包更新/安装，可能影响运行中服务。"
  confirm "确认执行 dnf/yum update/install？" || fail "用户取消包安装。"

  if command -v dnf >/dev/null 2>&1; then
    root_argv dnf update -y
    root_argv dnf install -y sudo vim curl wget rsync git tar unzip lsof net-tools bind-utils bash-completion
  elif command -v yum >/dev/null 2>&1; then
    root_argv yum update -y
    root_argv yum install -y sudo vim curl wget rsync git tar unzip lsof net-tools bind-utils bash-completion
  else
    warn "未找到 dnf/yum，跳过包安装。"
  fi
}

write_target_sshd_baseline() {
  local conf_dir="/etc/ssh/sshd_config.d"
  local conf_file="$conf_dir/99-ecs-baseline.conf"
  local content

  content='# Managed by ecs-secops.sh for target business ECS.
# Do not use this target baseline on a jump host.
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes

AllowGroups ops
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no

LogLevel VERBOSE
SyslogFacility AUTHPRIV
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
'

  warn "准备写入目标业务 ECS sshd 基线：$conf_file"
  warn "请确认这不是跳板机；目标业务 ECS 通常应设置 AllowTcpForwarding no。"
  confirm "确认写入 sshd 目标机基线配置？" || fail "用户取消 sshd 配置写入。"

  root_argv mkdir -p "$conf_dir"

  if [[ -f "$conf_file" ]]; then
    local backup="${conf_file}.bak.$(date '+%Y%m%d%H%M%S')"
    log "备份已有 sshd 基线配置：$backup"
    root_argv cp "$conf_file" "$backup"
  fi

  # 如果主配置没有 Include，则追加 Include。注意：sshd 对部分参数按第一个生效值处理，
  # 若主文件前面已有同名显式配置，目录配置可能无法覆盖；报告/check 会提示最终生效值。
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run root-shell] ensure Include /etc/ssh/sshd_config.d/*.conf in /etc/ssh/sshd_config\n'
  else
    if ! root_shell "grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config.d/\\*.conf' /etc/ssh/sshd_config"; then
      warn "/etc/ssh/sshd_config 未发现 Include，将在文件末尾追加。"
      root_shell "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date '+%Y%m%d%H%M%S') && printf '\nInclude /etc/ssh/sshd_config.d/*.conf\n' >> /etc/ssh/sshd_config"
    fi
  fi

  write_root_file "$conf_file" "600" "$content"

  warn "如主配置文件中已有同名显式项，可能影响目录配置生效。建议执行 check 查看 sshd -T 最终值。"
  log "校验 sshd 配置语法"
  root_argv sshd -t

  if [[ "$RESTART_SSHD" -eq 1 ]]; then
    warn "即将重启 sshd。请确认当前会话不要断开，并已验证新账号可登录。"
    confirm "确认重启 sshd？" || fail "用户取消 sshd 重启。"
    if root_argv systemctl restart sshd; then
      root_argv systemctl status sshd --no-pager || true
    else
      # 部分发行版服务名为 ssh。
      warn "systemctl restart sshd 失败，尝试 systemctl restart ssh"
      root_argv systemctl restart ssh
      root_argv systemctl status ssh --no-pager || true
    fi
  else
    warn "已写入并通过 sshd -t 校验，但未重启 sshd。确认可登录后，可手工执行：sudo systemctl restart sshd"
  fi
}

cmd_user_add() {
  require_user_and_key
  local key
  key="$(read_pubkey)"

  warn "将维护本机用户、公钥和组归属：user=$USERNAME groups=$GROUPS"
  confirm "确认继续？" || fail "用户取消。"

  ensure_user "$USERNAME"

  local group
  IFS=',' read -ra group_arr <<< "$GROUPS"
  for group in "${group_arr[@]}"; do
    group="$(printf '%s' "$group" | xargs)"
    [[ -n "$group" ]] && add_user_to_group "$USERNAME" "$group"
  done

  install_authorized_key "$USERNAME" "$key"

  log "用户维护完成。建议验证：id $USERNAME && sudo -l -U $USERNAME"
  warn "如果这是新用户，请记得设置本地密码以支持 sudo 提权：sudo passwd $USERNAME"
}

cmd_init_target() {
  require_user_and_key
  warn "init-target 仅适用于目标业务 ECS，不适用于跳板机。"
  warn "建议先确认云侧安全组已收口：22 端口只允许跳板机/PAM/VPN/办公出口等受控来源。"
  confirm "确认在当前主机执行目标 ECS 初始化？" || fail "用户取消。"

  maybe_set_hostname
  root_argv timedatectl set-timezone Asia/Shanghai
  maybe_install_packages

  # 复用 user-add 逻辑：创建个人账号、加入 ops 组、下发公钥。
  local key
  key="$(read_pubkey)"
  ensure_group "ops"
  ensure_user "$USERNAME"
  add_user_to_group "$USERNAME" "ops"
  install_authorized_key "$USERNAME" "$key"
  ensure_ops_sudoers

  if [[ "$NO_SSHD_CHANGE" -eq 1 ]]; then
    warn "根据 --no-sshd-change，跳过 sshd 基线写入。"
  else
    write_target_sshd_baseline
  fi

  log "初始化步骤完成。建议立即执行：$0 check --role target"
}

command_output() {
  local cmd="$1"
  bash -lc "$cmd" 2>&1 || true
}

status_from_bool() {
  if [[ "$1" -eq 0 ]]; then printf '通过'; else printf '不通过'; fi
}

add_row() {
  local item="$1" result="$2" evidence="$3" advice="$4"
  REPORT_ROWS+="| ${item} | ${result} | ${evidence} | ${advice} |\n"
}

cmd_check() {
  [[ "$ROLE" == "target" || "$ROLE" == "jump" ]] || fail "--role 只支持 target 或 jump"

  local host now sshd_t sshd_test service_status audit_status sudo_conf ops_group users_over_1000 secure_tail time_info
  host="$(hostname 2>/dev/null || printf unknown)"
  now="$(date '+%F %T')"
  if [[ -z "$REPORT_FILE" ]]; then
    REPORT_FILE="ecs-secops-report-${host}-$(date '+%Y%m%d%H%M%S').md"
  fi

  log "执行只读检查：role=$ROLE report=$REPORT_FILE"

  sshd_test="$(command_output 'sudo sshd -t')"
  sshd_t="$(command_output 'sudo sshd -T')"
  service_status="$(command_output 'systemctl is-active sshd || systemctl is-active ssh')"
  audit_status="$(command_output 'systemctl is-active auditd')"
  sudo_conf="$(command_output "sudo grep -R -E 'log_input|log_output|iolog_dir|use_pty' /etc/sudoers /etc/sudoers.d 2>/dev/null")"
  ops_group="$(command_output 'getent group ops')"
  users_over_1000="$(command_output "awk -F: '\$3>=1000 {print \$1 ':' \$3 ':' \$7}' /etc/passwd")"
  secure_tail="$(command_output 'sudo tail -n 30 /var/log/secure')"
  time_info="$(command_output 'timedatectl')"

  get_sshd_value() {
    local key="$1"
    awk -v k="$key" '$1==k {print $2; exit}' <<< "$sshd_t"
  }

  REPORT_ROWS=""
  local v result

  [[ -z "$sshd_test" ]] && result="通过" || result="不通过"
  add_row "sshd 配置语法" "$result" "\`sudo sshd -t\`" "不通过时先修复 sshd 配置，避免重启锁出。"

  v="$(get_sshd_value permitrootlogin)"
  [[ "$v" == "no" ]] && result="通过" || result="不通过"
  add_row "禁止 root SSH" "$result" "permitrootlogin=${v:-未获取}" "设置 PermitRootLogin no。"

  v="$(get_sshd_value passwordauthentication)"
  [[ "$v" == "no" ]] && result="通过" || result="不通过"
  add_row "禁止密码 SSH 登录" "$result" "passwordauthentication=${v:-未获取}" "设置 PasswordAuthentication no，并确认公钥链路可用。"

  v="$(get_sshd_value pubkeyauthentication)"
  [[ "$v" == "yes" ]] && result="通过" || result="不通过"
  add_row "启用公钥登录" "$result" "pubkeyauthentication=${v:-未获取}" "设置 PubkeyAuthentication yes。"

  v="$(get_sshd_value loglevel)"
  [[ "$v" == "VERBOSE" || "$v" == "verbose" ]] && result="通过" || result="部分通过"
  add_row "SSH 详细日志" "$result" "loglevel=${v:-未获取}" "建议设置 LogLevel VERBOSE，便于审计公钥指纹和登录行为。"

  local allowgroups allowusers
  allowgroups="$(get_sshd_value allowgroups)"
  allowusers="$(get_sshd_value allowusers)"
  if [[ -n "$allowgroups" || -n "$allowusers" ]]; then result="通过"; else result="不通过"; fi
  add_row "登录用户收口" "$result" "allowgroups=${allowgroups:-空}; allowusers=${allowusers:-空}" "目标机建议 AllowGroups ops 或明确 AllowUsers。"

  v="$(get_sshd_value allowagentforwarding)"
  [[ "$v" == "no" ]] && result="通过" || result="不通过"
  add_row "禁止 AgentForwarding" "$result" "allowagentforwarding=${v:-未获取}" "设置 AllowAgentForwarding no。"

  v="$(get_sshd_value allowtcpforwarding)"
  if [[ "$ROLE" == "jump" ]]; then
    [[ "$v" == "yes" ]] && result="通过" || result="不通过"
    add_row "跳板机 TCP 转发" "$result" "allowtcpforwarding=${v:-未获取}" "自建跳板机通常需要 AllowTcpForwarding yes 以支持 ProxyJump。"
  else
    [[ "$v" == "no" ]] && result="通过" || result="不通过"
    add_row "目标机关闭 TCP 转发" "$result" "allowtcpforwarding=${v:-未获取}" "目标业务 ECS 通常不承担中转职责，建议 AllowTcpForwarding no。"
  fi

  if grep -q '^ops:' <<< "$ops_group"; then result="通过"; else result="不通过"; fi
  add_row "ops 组存在" "$result" "${ops_group:-未找到 ops 组}" "创建 ops 组，并通过组收口登录和 sudo 权限。"

  if grep -q 'active' <<< "$audit_status"; then result="通过"; else result="部分通过"; fi
  add_row "auditd 状态" "$result" "auditd=${audit_status//$'\n'/ }" "生产/关键主机建议启用 auditd 并配置关键规则。"

  if [[ -n "$sudo_conf" ]]; then result="通过"; else result="部分通过"; fi
  add_row "sudo I/O 审计配置" "$result" "${sudo_conf:+已发现 sudo 审计配置}" "跳板机建议启用 use_pty、log_input、log_output、iolog_dir；目标机按等级启用。"

  add_row "云侧安全组 SSH 来源" "人工核验" "主机内无法可靠判断" "确认 22 端口未对 0.0.0.0/0 长期开放，目标机只允许跳板机/PAM/VPN/办公来源。"
  add_row "ActionTrail / SLS / 云助手旁路" "人工核验" "需阿里云控制台或 aliyun CLI" "确认 ActionTrail 投递、SLS 留存、Workbench/云助手/动态公钥注入权限收口。"

  cat > "$REPORT_FILE" <<EOF
# ECS 安全检查报告

## 基本信息

- 检查时间：$now
- 主机名：$host
- 角色：$ROLE
- 工具版本：$VERSION
- 说明：本报告由 ecs-secops.sh 生成；check 命令只读，不修改系统。

## 检查结果

| 检查项 | 结果 | 证据 | 处理建议 |
| --- | --- | --- | --- |
$(printf '%b' "$REPORT_ROWS")

## 关键命令证据

### sshd -T 摘要

\`\`\`text
$(grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication|allowgroups|allowusers|allowtcpforwarding|allowagentforwarding|loglevel|maxauthtries' <<< "$sshd_t" || true)
\`\`\`

### SSH 服务状态

\`\`\`text
$service_status
\`\`\`

### auditd 状态

\`\`\`text
$audit_status
\`\`\`

### sudo 审计配置片段

\`\`\`text
${sudo_conf:-未发现 log_input/log_output/iolog_dir/use_pty 配置}
\`\`\`

### UID >= 1000 的本地账号

\`\`\`text
$users_over_1000
\`\`\`

### 时间与时区

\`\`\`text
$time_info
\`\`\`

### /var/log/secure 最近日志

\`\`\`text
$secure_tail
\`\`\`

## 后续建议

1. 先处理“不通过”的 SSH 基线项，尤其是 root 登录、密码登录、目标机 TCP 转发。
2. 跳板机必须重点补齐 sudo I/O 审计、auditd、SLS 集中留存。
3. 目标 ECS 必须从云侧确认 22 端口来源收口，避免绕过跳板机/PAM。
4. 云侧 ActionTrail、Workbench、云助手、动态公钥注入需要单独核验并留存截图或查询结果。
EOF

  log "报告已生成：$REPORT_FILE"
}

case "$COMMAND" in
  help|-h|--help) usage ;;
  check) cmd_check ;;
  init-target|init) cmd_init_target ;;
  user-add) cmd_user_add ;;
  *) usage; fail "未知命令：$COMMAND" ;;
esac
