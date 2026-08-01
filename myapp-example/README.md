# 示例应用

这些文件需要复制到 `~/myapp` 目录中，作为 Jenkins Pipeline 的构建源。

## 快速复制

```bash
# 1. 创建目录
mkdir -p ~/myapp

# 2. 复制文件
cp index.html ~/myapp/
cp Dockerfile ~/myapp/

# 3. 初始化 Git 仓库
cd ~/myapp
git init
git add .
git commit -m "first commit"

# 4. 复制 Jenkinsfile（从项目根目录）
cp /path/to/devops-platform-lab/Jenkinsfile ~/myapp/
cd ~/myapp && git add Jenkinsfile && git commit -m "add Jenkinsfile"
```

## 修改 Jenkinsfile 中的路径

打开 `~/myapp/Jenkinsfile`，找到以下行：

```groovy
MONITORING_LAB_PATH = '/home/ace/monitoring-lab'
```

把 `/home/ace` 替换为你的实际家目录，例如：
- Linux: `/home/yourname/monitoring-lab`
- macOS: `/Users/yourname/monitoring-lab`

## 验证

```bash
cd ~/myapp
ls -la
# 应该看到: Dockerfile  index.html  Jenkinsfile  .git/
```
