#!/bin/bash
# 脚本名称: cleanup.sh
# 作用: 一键清理 DevOps 实验环境，恢复到初始状态
# 注意: 默认保留 Docker 镜像和数据卷，如需彻底清理请手动执行 docker volume rm
# 用法: cd /home/ace/monitoring-lab && bash scripts/cleanup.sh

set -e

# 切换到脚本所在目录
cd "$(dirname "$0")/.."

echo "===== 开始清理环境 ====="

# 1. 停止并删除 Docker Compose 服务
echo "停止 Docker Compose 服务..."
if [ -f docker-compose.yml ]; then
    sudo docker compose down
fi

# 2. 删除 Kind 集群
echo "删除 Kind 集群..."
kind delete cluster 2>/dev/null || echo "Kind 集群不存在或已删除"

# 3. 清理端口转发进程
pkill -f "kubectl port-forward.*kube-state-metrics" 2>/dev/null || true

# 4. 可选: 彻底清理未使用的 Docker 资源
# 取消下一行注释以启用（会删除所有未使用的镜像、容器、缓存，慎用）
# docker system prune -a -f

echo "===== 清理完成 ====="
echo ""
echo "提示: 以下数据卷未被删除，如需彻底清理请手动执行:"
echo "  docker volume rm devops-platform-lab_prometheus_data"
echo "  docker volume rm devops-platform-lab_grafana_data"
echo "  docker volume rm devops-platform-lab_es_data"
echo "  docker volume rm devops-platform-lab_jenkins_home"
echo ""
echo "如需重新部署，请执行: make up"
