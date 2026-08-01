#!/bin/bash
# 脚本名称: check-prereqs.sh
# 作用: 检查宿主机是否满足运行本项目的所有前置条件
# 用法: bash scripts/check-prereqs.sh

set -e

ERRORS=0
WARNINGS=0

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "  [OK] $1: $("$1" --version 2>/dev/null | head -1 || echo 'installed')"
    else
        echo "  [FAIL] $1 未安装"
        ERRORS=$((ERRORS + 1))
    fi
}

check_port() {
    if ss -tlnp 2>/dev/null | grep -q ":$1 "; then
        echo "  [WARN] 端口 $1 已被占用"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "  [OK] 端口 $1 可用"
    fi
}

echo "===== 前置条件检查 ====="
echo ""

echo "[1/6] 检查必需命令..."
check_cmd docker
check_cmd "docker compose" || check_cmd docker-compose
check_cmd kubectl
check_cmd kind
check_cmd helm
check_cmd jq

echo ""
echo "[2/6] 检查可选命令..."
check_cmd trivy || echo "  [INFO] trivy 未安装（可选，用于镜像安全扫描）"
check_cmd cosign || echo "  [INFO] cosign 未安装（可选，用于镜像签名）"

echo ""
echo "[3/6] 检查系统资源..."
MEM_GB=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo 0)
if [ "$MEM_GB" -ge 8 ]; then
    echo "  [OK] 内存: ${MEM_GB}GB"
else
    echo "  [WARN] 内存: ${MEM_GB}GB（建议 >= 8GB）"
    WARNINGS=$((WARNINGS + 1))
fi

CPU_CORES=$(nproc 2>/dev/null || echo 0)
if [ "$CPU_CORES" -ge 4 ]; then
    echo "  [OK] CPU: ${CPU_CORES} 核"
else
    echo "  [WARN] CPU: ${CPU_CORES} 核（建议 >= 4核）"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "[4/6] 检查端口占用..."
for port in 8081 3000 5601 9090 9093 9200 9100 5000 8080; do
    check_port $port
done

echo ""
echo "[5/6] 检查 Docker 运行状态..."
if docker info >/dev/null 2>&1; then
    echo "  [OK] Docker 正在运行"
else
    echo "  [FAIL] Docker 未运行"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "[6/6] 检查 vm.max_map_count..."
CURRENT=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
if [ "$CURRENT" -ge 262144 ]; then
    echo "  [OK] vm.max_map_count = $CURRENT"
else
    echo "  [WARN] vm.max_map_count = $CURRENT（建议 >= 262144，Elasticsearch 需要）"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "===== 检查结果 ====="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "[PASS] 所有检查通过，可以开始部署！"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "[WARN] 发现 $WARNINGS 个警告，建议修复后再部署"
    exit 0
else
    echo "[FAIL] 发现 $ERRORS 个错误，$WARNINGS 个警告，请先修复错误"
    exit 1
fi
