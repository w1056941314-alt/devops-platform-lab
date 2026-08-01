#!/bin/bash
# 脚本名称: install-deps.sh
# 作用: 一键安装运行本项目所需的所有依赖
# 用法: bash scripts/install-deps.sh
# 支持: Ubuntu/Debian, CentOS/RHEL/Fedora, macOS

set -e

OS=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif [ "$(uname)" = "Darwin" ]; then
    OS="macos"
else
    echo "[!] 无法识别操作系统，请手动安装依赖"
    exit 1
fi

echo "===== 检测到操作系统: $OS ====="

# 安装 Docker
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        echo "[SKIP] Docker 已安装: $(docker --version)"
        return
    fi
    echo "[INSTALL] 正在安装 Docker..."
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker $USER
        echo "[OK] Docker 安装完成，请重新登录以应用用户组变更"
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        echo "[OK] Docker 安装完成，请重新登录以应用用户组变更"
    elif [ "$OS" = "macos" ]; then
        echo "[!] macOS 请手动安装 Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
        exit 1
    fi
}

# 安装 kubectl
install_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        echo "[SKIP] kubectl 已安装: $(kubectl version --client 2>/dev/null | head -1)"
        return
    fi
    echo "[INSTALL] 正在安装 kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo "[OK] kubectl 安装完成"
}

# 安装 Kind
install_kind() {
    if command -v kind >/dev/null 2>&1; then
        echo "[SKIP] Kind 已安装: $(kind version)"
        return
    fi
    echo "[INSTALL] 正在安装 Kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo "[OK] Kind 安装完成"
}

# 安装 Helm
install_helm() {
    if command -v helm >/dev/null 2>&1; then
        echo "[SKIP] Helm 已安装: $(helm version --short 2>/dev/null)"
        return
    fi
    echo "[INSTALL] 正在安装 Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "[OK] Helm 安装完成"
}

# 安装 jq
install_jq() {
    if command -v jq >/dev/null 2>&1; then
        echo "[SKIP] jq 已安装"
        return
    fi
    echo "[INSTALL] 正在安装 jq..."
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        sudo apt-get install -y jq
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
        sudo yum install -y jq
    fi
    echo "[OK] jq 安装完成"
}

# 主流程
echo ""
echo "===== 开始安装依赖 ====="
install_docker
install_kubectl
install_kind
install_helm
install_jq

echo ""
echo "===== 安装完成 ====="
echo ""
echo "如果 Docker 是新安装的，请执行以下命令后重新登录:"
echo "  newgrp docker"
echo ""
echo "验证安装:"
echo "  docker --version"
echo "  docker compose version"
echo "  kubectl version --client"
echo "  kind version"
echo "  helm version"
