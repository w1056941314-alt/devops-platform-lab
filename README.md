# DevOps Platform Lab — 云原生运维实践平台

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **版本**: v5.1（初学者友好版）  
> **定位**: 从零开始、分阶段学习的 DevOps 实验环境。你不需要一次跑通所有东西，**跑通 Phase 1 就算成功**。

## ⚠️ 诚实声明

这个项目**对纯新手确实有门槛**。你需要：
- 一台至少有 **4GB 空闲内存** 的电脑（8GB 总内存勉强够 Phase 1）
- 愿意阅读报错信息并搜索解决方案的耐心
- 大约 **2-3 小时** 的连续时间（第一次搭建）

**如果你连 Docker 是什么都不知道**，建议先去 [Docker 官方教程](https://docs.docker.com/get-started/) 花 30 分钟跑一遍 `docker run hello-world`。

## 技术栈

| 组件 | 用途 | Phase | 必需？ |
|------|------|-------|--------|
| Prometheus | 指标采集 | 1 | ✅ 必学 |
| Grafana | 可视化大盘 | 1 | ✅ 必学 |
| Node Exporter | 宿主机指标 | 1 | ✅ 必学 |
| Elasticsearch | 日志存储 | 2 | ✅ 必学 |
| Kibana | 日志查询 | 2 | ✅ 必学 |
| Fluentd | 日志采集 | 2 | ✅ 必学 |
| Jenkins | CI/CD 引擎 | 3 | ✅ 必学 |
| Registry | 镜像仓库 | 3 | ✅ 必学 |
| Helm | 包管理 | — | ❌ 进阶（见 advanced/） |
| ArgoCD | GitOps | — | ❌ 进阶（见 advanced/） |
| Terraform | 基础设施即代码 | — | ❌ 进阶（见 advanced/） |

## 下载后第一步（必须执行）

```bash
# 1. 进入项目目录
cd devops-platform-lab

# 2. 加载环境变量并生成配置文件（会自动替换所有路径和网关地址）
source ./setup-env.sh

# 如果看到 "[OK] Docker 网关已检测" 和 "配置生成完成"，说明成功了
# 如果报错，请检查 Docker 是否正在运行
```

> **重要**: `setup-env.sh` 会**自动生成** `kind-config.yaml`、`prometheus.yml`、`fluentd-daemonset.yaml`，并更新 `docker-compose.yml` 中的家目录路径。**不要手动编辑这些文件**，否则换电脑后路径会出错。

## 快速开始（3 步）

```bash
# 第 1 步：安装依赖（如果已安装 Docker/kubectl/Kind，可跳过）
make install

# 第 2 步：检查环境
make check

# 第 3 步：启动 Phase 1（监控）
make phase1
```

然后打开浏览器访问：
- **Grafana**: http://localhost:3000（账号 admin/admin）
- **Prometheus**: http://localhost:9090

**如果这一步成功了，恭喜你，你已经跑通了 DevOps 的第一个链路！**

## 分阶段学习路径

```
Phase 1: 监控入门（4GB 内存）
    └── 目标：学会看 Grafana 大盘，理解 Prometheus 指标
    └── 预计时间：30 分钟
    └── 命令：make phase1
    └── 如果卡住了：跳过 Phase 2/3，先玩熟这个

Phase 2: 日志收集（+2GB 内存）
    └── 目标：在 Kibana 里查到容器日志
    └── 预计时间：20 分钟
    └── 命令：make phase2
    └── 如果卡住了：ES 启动慢是正常的，等 2-3 分钟

Phase 3: CI/CD 流水线（+2GB 内存）
    └── 目标：改一行代码，Jenkins 自动构建并部署到 K8s
    └── 预计时间：40 分钟（Jenkins 初始化占一半）
    └── 命令：make phase3
    └── 如果卡住了：Jenkins 配置可以手动在 Web UI 完成

【此时你已经掌握了完整的 DevOps 链路】

进阶：Helm + GitOps + Terraform（见 advanced/ 目录）
    └── 什么时候学：本地跑通所有 Phase 后
    └── 用途：生产环境迁移、多环境管理、基础设施自动化
```

## 项目结构

```
.
├── Makefile                    # ✅ 必学：一键命令（make phase1/phase2/phase3）
├── docker-compose.yml          # ✅ 必学：外部服务编排（Prometheus/Grafana/ES/Jenkins）
├── kind-config.yaml            # ✅ 必学：K8s 集群配置
├── setup-env.sh                # ✅ 必学：自动检测 Docker 网关
├── .env.example                # ✅ 必学：环境变量模板
├── .gitignore                  # ✅ 必学：敏感信息保护
├── .dockerignore               # ✅ 必学：Docker 构建优化
├── prometheus.yml              # ✅ 必学：监控抓取配置
├── alert.rules.yml             # ✅ 必学：告警规则
├── alertmanager.yml.example    # ✅ 必学：邮件告警模板（需复制为 alertmanager.yml）
├── app-deployment.yaml         # ✅ 必学：K8s 业务应用（Nginx + Sidecar）
├── fluentd-daemonset.yaml    # ✅ 必学：K8s 日志采集器
├── network-policy.yaml         # ✅ 必学：网络隔离策略
├── Jenkinsfile                 # ✅ 必学：CI/CD Pipeline 定义
├── myapp-example/              # ✅ 必学：示例应用代码（复制到 ~/myapp）
│   ├── index.html
│   ├── Dockerfile
│   └── README.md
├── scripts/                    # ✅ 必学：自动化脚本
│   ├── install-deps.sh         # 一键安装依赖
│   ├── check-prereqs.sh        # 环境检查
│   ├── deploy.sh               # 一键部署
│   ├── setup-jenkins.sh        # Jenkins 配置引导
│   ├── test.sh                 # 冒烟测试
│   ├── diagnose.sh             # 诊断信息收集
│   ├── cleanup.sh              # 清理环境
│   └── security-scan.sh        # 镜像安全扫描
├── docs/
│   └── troubleshooting.md      # ✅ 必学：故障排查指南
├── advanced/                   # ❌ 进阶：初学者搭建时不需要
│   ├── README.md               # 进阶内容说明和学习顺序
│   ├── helm-charts/            # Helm Chart（生产环境包管理）
│   ├── gitops/                 # ArgoCD 配置（声明式持续交付）
│   └── terraform/              # 阿里云 ACK 模板（基础设施即代码）
├── .github/workflows/ci.yml    # CI 工作流（GitHub 自动检查）
├── CHANGELOG.md
├── LICENSE
└── README.md
```

> **初学者只需要关注根目录和 scripts/ 目录的文件。**  
> `advanced/` 目录下的内容在搭建过程中完全不需要使用。

## 日常命令

```bash
make help        # 查看所有可用命令
make status      # 看服务状态
make test        # 冒烟测试
make diagnose    # 出问题时收集诊断信息
make down        # 停止服务（保留数据）
make clean       # 彻底清理（删除所有数据）
```

## 常见问题（FAQ）

### Q1: 浏览器打不开 localhost:3000？

**WSL2 用户**：在 WSL2 终端执行 `ip addr | grep eth0`，用 `http://<IP>:3000` 访问  
**Mac 用户**：检查 Docker Desktop 端口映射  
**Linux 用户**：`sudo ufw status` 看防火墙是否拦截

### Q2: `make check` 报内存不足？

- **WSL2**: 在 Windows 创建 `C:\Users\<你>\.wslconfig`：
  ```
  [wsl2]
  memory=8GB
  processors=4
  ```
  保存后执行 `wsl --shutdown`，重新打开 WSL2
- **Mac**: Docker Desktop -> Settings -> Resources -> Memory 调到 8GB
- **如果只有 4GB 总内存**：只能跑 `make phase1`，Phase 2/3 会 OOM

### Q3: Elasticsearch 启动后自动退出？

执行 `sudo sysctl -w vm.max_map_count=262144`  
Mac 用户通过 Docker Desktop 设置（见上方）。

### Q4: Jenkins 构建失败？

1. `docker exec jenkins docker ps` — 看 Jenkins 里能不能用 Docker
2. `docker exec jenkins kubectl get nodes` — 看 Jenkins 里能不能连 K8s
3. `docker exec jenkins cat /home/ace/monitoring-lab/.env` — 看 .env 是否挂载成功

### Q5: advanced/ 目录里的文件什么时候用？

**答案是：搭建过程中完全不需要。**

- `helm-charts/`: 当你理解了 `app-deployment.yaml` 后，学习如何用 Helm 管理多环境
- `gitops/`: 当你跑通了 Jenkins Pipeline 后，学习如何用 ArgoCD 替代 Jenkins 直接操作 K8s
- `terraform/`: 当你要把环境搬到阿里云/腾讯云/AWS 时

建议的学习顺序见 `advanced/README.md`。

## 安全声明

- **本地学习专用**，生产环境需要：Harbor + TLS + 认证、ES 安全认证、Jenkins Kubernetes Agent
- Registry 无认证，不要暴露到公网
- `.env` 和 `alertmanager.yml` 含敏感信息，已加入 `.gitignore`

## License

[MIT](LICENSE)
