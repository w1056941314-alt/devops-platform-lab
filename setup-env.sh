#!/bin/bash
# 脚本名称: setup-env.sh
# 作用: 自动检测 Docker bridge 网关地址，生成 .env 文件，并预处理配置文件
# 用法: source ./setup-env.sh
# 为什么需要:
#   1. 消除 172.17.0.1 硬编码，让配置在不同电脑上都能跑通
#   2. 生成 .env 文件供 Docker Compose 读取（包括 HOME 变量）
#   3. 自动生成 alertmanager.yml（避免用户忘记手动复制）
#   4. 预处理 kind-config.yaml，将占位符替换为实际网关地址

set -e

# 通过 docker network inspect 获取 bridge 网络的网关地址
GATEWAY=$(docker network inspect bridge --format='{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)

# 如果检测不到，使用默认值兜底
if [ -z "$GATEWAY" ]; then
    echo "[!] 无法自动检测 Docker 网关，使用默认值 172.17.0.1"
    echo "    如果后续服务访问异常，请手动检查: docker network inspect bridge"
    GATEWAY="172.17.0.1"
fi

# 导出环境变量，当前终端可用
export DOCKER_GATEWAY=$GATEWAY

# 写入 .env 文件，docker compose 和其他脚本可以读取
# 注意: Docker Compose 会从 .env 文件读取变量，用于解析 docker-compose.yml 中的 ${HOME}
cat > .env << EOENV
# 由 setup-env.sh 自动生成，请勿手动修改
DOCKER_GATEWAY=${DOCKER_GATEWAY}
HOME=${HOME}
EOENV

# 加固 .env 文件权限
chmod 600 .env

# 确认权限设置成功（兼容 macOS 和 Linux）
PERM=$(stat -c %a .env 2>/dev/null || stat -f %Lp .env 2>/dev/null)
if [ "$PERM" = "600" ]; then
    echo "[OK] Docker 网关已检测并导出: DOCKER_GATEWAY=${DOCKER_GATEWAY}"
    echo "[OK] .env 文件已生成（包含 HOME=${HOME}），权限已加固为 600"
else
    echo "[OK] Docker 网关已检测并导出: DOCKER_GATEWAY=${DOCKER_GATEWAY}"
    echo "[OK] .env 文件已生成（包含 HOME=${HOME}）"
    echo "[!] .env 文件权限设置可能未生效，当前权限: $PERM"
fi

echo ""
echo "===== 正在生成配置文件 ====="
# 自动生成所有含变量的配置文件
bash scripts/generate-configs.sh

# 预处理 kind-config.yaml：将占位符替换为实际的 DOCKER_GATEWAY
# 原因: Kind 读取的是纯 YAML 文件，不会解析 shell 变量 ${DOCKER_GATEWAY}
if [ -f kind-config.yaml ]; then
    echo "[OK] 预处理 kind-config.yaml..."
    # 使用临时文件避免 sed 原地编辑的兼容性问题
    sed "s|__DOCKER_GATEWAY__|${DOCKER_GATEWAY}|g" kind-config.yaml > kind-config.yaml.tmp
    mv kind-config.yaml.tmp kind-config.yaml
    echo "[OK] kind-config.yaml 已更新，网关地址: ${DOCKER_GATEWAY}"
fi

# 自动生成 alertmanager.yml（如果用户忘记手动复制）
if [ ! -f alertmanager.yml ]; then
    if [ -f alertmanager.yml.example ]; then
        echo "[OK] 从 alertmanager.yml.example 生成 alertmanager.yml..."
        cp alertmanager.yml.example alertmanager.yml
    else
        echo "[OK] 生成默认 alertmanager.yml..."
        cat > alertmanager.yml << 'EOALERT'
# 由 setup-env.sh 自动生成
# 作用: Alertmanager 路由配置
# 用法: 修改下方的邮箱地址后，Prometheus 告警会自动发送邮件

global:
  # 邮件 SMTP 服务器配置（示例，请根据实际邮箱修改）
  smtp_smarthost: 'localhost:25'
  smtp_from: 'alertmanager@example.com'

route:
  # 默认路由: 所有告警都发给 default-receiver
  receiver: 'default-receiver'
  # 按 alertname 分组（同一类型的告警合并成一封邮件）
  group_by: ['alertname']
  # 等待 10 秒再发送，让同类告警聚合
  group_wait: 10s
  # 同一组的告警间隔
  group_interval: 10s
  # 重复告警的间隔
  repeat_interval: 1h

receivers:
  - name: 'default-receiver'
    # 邮件通知（取消注释并配置 SMTP 后即可使用）
    # email_configs:
    #   - to: 'your-email@example.com'
    #     subject: '[Alert] {{ .GroupLabels.alertname }}'
    #     body: |
    #       {{ range .Alerts }}
    #       告警: {{ .Annotations.summary }}

    #       详情: {{ .Annotations.description }}

    #       时间: {{ .StartsAt }}

    #       {{ end }}
EOALERT
    fi
    echo "[OK] alertmanager.yml 已生成"
    echo "    提示: 如需邮件告警，请编辑 alertmanager.yml 配置 SMTP"
else
    echo "[OK] alertmanager.yml 已存在，跳过生成"
fi

echo ""
echo "===== 环境准备完成 ====="
echo ""
echo "后续所有配置文件将使用 DOCKER_GATEWAY=${DOCKER_GATEWAY}"
echo ""
echo "现在可以执行:"
echo "  make phase1    # 启动监控（4GB 内存）"
echo "  make phase2    # 加日志（+2GB）"
echo "  make phase3    # 加 CI/CD（+2GB）"
echo "  make full      # 全部启动（8GB+）"
