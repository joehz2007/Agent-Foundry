# ecs-secops.sh

阿里云 ECS 主机侧初始化与安全检查工具（MVP）。

> 依据 Obsidian 笔记：
>
> - 《阿里云跳板机与目标主机安全检查指南》
> - 《阿里云运维-ECS初始化》
> - 《阿里云运维-ECS用户管理》

## 定位

这个工具第一版只做 **主机内** 自动化：

- 目标 ECS 初始化
- 运维用户创建 / 公钥下发
- `ops` 组和 sudoers 配置
- 目标 ECS 的 `sshd` 基线配置
- 跳板机 / 目标 ECS 的主机侧安全检查
- 输出 Markdown 检查报告

暂不自动处理云侧：

- 安全组是否开放 `0.0.0.0/0:22`
- ActionTrail 是否开启
- SLS 是否采集日志
- Workbench / 云助手 / 动态公钥注入权限

这些会在 `check` 报告中列为“人工核验”。后续可以再接入 `aliyun` CLI 或 OpenAPI。

## 重要安全提醒

1. `init-target` 只适用于 **目标业务 ECS**，不要用于跳板机。
2. 目标业务 ECS 默认会配置 `AllowTcpForwarding no`；跳板机通常需要 `AllowTcpForwarding yes`。
3. 初始化前请保留当前 SSH 会话，不要断开。
4. 推荐先执行 `--dry-run`。
5. 默认写入 sshd 配置后 **不重启 sshd**；如需自动重启，显式传入 `--restart-sshd`。
6. 设置本地密码仍需人工执行 `sudo passwd <user>`，用于 sudo 交互提权。

## 文件

```text
tools/ecs-secops/
├── ecs-secops.sh
└── README.md
```

## 快速开始

### 1. 只检查目标 ECS

```bash
./ecs-secops.sh check --role target
```

生成类似：

```text
ecs-secops-report-hostname-20260609235959.md
```

### 2. 只检查跳板机

```bash
./ecs-secops.sh check --role jump
```

跳板机和目标机的关键差异：

| 项目 | 跳板机 | 目标业务 ECS |
| --- | --- | --- |
| `PermitRootLogin` | `no` | `no` |
| `PasswordAuthentication` | `no` | `no` |
| `AllowAgentForwarding` | `no` | `no` |
| `AllowTcpForwarding` | 通常 `yes` | 通常 `no` |
| `sudo I/O 审计` | 建议必需 | 生产/关键主机建议必需 |
| `auditd` | 建议必需 | 生产/关键主机建议必需 |

### 3. 新增或更新用户

```bash
./ecs-secops.sh user-add \
  --user xugw \
  --pubkey-file ./xugw.pub \
  --groups ops,app \
  --dry-run
```

确认无误后再执行：

```bash
./ecs-secops.sh user-add \
  --user xugw \
  --pubkey-file ./xugw.pub \
  --groups ops,app
```

它会做：

- 创建用户，如果用户不存在
- 创建组，如果组不存在
- 把用户加入指定组
- 创建 `~/.ssh/authorized_keys`
- 追加公钥，已存在则不重复追加
- 修正 `.ssh` 和 `authorized_keys` 权限

执行后建议人工设置本地密码：

```bash
sudo passwd xugw
```

用于 sudo 交互提权。

### 4. 初始化目标 ECS

先 dry-run：

```bash
./ecs-secops.sh init-target \
  --user xugw \
  --pubkey-file ./xugw.pub \
  --hostname app-test-01 \
  --dry-run
```

确认后执行：

```bash
./ecs-secops.sh init-target \
  --user xugw \
  --pubkey-file ./xugw.pub \
  --hostname app-test-01
```

默认行为：

- 设置时区为 `Asia/Shanghai`
- 可选设置主机名
- 创建 `ops` 组
- 创建用户并加入 `ops`
- 下发用户公钥
- 写入 `/etc/sudoers.d/ops`
- 写入目标 ECS sshd 基线：`/etc/ssh/sshd_config.d/99-ecs-baseline.conf`
- 执行 `sshd -t` 校验
- **不重启 sshd**

如确认新账号可以登录，希望脚本自动重启 sshd：

```bash
./ecs-secops.sh init-target \
  --user xugw \
  --pubkey-file ./xugw.pub \
  --restart-sshd
```

## sshd 基线内容

`init-target` 会写入：

```sshconfig
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
```

注意：如果 `/etc/ssh/sshd_config` 主文件里已经显式配置了同名参数，且其位置优先于 `Include /etc/ssh/sshd_config.d/*.conf`，那么目录配置可能不会成为最终生效值。执行后应使用：

```bash
./ecs-secops.sh check --role target
```

查看 `sshd -T` 的最终生效配置。

## 检查项

`check` 当前覆盖：

- `sshd -t` 语法
- `PermitRootLogin no`
- `PasswordAuthentication no`
- `PubkeyAuthentication yes`
- `LogLevel VERBOSE`
- `AllowGroups` / `AllowUsers`
- `AllowAgentForwarding no`
- 跳板机：`AllowTcpForwarding yes`
- 目标 ECS：`AllowTcpForwarding no`
- `ops` 组存在
- `auditd` 状态
- `sudo` I/O 审计配置片段
- UID >= 1000 的本地账号
- `/var/log/secure` 最近日志
- 时区 / 时间信息
- 云侧人工核验项提示

## 建议操作顺序

### 新目标 ECS

```text
1. 云侧先收口安全组
2. root 或临时入口登录目标 ECS
3. 执行 init-target --dry-run
4. 执行 init-target，不带 --restart-sshd
5. 人工设置新用户密码：sudo passwd <user>
6. 从本地经跳板机验证新用户公钥登录
7. 验证 sudo：sudo -v
8. 重启 sshd：sudo systemctl restart sshd
9. 执行 check --role target
10. 留存 Markdown 报告
```

### 已有 ECS 新增用户

```text
1. 确认用户公钥，不能收私钥
2. 执行 user-add --dry-run
3. 执行 user-add
4. 设置用户本地密码
5. 从本地经跳板机验证登录
6. 检查 sudo 权限和组归属
```

### 跳板机巡检

```text
1. 执行 check --role jump
2. 核对 AllowTcpForwarding 是否为 yes
3. 核对 sudo I/O 审计、auditd、SLS
4. 核对安全组入口只允许办公/VPN来源
5. 留存报告和云侧截图
```

## 后续增强方向

1. 增加 `init-jump`，单独处理跳板机基线。
2. 增加 `auditd` 和 `sudo I/O` 自动配置。
3. 增加 `--format json`，便于 CI 或批量汇总。
4. 增加远程模式：`--host`、`--jump`。
5. 增加 `aliyun` CLI 云侧检查：安全组、ActionTrail、SLS、云助手权限。
6. 稳定后迁移为 Ansible roles，支持批量 ECS 初始化和巡检。
