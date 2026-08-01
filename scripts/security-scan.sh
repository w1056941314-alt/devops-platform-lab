#!/bin/bash
# 脚本名称: security-scan.sh
# 作用: 对构建的镜像进行安全扫描
# 用法: bash scripts/security-scan.sh <镜像名:标签>
# [v5新增]

set -e

IMAGE="${1:-nginx-demo:latest}"

echo "===== 镜像安全扫描: $IMAGE ====="

if ! command -v trivy >/dev/null 2>&1; then
    echo "[!] Trivy 未安装，正在安装..."
    # 安装 Trivy
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
fi

echo "[1/3] 扫描 OS 漏洞..."
trivy image --severity HIGH,CRITICAL --exit-code 0 "$IMAGE"

echo "[2/3] 扫描依赖库漏洞..."
trivy image --severity HIGH,CRITICAL --scanners vuln --exit-code 0 "$IMAGE"

echo "[3/3] 检查敏感信息泄露..."
trivy image --scanners secret --exit-code 0 "$IMAGE"

echo "===== 扫描完成 ====="
