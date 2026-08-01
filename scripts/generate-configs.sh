#!/bin/bash
# 脚本名称: generate-configs.sh
# 作用: 根据当前环境自动生成所有包含动态变量的配置文件
#
# 为什么需要这个脚本:
#   GitHub 下载的文件中含有 ${DOCKER_GATEWAY}、/home/ace 等占位符
#   这些需要根据你的实际环境替换，否则配置会出错
#
# 用法:
#   source ./setup-env.sh              # 先检测网关
#   bash scripts/generate-configs.sh   # 再生成配置

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# 检查环境变量
if [ -z "$DOCKER_GATEWAY" ]; then
    echo "[!] DOCKER_GATEWAY 未设置，请先运行: source ./setup-env.sh"
    exit 1
fi

if [ -z "$HOME" ]; then
    echo "[!] HOME 环境变量未设置"
    exit 1
fi

echo "===== 生成配置文件 ====="
echo "DOCKER_GATEWAY: $DOCKER_GATEWAY"
echo "HOME: $HOME"
echo ""

# ---------- 生成 kind-config.yaml ----------
echo "[1/4] 生成 kind-config.yaml..."
cat > kind-config.yaml << EOF
# 文件: kind-config.yaml
# 作用: 定义 Kind 集群的节点结构和 containerd 配置
# 自动生成时间: $(date)
# 注意: 本文件由 scripts/generate-configs.sh 自动生成

kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker

containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${DOCKER_GATEWAY}:5000"]
      endpoint = ["http://${DOCKER_GATEWAY}:5000"]
EOF
echo "  [OK] kind-config.yaml"

# ---------- 生成 prometheus.yml ----------
echo "[2/4] 生成 prometheus.yml..."
cat > prometheus.yml << EOF
# 文件: prometheus.yml
# 作用: Prometheus 监控抓取配置
# 自动生成时间: $(date)

global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - "/etc/prometheus/alert.rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'kube-state-metrics'
    static_configs:
      - targets: ['${DOCKER_GATEWAY}:8080']
EOF
echo "  [OK] prometheus.yml"

# ---------- 生成 fluentd-daemonset.yaml ----------
echo "[3/4] 生成 fluentd-daemonset.yaml..."
cat > fluentd-daemonset.yaml << 'INNEREOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd
rules:
  - apiGroups: [""]
    resources: ["pods", "namespaces"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: fluentd
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: fluentd
    namespace: kube-system
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: fluentd
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      serviceAccountName: fluentd
      containers:
        - name: fluentd
          image: fluent/fluentd-kubernetes-daemonset:v1.16-debian-elasticsearch-1
          env:
            - name: FLUENT_ELASTICSEARCH_HOST
              value: "DOCKER_GATEWAY_PLACEHOLDER"
            - name: FLUENT_ELASTICSEARCH_PORT
              value: "9200"
            - name: FLUENT_ELASTICSEARCH_SCHEME
              value: "http"
            - name: FLUENT_ELASTICSEARCH_BUFFER_TYPE
              value: "file"
            - name: FLUENT_ELASTICSEARCH_BUFFER_PATH
              value: "/var/log/fluentd-buffer"
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: dockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: buffer
              mountPath: /var/log/fluentd-buffer
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: dockercontainers
          hostPath:
            path: /var/lib/docker/containers
        - name: buffer
          hostPath:
            path: /var/log/fluentd-buffer
INNEREOF
sed -i "s/DOCKER_GATEWAY_PLACEHOLDER/${DOCKER_GATEWAY}/g" fluentd-daemonset.yaml
echo "  [OK] fluentd-daemonset.yaml"

# ---------- 更新 docker-compose.yml 中的家目录路径 ----------
echo "[4/4] 更新 docker-compose.yml..."
sed -i "s|/home/ace|${HOME}|g" docker-compose.yml
echo "  [OK] docker-compose.yml"

echo ""
echo "===== 配置生成完成 ====="
echo "现在可以执行: make phase1"
