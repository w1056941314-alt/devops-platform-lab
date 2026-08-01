# ============================================================================
# 文件: terraform/variables.tf
# 作用: 定义 Terraform 变量的类型、默认值和描述
#
# 什么是变量:
#   把配置中可能变化的部分抽象为变量
#   部署时可以通过命令行、环境变量或 tfvars 文件传入不同值
#
# 用法:
#   terraform plan -var="region=cn-beijing"    # 命令行传入
#   export TF_VAR_region=cn-beijing            # 环境变量传入
#   terraform plan -var-file="prod.tfvars"     # 文件传入
# ============================================================================

# region: 阿里云区域
# 不同区域的价格、可用区、实例类型不同
# 国内用户通常选 cn-hangzhou（杭州）或 cn-beijing（北京）
variable "region" {
  description = "阿里云区域"
  type        = string
  default     = "cn-hangzhou"
}

# zone_id: 可用区 ID
# 一个区域包含多个可用区（独立的数据中心）
# 多可用区部署可以实现高可用（一个可用区故障不影响其他可用区）
variable "zone_id" {
  description = "可用区 ID"
  type        = string
  default     = "cn-hangzhou-h"
}

# cluster_name: 集群名称
# 用于命名 VPC、交换机、ACK 集群等资源，便于识别
variable "cluster_name" {
  description = "集群名称"
  type        = string
  default     = "devops-lab-prod"
}
