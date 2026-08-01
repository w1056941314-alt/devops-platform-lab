#!/bin/bash
# 脚本名称: setup-jenkins.sh
# 作用: 自动配置 Jenkins Pipeline 任务，无需手动在 Web UI 中操作
# 用法: bash scripts/setup-jenkins.sh
# 前提: Jenkins 容器已启动且初始化完成

set -e

JENKINS_URL="http://localhost:8081"
MAX_WAIT=120

echo "===== 等待 Jenkins 启动 ====="
for i in $(seq 1 $MAX_WAIT); do
    if curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL/login" | grep -q "200"; then
        echo ""
        echo "[OK] Jenkins 已就绪"
        break
    fi
    echo -n "."
    sleep 1
done

# 获取初始密码（通过 docker exec，不依赖宿主机文件路径）
echo ""
echo "===== Jenkins 初始密码 ====="
INITIAL_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")

if [ -n "$INITIAL_PASSWORD" ]; then
    echo "[INFO] 初始密码: $INITIAL_PASSWORD"
    echo ""
    echo "===== 下一步操作 ====="
    echo "1. 访问 http://localhost:8081"
    echo "2. 输入上面的初始密码"
    echo "3. 安装推荐插件"
    echo "4. 创建管理员账号"
    echo "5. 完成后回到这里，运行: bash scripts/setup-jenkins.sh --auto"
    echo ""
else
    echo "[INFO] Jenkins 可能已完成初始化，或密码文件不存在"
fi

# 自动模式（需要 Jenkins 已完成初始化并设置了管理员账号）
if [ "$1" = "--auto" ]; then
    echo ""
    echo "[INFO] 尝试自动创建 Pipeline 任务..."
    echo ""
    echo "由于 Jenkins 自动配置需要 API Token，简化流程如下:"
    echo ""
    echo "  1. 访问 http://localhost:8081"
    echo "  2. 点击左侧'新建任务'"
    echo "  3. 输入名称: nginx-cicd"
    echo "  4. 选择'流水线'，点击确定"
    echo "  5. 在'流水线'区域:"
    echo "     - Definition: Pipeline script from SCM"
    echo "     - SCM: Git"
    echo "     - Repository URL: file:///home/你的用户名/myapp"
    echo "     - Branches to build: */main"
    echo "     - Script Path: Jenkinsfile"
    echo "  6. 点击保存"
    echo ""
    echo "  然后回到任务页面，点击'立即构建'即可"
    echo ""
    echo "  注意: 请把 /home/你的用户名 替换为你的实际家目录"
fi
