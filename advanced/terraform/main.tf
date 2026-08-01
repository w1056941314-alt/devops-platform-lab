# 文件: terraform/main.tf
# 作用: 使用 Terraform 创建阿里云 ACK 集群（示例）
# 用法: terraform init && terraform plan && terraform apply

terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.200"
    }
  }
}

provider "alicloud" {
  region = var.region
}

# 创建 VPC
resource "alicloud_vpc" "main" {
  vpc_name   = "${var.cluster_name}-vpc"
  cidr_block = "10.0.0.0/16"
}

# 创建交换机
resource "alicloud_vswitch" "main" {
  vswitch_name = "${var.cluster_name}-vswitch"
  vpc_id       = alicloud_vpc.main.id
  cidr_block   = "10.0.1.0/24"
  zone_id      = var.zone_id
}

# 创建 ACK 托管集群
resource "alicloud_cs_managed_kubernetes" "main" {
  name                = var.cluster_name
  cluster_spec        = "ack.pro.small"
  version             = "1.32.0-aliyun.1"
  vpc_id              = alicloud_vpc.main.id
  vswitch_ids         = [alicloud_vswitch.main.id]
  new_nat_gateway     = true
  load_balancer_spec  = "slb.s2.small"
  worker_instance_types = ["ecs.g7.xlarge"]
  worker_number       = 3
  worker_vswitch_ids  = [alicloud_vswitch.main.id]
  # 启用日志服务
  enable_sls_log      = true
  # 启用监控
  enable_monitoring   = true
}

# 输出 kubeconfig
output "kubeconfig" {
  value     = alicloud_cs_managed_kubernetes.main.kube_config
  sensitive = true
}
