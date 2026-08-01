#!/bin/bash
# 脚本名称: test.sh
# 作用: 分阶段冒烟测试
# 用法: make test
#
# 注意: 本脚本已移除 set -e，所有测试都会执行完再统一输出结果
#       不会因为某个服务检查失败而提前退出

# 不再使用 set -e，确保所有测试都执行完
# set -e

echo "===== 冒烟测试 ====="
echo ""

# 检测当前启动了哪些服务
HAS_MONITORING=false
HAS_LOGGING=false
HAS_CICD=false

# 使用 docker compose ps 检查服务状态
# 注意: docker compose ps 在没有 running 容器时可能返回非零，用 || true 忽略
if docker compose ps 2>/dev/null | grep -q prometheus; then HAS_MONITORING=true; fi
if docker compose ps 2>/dev/null | grep -q elasticsearch; then HAS_LOGGING=true; fi
if docker compose ps 2>/dev/null | grep -q jenkins; then HAS_CICD=true; fi

PASS=0
FAIL=0

check_service() {
    local name=$1
    local url=$2
    local check=$3
    echo -n "  $name: "
    # 使用 eval 执行检查命令，但捕获退出状态而不是让 set -e 中断
    if eval "$check" >/dev/null 2>&1; then
        echo "[OK]"
        PASS=$((PASS + 1))
    else
        echo "[FAIL]"
        FAIL=$((FAIL + 1))
    fi
}

# Phase 1: 监控
if [ "$HAS_MONITORING" = true ]; then
    echo "[Phase 1] 监控服务检查:"
    check_service "Prometheus" "http://localhost:9090"         'curl -s http://localhost:9090/-/healthy | grep -q "Prometheus Server is Healthy"'
    check_service "Grafana" "http://localhost:3000"         'curl -s http://localhost:3000/api/health | grep -q '"'"'"database":"ok"'"'"''
    check_service "Node Exporter" "http://localhost:9100"         'curl -s http://localhost:9100/metrics | grep -q "node_cpu_seconds_total"'
    check_service "Alertmanager" "http://localhost:9093"         'curl -s http://localhost:9093/-/healthy | grep -q "OK"'
    echo ""
fi

# Phase 2: 日志
if [ "$HAS_LOGGING" = true ]; then
    echo "[Phase 2] 日志服务检查:"
    check_service "Elasticsearch" "http://localhost:9200"         'curl -s http://localhost:9200/_cluster/health | grep -q '"'"'"status"'"'"''
    # Kibana 启动慢，多等一会儿
    echo -n "  Kibana: "
    KIBANA_OK=false
    for i in $(seq 1 15); do
        if curl -s http://localhost:5601/api/status 2>/dev/null | grep -q '"'"'"level":"available"'"'"''; then
            echo "[OK]"
            PASS=$((PASS + 1))
            KIBANA_OK=true
            break
        fi
        sleep 3
    done
    if [ "$KIBANA_OK" = false ]; then
        echo "[FAIL]（启动较慢，请稍后再试）"
        FAIL=$((FAIL + 1))
    fi
    echo ""
fi

# Phase 3: CI/CD
if [ "$HAS_CICD" = true ]; then
    echo "[Phase 3] CI/CD 服务检查:"
    check_service "Jenkins" "http://localhost:8081"         '[ "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/login)" = "200" ]'
    check_service "Registry" "http://localhost:5000"         'curl -s http://localhost:5000/v2/_catalog | grep -q "repositories"'
    echo ""
fi

# K8s 检查
echo "[K8s] 集群状态检查:"
if kubectl get nodes >/dev/null 2>&1; then
    echo "  Nodes: [OK]"
    PASS=$((PASS + 1))
    echo -n "  Nginx Pod: "
    if kubectl get pods -l app=nginx-demo-pod 2>/dev/null | grep -q "Running"; then
        echo "[OK]"
        PASS=$((PASS + 1))
    else
        echo "[FAIL]"
        FAIL=$((FAIL + 1))
    fi
    echo -n "  kube-state-metrics: "
    if curl -s http://localhost:8080/metrics 2>/dev/null | grep -q "kube_"; then
        echo "[OK]"
        PASS=$((PASS + 1))
    else
        echo "[FAIL]（端口转发可能未建立）"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  [INFO] K8s 集群未启动"
fi

echo ""
echo "===== 测试结果: $PASS 通过, $FAIL 失败 ====="
if [ $FAIL -eq 0 ]; then
    echo "[PASS] 所有检查通过！"
    exit 0
else
    echo "[WARN] 有 $FAIL 项未通过，建议执行: make diagnose"
    exit 0
fi
