# advanced/ — 进阶内容（初学者搭建时不需要）

> ⚠️ **重要提示**: 这个目录下的内容在初学者搭建过程中**完全不需要使用**。
> 它们是"生产环境迁移"和"进阶学习"的参考材料。
> 
> 如果你是第一次搭建，请直接跳过这个目录，回到项目根目录执行：
> ```bash
> make phase1   # 启动监控
> ```

## 什么时候需要看这些文件？

### 1. helm-charts/ — 当你理解了原始 YAML 部署后

**原始方式**（初学者用的）:
```bash
kubectl apply -f app-deployment.yaml
kubectl apply -f network-policy.yaml
```
每次改配置都要改 YAML 文件，多个环境（dev/staging/prod）要维护多份几乎相同的文件。

**Helm 方式**（进阶）:
```bash
helm install nginx-dev ./helm-charts/nginx-demo              # 开发环境
helm install nginx-prod ./helm-charts/nginx-demo -f values-production.yaml  # 生产环境
```
一套模板 + 不同的 values 文件 = 多环境管理。

**建议**: 先跑通 `app-deployment.yaml`，理解 Deployment/Service/NetworkPolicy 的概念后，再来看 Helm 是如何把这些抽象为模板的。

### 2. gitops/ — 当你跑通了 Jenkins CI/CD 后

**Jenkins 方式**（初学者用的）:
Jenkins Pipeline 直接执行 `kubectl set image`，属于"命令式"部署。

**GitOps 方式**（进阶）:
用 ArgoCD 监控 Git 仓库，自动把 Git 中的声明式配置同步到集群。
优势：变更可追溯、自动回滚、避免"配置漂移"。

**建议**: 先跑通 Jenkins Pipeline（Phase 3），理解 CI/CD 流程后，再来看 ArgoCD 是如何替代 Jenkins 直接操作 K8s 的。

### 3. terraform/ — 当你要把环境搬到阿里云/腾讯云/AWS 时

**本地方式**（初学者用的）:
Kind 集群 + Docker Compose，零成本，搞坏了 `make clean` 重来。

**Terraform 方式**（进阶）:
用代码创建云厂商的 K8s 集群（如阿里云 ACK）、VPC、交换机等。

**建议**: 本地跑通所有 Phase 后，再考虑用 Terraform 创建生产环境。

## 学习顺序建议

```
Phase 1: make phase1（监控）
  ↓
Phase 2: make phase2（日志）
  ↓
Phase 3: make phase3（CI/CD with Jenkins）
  ↓
【此时你已经掌握了完整的 DevOps 链路】
  ↓
进阶 1: 学习 Helm（helm-charts/）
  ↓
进阶 2: 学习 GitOps（gitops/）
  ↓
进阶 3: 迁移到云厂商（terraform/）
```

## 这些文件会过期吗？

不会。Helm Chart、ArgoCD 配置、Terraform 模板都是**声明式配置**，和具体版本无关（除了镜像标签）。即使 K8s 升级了，这些配置的核心逻辑仍然适用。
