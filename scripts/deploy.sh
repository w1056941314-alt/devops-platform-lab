#!/bin/bash
# 脚本名称: deploy.sh
# 作用: 一键部署/恢复整个 DevOps 环境
# 用法: make full 或 bash scripts/deploy.sh

set -e

cd "$(dirname "$0")/.."

# 加载环境变量
if [ -f .env ]; then
    source .env
    echo "[OK] 已加载环境变量，DOCKER_GATEWAY=${DOCKER_GATEWAY}"
else
    echo "[!] 未找到 .env 文件，请先运行: source ./setup-env.sh"
    exit 1
fi

echo "================================"
echo "== DevOps 平台部署 =="
echo "================================"

# 0a. 端口占用预检
# 使用 lsof 作为 ss 的备选（某些系统 ss 需要 sudo）
check_port() {
    local port=$1
    if command -v ss >/dev/null 2>&1; then
        if ss -tlnp 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    elif command -v lsof >/dev/null 2>&1; then
        if lsof -i :"$port" >/dev/null 2>&1; then
            return 1
        fi
    else
        # 如果 ss 和 lsof 都不可用，用 /proc/net/tcp 兜底
        if grep -q "$(printf '%04X' "$port")" /proc/net/tcp 2>/dev/null; then
            return 1
        fi
    fi
    return 0
}

echo "[1/8] 检查端口占用..."
PORT_OK=true
for port in 8081 3000 5601 9090 9093 9200 9100 5000 8080; do
    if ! check_port $port; then
        echo "[WARN] 端口 $port 已被占用"
        echo "       解决方法: lsof -i :$port 找到进程并 kill，或修改 docker-compose.yml 中的端口映射"
        PORT_OK=false
    fi
done
if [ "$PORT_OK" = false ]; then
    echo "[!] 有端口被占用，请释放后重试"
    exit 1
fi
echo "[OK] 端口检查通过"

# 0b. 检查 Kind 集群
# 如果集群已存在，友好提示而不是报错退出
echo "[2/8] 检查 Kind 集群..."
if kind get clusters 2>/dev/null | grep -q "^kind$"; then
    echo "[OK] Kind 集群 'kind' 已存在，跳过创建"
    echo "    如需重新创建，请先执行: kind delete cluster"
else
    echo "Kind 集群不存在，正在创建..."
    # 确保 kind-config.yaml 已预处理（setup-env.sh 应该已经做了）
    if [ ! -f kind-config.yaml ]; then
        echo "[!] 未找到 kind-config.yaml，请先运行: source ./setup-env.sh"
        exit 1
    fi
    kind create cluster --config kind-config.yaml || {
        echo "[!] Kind 集群创建失败"
        echo "    常见原因:"
        echo "    1. Docker 未运行: sudo systemctl start docker"
        echo "    2. 内存不足: 确保空闲内存 >= 4GB"
        echo "    3. 磁盘空间不足: df -h 检查"
        exit 1
    }
fi

# 1. 确认 Docker 正在运行
echo "[3/8] 检查 Docker..."
docker info >/dev/null 2>&1 || {
    echo "[FAIL] Docker 未运行!"
    echo "       解决方法: sudo systemctl start docker"
    exit 1
}

# 2. 启动 Kind 节点（如果之前 stop 了）
echo "[4/8] 启动 Kind 节点..."
docker start kind-control-plane 2>/dev/null || true
docker start kind-worker 2>/dev/null || true

echo "[5/8] 等待 K8s 节点就绪（最多 120 秒）..."
kubectl wait --for=condition=Ready node --all --timeout=120s || {
    echo "[!] K8s 节点未就绪"
    echo "    解决方法: kind delete cluster && source ./setup-env.sh && make full"
    exit 1
}

# 3. 检查并拉取所需镜像
echo "[6/8] 检查镜像..."
pull_if_not_exists() {
    if ! docker image inspect "$1" >/dev/null 2>&1; then
        echo "  拉取镜像: $1"
        docker pull "$1" || {
            echo "  [!] 拉取失败，尝试阿里云镜像源..."
            return 1
        }
    else
        echo "  已存在: $1"
    fi
}

pull_if_not_exists "nginx:1.27-alpine"
pull_if_not_exists "busybox:1.36"
pull_if_not_exists "fluent/fluentd-kubernetes-daemonset:v1.16-debian-elasticsearch-1"

# kube-state-metrics 用阿里云镜像源回退
KSM_IMAGE="registry.k8s.io/kube-state-metrics:v2.15.0"
ALIYUN_IMAGE="registry.aliyuncs.com/google_containers/kube-state-metrics:v2.15.0"
if ! docker image inspect "$KSM_IMAGE" >/dev/null 2>&1; then
    echo "  尝试拉取 kube-state-metrics（官方源）..."
    if ! docker pull "$KSM_IMAGE" 2>/dev/null; then
        echo "  官方源失败，切换到阿里云镜像源..."
        docker pull "$ALIYUN_IMAGE" && docker tag "$ALIYUN_IMAGE" "$KSM_IMAGE"
    fi
fi

# 4. 导入镜像到 Kind
# 先检查 kind-control-plane 容器是否存在，避免 ctr 命令报错
echo "[7/8] 导入镜像到 Kind..."
if docker ps -a --format '{{.Names}}' | grep -q "^kind-control-plane$"; then
    if ! docker exec kind-control-plane ctr -n k8s.io images ls 2>/dev/null | grep -q "kube-state-metrics"; then
        echo "  导入 kube-state-metrics 到 Kind..."
        kind load docker-image "$KSM_IMAGE"
    else
        echo "  kube-state-metrics 已在 Kind 中，跳过导入"
    fi
else
    echo "[WARN] kind-control-plane 容器不存在，跳过镜像导入"
    echo "       可能原因: Kind 集群创建失败或集群名不匹配"
fi

# 5. 部署 K8s 资源
echo "[8/8] 部署 K8s 资源..."
kubectl apply -f app-deployment.yaml
kubectl apply -f fluentd-daemonset.yaml
kubectl apply -f network-policy.yaml
kubectl apply -f https://github.com/kubernetes/kube-state-metrics/raw/main/examples/standard/cluster-role.yaml
kubectl apply -f https://github.com/kubernetes/kube-state-metrics/raw/main/examples/standard/deployment.yaml
kubectl apply -f https://github.com/kubernetes/kube-state-metrics/raw/main/examples/standard/service.yaml

# 6. 端口转发
# 使用更精确的匹配模式，避免误杀其他用户的 port-forward 进程
echo "[OK] 建立端口转发..."
# 先查找当前目录相关的 port-forward 进程（通过 kube-state-metrics 服务名匹配）
PF_PID=$(pgrep -f "kubectl port-forward.*kube-state-metrics.*8080:8080" || true)
if [ -n "$PF_PID" ]; then
    echo "  停止旧的端口转发进程 (PID: $PF_PID)..."
    kill "$PF_PID" 2>/dev/null || true
    sleep 1
fi
nohup kubectl port-forward -n kube-system svc/kube-state-metrics 8080:8080 --address 0.0.0.0 >/dev/null 2>&1 &
sleep 2
echo "[OK] 端口转发已建立: localhost:8080 -> kube-state-metrics:8080"

# 7. 调整内核参数
sudo sysctl -w vm.max_map_count=262144 >/dev/null 2>&1 || true

# 8. 启动所有外部容器
echo "[OK] 启动外部服务..."
docker compose --profile full up -d

echo "================================"
echo "[OK] 部署完成!"
echo ""
echo "  Jenkins:      http://localhost:8081"
echo "  Grafana:      http://localhost:3000 (admin/admin)"
echo "  Kibana:       http://localhost:5601"
echo "  Prometheus:   http://localhost:9090"
echo "  Alertmanager: http://localhost:9093"
echo ""
echo "  如果浏览器打不开，执行: make diagnose"
echo "  查看状态: make status"
echo "================================"
