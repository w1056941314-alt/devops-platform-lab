{{/* ==========================================================================
   文件: _helpers.tpl
   作用: Helm Chart 的"辅助函数"模板

   什么是 _helpers.tpl:
     Helm 的模板文件，定义可复用的命名规则
     其他模板通过 {{ include "函数名" . }} 调用这些函数

   为什么需要:
     避免在多个模板中重复写相同的命名逻辑
     确保所有资源名称一致（如 Deployment 和 Service 同名）
   ========================================================================== */}}

{{/*
   函数: nginx-demo.name
   作用: 生成 Chart 的基础名称
   逻辑: 优先使用 .Values.nameOverride，否则用 Chart.Name
         trunc 63: K8s 资源名最长 63 字符，超出截断
         trimSuffix "-": 去掉末尾的连字符
*/}}
{{- define "nginx-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
   函数: nginx-demo.fullname
   作用: 生成完整的资源名称（Release 名 + Chart 名）
   逻辑:
     1. 如果用户指定了 fullnameOverride，直接用
     2. 否则组合 Release.Name 和 Chart 名
     3. 如果 Release.Name 已包含 Chart 名，不再重复
   示例:
     helm install myapp ./nginx-demo -> myapp-nginx-demo
     helm install nginx-demo ./nginx-demo -> nginx-demo（不重复）
*/}}
{{- define "nginx-demo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
   函数: nginx-demo.labels
   作用: 生成标准 K8s 标签集合
   包含:
     helm.sh/chart: Chart 名和版本（用于追踪来源）
     app.kubernetes.io/version: 应用版本
     app.kubernetes.io/managed-by: 管理工具（Helm）
*/}}
{{- define "nginx-demo.labels" -}}
helm.sh/chart: {{ include "nginx-demo.chart" . }}
{{ include "nginx-demo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
   函数: nginx-demo.selectorLabels
   作用: 生成用于选择器的标签（Service 匹配 Pod 用）
   注意: 这些标签一旦确定就不能随意更改，否则 Service 会找不到 Pod
*/}}
{{- define "nginx-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nginx-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
   函数: nginx-demo.chart
   作用: 生成 Chart 标签值（名-版本）
   replace "+" "_": Helm 版本号可能包含 +，K8s 标签不允许 +，替换为 _
*/}}
{{- define "nginx-demo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
