# 故障排查指南

> 遇到问题不要慌，90% 的问题都有标准解法。

## 第一步：运行诊断

```bash
make diagnose
```

这会生成一个 `diagnosis-YYYYMMDD-HHMMSS/` 目录，包含系统资源、容器状态、K8s 事件、日志等信息。如果向别人求助，直接打包这个目录发过去。

## 第二步：按症状查找

### 症状 1: `make check` 报内存不足

**表现**: `内存: 3GB（建议 >= 8GB）`

**原因**: 你的电脑总内存不足，或者 WSL2/Docker Desktop 分配的内存太少。

**解决**:
- WSL2: 在 Windows 创建 `C:\Users\<你>\.wslconfig`：
  ```
  [wsl2]
  memory=8GB
  processors=4
  swap=2GB
  ```
  保存后执行 `wsl --shutdown`，重新打开 WSL2
- Mac: Docker Desktop -> Settings -> Resources -> Memory 调到 8GB
- 如果只有 4GB 总内存：只能跑 `make phase1`，Phase 2/3 会 OOM

---

### 症状 2: 浏览器打不开 localhost:3000

**表现**: 页面无法访问或连接被拒绝

**排查步骤**:
1. `make status` — 看 Grafana 容器是否在运行
2. `docker logs grafana` — 看有没有报错
3. **WSL2**: 执行 `ip addr | grep eth0`，用 `http://<IP>:3000` 访问
4. **Mac**: 检查 Docker Desktop 端口映射是否开启
5. **Linux**: `sudo ufw status` 看防火墙是否拦截

---

### 症状 3: Elasticsearch 启动后自动退出

**表现**: `docker compose ps` 显示 ES 是 `Exited` 状态

**原因**: `vm.max_map_count` 太小，ES 需要至少 262144

**解决**:
```bash
# Linux/WSL2
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Mac: Docker Desktop -> Settings -> Resources -> Advanced
# 添加参数: vm.max_map_count=262144
```

---

### 症状 4: Pod 一直 ImagePullBackOff

**表现**: `kubectl get pods` 显示 `ImagePullBackOff`

**排查**:
```bash
# 看具体错误
kubectl describe pod <pod-name>

# 常见原因:
# 1. kind-config.yaml 没配置 registry mirrors
#    解决: kind delete cluster && kind create cluster --config kind-config.yaml
# 2. setup-env.sh 检测的网关不对
#    解决: docker network inspect bridge 确认网关，手动修改 .env
# 3. 镜像不存在
#    解决: docker pull nginx:1.27-alpine
```

---

### 症状 5: Jenkins 构建失败

**表现**: Pipeline 构建红色，日志报错

**排查**:
```bash
# 1. Jenkins 里能不能用 Docker?
docker exec jenkins docker ps

# 2. Jenkins 里能不能连 K8s?
docker exec jenkins kubectl get nodes

# 3. Jenkins 能不能读到 .env?
docker exec jenkins cat /home/ace/monitoring-lab/.env

# 4. 如果以上都 OK，看 Jenkins 构建日志的具体报错
```

---

### 症状 6: `make backup` 报错

**表现**: `Error: No such volume`

**原因**: Docker Compose 卷名前缀随目录名变化

**解决**: 确保 docker-compose.yml 中显式命名了卷（本项目已修复）

---

### 症状 7: Kibana 显示 "Server not ready"

**表现**: 打开 Kibana 页面显示未就绪

**原因**: Kibana 依赖 ES，ES 启动需要 1-2 分钟

**解决**: 等 2-3 分钟再刷新。如果还不好：
```bash
docker logs kb          # 看 Kibana 日志
curl localhost:9200/_cluster/health  # 看 ES 健康状态
```

---

### 症状 8: 告警邮件收不到

**表现**: 删除了 Pod 但没收到邮件

**排查**:
1. `alertmanager.yml` 是否从 `.example` 复制并填入了真实邮箱授权码？
2. 授权码是否正确？（不是 QQ 密码，是 SMTP 授权码）
3. `docker logs alertmanager` 看 SMTP 连接错误
4. Prometheus 告警规则是否加载？访问 http://localhost:9090/rules

---

## 第三步：如果以上都解决不了

1. 执行 `make diagnose` 生成诊断报告
2. 打包发送: `tar czf diagnosis-report.tar.gz diagnosis-*/`
3. 附上以下信息：
   - 操作系统（Ubuntu 22.04 / WSL2 / macOS）
   - 总内存和 CPU 核数
   - 执行到哪一步失败的
   - 具体的报错信息（复制粘贴）
