# ============================================================================
# 文件: Makefile
# 作用: 封装日常操作命令，降低初学者记忆负担
#
# 什么是 Makefile:
#   定义一系列"目标"和对应的"命令"
#   用户只需记住目标名（如 make phase1），不需要记复杂的命令
#
# 用法:
#   make help        # 查看所有可用命令（初学者从这里开始）
#   make install     # 安装依赖
#   make check       # 检查环境
#   make phase1      # 启动监控（4GB内存）
#   make phase2      # 加日志（+2GB）
#   make phase3      # 加CI/CD（+2GB）
#   make full        # 全部启动（8GB+）
#
# 注意: 命令前的缩进必须是 Tab 键，不能用空格
# ============================================================================

# .PHONY: 声明这些目标不对应实际文件
# 防止有同名文件时 Make 误判（比如有个文件叫 "help"，make help 会以为文件已存在）
.PHONY: help install check phase1 phase2 phase3 full down test status logs clean backup restore diagnose helm-lint security-scan

# ---------- 默认目标: 输入 make 不带参数时执行 ----------
# help 目标显示所有可用命令和说明，是初学者的"导航页"
help: ## 显示帮助信息（初学者从这里开始）
	@echo "DevOps Platform Lab - 初学者友好命令"
	@echo ""
	@echo "  第一步: 安装依赖"
	@echo "    make install          一键安装 Docker/kubectl/Kind/Helm"
	@echo ""
	@echo "  第二步: 检查环境"
	@echo "    make check            检查前置条件是否满足"
	@echo ""
	@echo "  第三步: 分阶段部署（推荐初学者按顺序执行）"
	@echo "    make phase1           启动监控（Prometheus+Grafana，需4GB内存）"
	@echo "    make phase2           加日志（+ES+Kibana，需+2GB内存）"
	@echo "    make phase3           加CI/CD（+Jenkins+Registry，需+2GB内存）"
	@echo "    make full             一键启动全部（需8GB+内存）"
	@echo ""
	@echo "  日常维护:"
	@echo "    make test             冒烟测试当前阶段"
	@echo "    make status           查看所有服务状态"
	@echo "    make logs             查看所有服务日志"
	@echo "    make diagnose         出问题时收集诊断信息"
	@echo "    make down             停止服务（保留数据）"
	@echo "    make clean            彻底清理（删除所有数据）"
	@echo "    make backup           备份关键数据卷"
	@echo "    make restore          从备份恢复"
	@echo "    make helm-lint        检查 Helm Chart 语法"
	@echo "    make security-scan    镜像安全扫描"

# ---------- 安装依赖 ----------
# 为什么需要: 初学者可能不知道要装哪些工具，这个脚本自动检测并安装
install: ## 一键安装所有依赖（Docker/kubectl/Kind/Helm/jq）
	bash scripts/install-deps.sh

# ---------- 环境检查 ----------
# 为什么需要: 在部署前检查内存/CPU/端口/命令，避免跑到一半报错
check: ## 检查前置条件（内存/CPU/端口/命令）
	bash scripts/check-prereqs.sh

# ---------- Phase 1: 监控 ----------
# 只启动 monitoring profile 的服务（Prometheus + Grafana + Node Exporter）
# 内存需求最低，建议所有初学者先跑通这个阶段
phase1: ## 启动 Phase 1: 监控（Prometheus + Grafana + Node Exporter）
	@echo "===== Phase 1: 启动监控服务 ====="
	@bash scripts/check-prereqs.sh || { echo "[!] 前置检查未通过，请修复后重试"; exit 1; }
	@source ./setup-env.sh
	@docker compose --profile monitoring up -d
	@echo ""
	@echo "[OK] Phase 1 启动完成！"
	@echo "  Prometheus:    http://localhost:9090"
	@echo "  Grafana:       http://localhost:3000 (admin/admin)"
	@echo "  Node Exporter: http://localhost:9100"
	@echo ""
	@echo "  如果浏览器打不开，试试: make diagnose"

# ---------- Phase 2: 日志 ----------
# 加 logging profile 的服务（Elasticsearch + Kibana）
# 需要先调整 vm.max_map_count（ES 需要）
phase2: ## 启动 Phase 2: 日志（+ Elasticsearch + Kibana）
	@echo "===== Phase 2: 启动日志服务 ====="
	@sudo sysctl -w vm.max_map_count=262144 >/dev/null 2>&1 || true
	@docker compose --profile logging up -d
	@echo ""
	@echo "[OK] Phase 2 启动完成！"
	@echo "  Kibana:        http://localhost:5601"
	@echo "  Elasticsearch: http://localhost:9200"
	@echo ""
	@echo "  注意: Kibana 启动较慢，请等待 1-2 分钟后访问"

# ---------- Phase 3: CI/CD ----------
# 加 cicd profile 的服务（Jenkins + Registry）
# Jenkins 首次启动需要初始化（安装插件、创建管理员账号）
phase3: ## 启动 Phase 3: CI/CD（+ Jenkins + Registry）
	@echo "===== Phase 3: 启动 CI/CD 服务 ====="
	@docker compose --profile cicd up -d
	@echo ""
	@echo "[OK] Phase 3 启动完成！"
	@echo "  Jenkins:       http://localhost:8081"
	@echo "  Registry:      http://localhost:5000"
	@echo ""
	@echo "  Jenkins 初始密码:"
	@echo "    docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
	@echo ""
	@echo "  配置 Jenkins Pipeline:"
	@echo "    bash scripts/setup-jenkins.sh"

# ---------- 全部启动 ----------
# 一次性启动所有服务，需要 8GB+ 内存
# 内部调用 deploy.sh，包含镜像预拉取、Kind 集群创建、端口转发等
full: ## 一键启动全部服务（需要 8GB+ 内存）
	@bash scripts/check-prereqs.sh || { echo "[!] 前置检查未通过"; exit 1; }
	@source ./setup-env.sh
	@sudo sysctl -w vm.max_map_count=262144 >/dev/null 2>&1 || true
	@bash scripts/deploy.sh

# ---------- 停止服务 ----------
# docker compose down: 停止并删除容器，但保留命名卷（数据不丢）
down: ## 停止当前运行的服务（保留数据卷）
	@docker compose --profile monitoring --profile logging --profile cicd down
	@echo "[OK] 服务已停止，数据保留在 Docker Volumes 中"

# ---------- 冒烟测试 ----------
# 逐个检查服务是否正常运行，输出 [OK] 或 [FAIL]
test: ## 冒烟测试
	@bash scripts/test.sh

# ---------- 查看状态 ----------
# 同时显示 Docker Compose 容器状态和 K8s Pod/Node 状态
status: ## 查看所有服务状态
	@echo "=== Docker Compose 服务 ==="
	@docker compose ps
	@echo ""
	@echo "=== K8s Pods ==="
	@kubectl get pods 2>/dev/null || echo "  [INFO] K8s 集群未启动或 kubectl 未配置"
	@echo ""
	@echo "=== K8s Nodes ==="
	@kubectl get nodes 2>/dev/null || echo "  [INFO] K8s 集群未启动"

# ---------- 查看日志 ----------
# -f: 持续跟踪（类似 tail -f），按 Ctrl+C 退出
logs: ## 查看所有服务日志
	@docker compose logs -f

# ---------- 深度清理 ----------
# docker compose down -v: 删除容器和命名卷（数据丢失！）
# kind delete cluster: 删除 Kind K8s 集群
# 相当于"恢复出厂设置"
clean: ## 深度清理（含数据卷+Kind集群）
	@docker compose --profile monitoring --profile logging --profile cicd down -v
	@kind delete cluster 2>/dev/null || true
	@echo "[OK] 深度清理完成，所有数据卷和 Kind 集群已删除"

# ---------- 备份 ----------
# 利用 Docker 卷挂载机制，启动临时 Alpine 容器打包数据
# 备份文件存放在 backups/ 目录，文件名包含时间戳
backup: ## 备份关键数据卷到 backups/ 目录
	@mkdir -p backups
	@echo "备份 Prometheus..."
	@docker run --rm -v devops_prometheus_data:/data -v $(PWD)/backups:/backup alpine tar czf /backup/prometheus_$$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@echo "备份 Grafana..."
	@docker run --rm -v devops_grafana_data:/data -v $(PWD)/backups:/backup alpine tar czf /backup/grafana_$$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@echo "备份 ES..."
	@docker run --rm -v devops_es_data:/data -v $(PWD)/backups:/backup alpine tar czf /backup/es_$$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@echo "备份 Jenkins..."
	@docker run --rm -v devops_jenkins_home:/data -v $(PWD)/backups:/backup alpine tar czf /backup/jenkins_$$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@echo "[OK] 备份完成，存放在 backups/ 目录"

# ---------- 恢复 ----------
# 用法: make restore BACKUP=backups/prometheus_20260115_143022.tar.gz VOLUME=prometheus_data
# 恢复后需要重启对应服务: docker compose restart <服务名>
restore: ## 从备份文件恢复数据卷（用法: make restore BACKUP=... VOLUME=...）
	@if [ -z "$(BACKUP)" ] || [ -z "$(VOLUME)" ]; then \
		echo "用法: make restore BACKUP=backups/xxx.tar.gz VOLUME=prometheus_data"; \
		exit 1; \
	fi
	@docker run --rm -v devops_$(VOLUME):/data -v $(PWD)/$(BACKUP):/backup.tar.gz alpine sh -c "rm -rf /data/* && tar xzf /backup.tar.gz -C /data"
	@echo "[OK] 已恢复 $(VOLUME) 从 $(BACKUP)"

# ---------- 诊断 ----------
# 出问题时运行，自动收集系统资源、容器状态、K8s 事件、日志等
diagnose: ## 一键收集诊断信息（出问题时运行这个）
	@bash scripts/diagnose.sh

# ---------- Helm 语法检查 ----------
# helm lint: 检查 Chart.yaml、values.yaml、模板语法等
helm-lint: ## [v5] 检查 Helm Chart 语法
	@if [ -d "advanced/helm-charts/nginx-demo" ]; then \
		helm lint advanced/helm-charts/nginx-demo; \
	else \
		echo "[WARN] Helm Chart 目录不存在"; \
	fi

# ---------- 安全扫描 ----------
# 调用 scripts/security-scan.sh，用 Trivy 扫描镜像漏洞
security-scan: ## [v5] 镜像安全扫描
	@bash scripts/security-scan.sh
