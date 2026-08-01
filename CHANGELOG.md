# Changelog

## [v5.1] - 2026-07-31

### 改进初学者体验
- **分阶段部署**: docker-compose.yml 支持 `--profile`（monitoring/logging/cicd/full）
- **一键安装依赖**: `scripts/install-deps.sh` 自动安装 Docker/kubectl/Kind/Helm/jq
- **前置检查**: `scripts/check-prereqs.sh` 检查内存/CPU/端口/命令
- **分阶段 Makefile**: `make phase1/phase2/phase3/full`，降低挫败感
- **Jenkins 自动配置提示**: `scripts/setup-jenkins.sh` 引导用户完成配置
- **详细错误提示**: deploy.sh/test.sh 每个步骤都有"如果失败了怎么办"
- **故障排查文档**: `docs/troubleshooting.md` 覆盖 8 大常见问题
- **诚实声明**: README 明确说明门槛和预期时间

## [v5.0] - 2026-07-31

### Added
- 补全所有截断 YAML
- Helm Chart 封装
- ArgoCD GitOps 配置
- Terraform 阿里云 ACK 模板
- Trivy 镜像安全扫描
- Cosign 镜像签名
- NetworkPolicy 网络隔离

## [v4.0] - 2026-07-23

### Added
- Makefile 封装
- 数据备份与恢复
- 一键诊断脚本
- ArgoCD GitOps 演进路径

## [v3.0] - 2026-07-23

### Added
- 健康探针
- 日志轮转
- 权限加固
- 功能验证清单

## [v2.0] - 2026-07-22

### Fixed
- Jenkins 挂载 Bug
- ES 冒烟测试优化

## [v1.0] - 2026-07-22

### Added
- 初始版本
