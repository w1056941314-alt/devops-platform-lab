#!/bin/bash
# 脚本名称: diagnose.sh
# 作用: 一键收集诊断信息，生成报告，降低排障沟通成本
# 用法: bash scripts/diagnose.sh
# [v4新增]

REPORT_DIR="diagnosis-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPORT_DIR"

# 检查 jq 是否安装
if ! command -v jq >/dev/null 2>&1; then
    echo "[!] jq 未安装，诊断报告中的 JSON 数据将不会被格式化"
    echo "    建议安装: sudo apt-get install jq 或 brew install jq"
fi

echo "===== 开始收集诊断信息 ====="

# 1. 系统信息
echo "[1/8] 收集系统资源..."
echo "=== CPU / 内存 / 磁盘 ===" > "$REPORT_DIR/system.txt"
free -h >> "$REPORT_DIR/system.txt" 2>/dev/null || true
df -h >> "$REPORT_DIR/system.txt" 2>/dev/null || true
top -bn1 | head -20 >> "$REPORT_DIR/system.txt" 2>/dev/null || true

# 2. Docker 状态
echo "[2/8] 收集 Docker 状态..."
docker compose ps > "$REPORT_DIR/docker-ps.txt" 2>/dev/null || true
docker stats --no-stream > "$REPORT_DIR/docker-stats.txt" 2>/dev/null || true

# 3. K8s 状态
echo "[3/8] 收集 K8s 状态..."
kubectl get nodes -o wide > "$REPORT_DIR/k8s-nodes.txt" 2>/dev/null || true
kubectl get pods --all-namespaces -o wide > "$REPORT_DIR/k8s-pods.txt" 2>/dev/null || true
kubectl get events --sort-by='.lastTimestamp' > "$REPORT_DIR/k8s-events.txt" 2>/dev/null || true

# 4. 容器日志（最近100行）
echo "[4/8] 收集容器日志..."
for container in prometheus grafana alertmanager es kb jenkins registry node-exporter; do
    docker logs --tail 100 "$container" > "$REPORT_DIR/log-${container}.txt" 2>/dev/null || true
done

# 5. 网络连通性
echo "[5/8] 测试网络连通性..."
echo "=== 端口监听 ===" > "$REPORT_DIR/network.txt"
ss -tlnp >> "$REPORT_DIR/network.txt" 2>/dev/null || true
echo "" >> "$REPORT_DIR/network.txt"
echo "=== Prometheus Targets ===" >> "$REPORT_DIR/network.txt"
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health}' >> "$REPORT_DIR/network.txt" 2>/dev/null || true

# 6. ES 健康
echo "[6/8] 收集 ES 状态..."
curl -s http://localhost:9200/_cluster/health > "$REPORT_DIR/es-health.json" 2>/dev/null || true
curl -s http://localhost:9200/_cat/indices?v > "$REPORT_DIR/es-indices.txt" 2>/dev/null || true

# 7. 告警状态
echo "[7/8] 收集告警状态..."
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | .labels.alertname' > "$REPORT_DIR/alerts.txt" 2>/dev/null || true

# 8. 生成摘要
echo "[8/8] 生成报告摘要..."
cat > "$REPORT_DIR/SUMMARY.txt" << SUMM
diagnosis report generated at: $(date)
report directory: $REPORT_DIR

file descriptions:
  - system.txt: system resources (CPU/memory/disk)
  - docker-ps.txt / docker-stats.txt: Docker container status
  - k8s-*.txt: Kubernetes nodes, pods, events
  - log-*.txt: last 100 lines of each container log
  - network.txt: network ports and Prometheus target health
  - es-health.json / es-indices.txt: Elasticsearch cluster status
  - alerts.txt: current active alerts list

please pack and send $REPORT_DIR to support:
  tar czf ${REPORT_DIR}.tar.gz $REPORT_DIR
SUMM

tar czf "${REPORT_DIR}.tar.gz" "$REPORT_DIR"

echo "===== 诊断完成 ====="
echo "[OK] 报告已生成: $REPORT_DIR/"
echo "[OK] 打包文件: ${REPORT_DIR}.tar.gz"
