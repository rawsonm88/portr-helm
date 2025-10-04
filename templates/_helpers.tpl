{{/*
Expand the name of the chart.
*/}}
{{- define "portr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "portr.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "portr.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "portr.labels" -}}
helm.sh/chart: {{ include "portr.chart" . }}
{{ include "portr.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "portr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "portr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Admin component labels
*/}}
{{- define "portr.admin.labels" -}}
{{ include "portr.labels" . }}
app.kubernetes.io/component: admin
{{- end }}

{{/*
Admin selector labels
*/}}
{{- define "portr.admin.selectorLabels" -}}
{{ include "portr.selectorLabels" . }}
app.kubernetes.io/component: admin
{{- end }}

{{/*
Tunnel component labels
*/}}
{{- define "portr.tunnel.labels" -}}
{{ include "portr.labels" . }}
app.kubernetes.io/component: tunnel
{{- end }}

{{/*
Tunnel selector labels
*/}}
{{- define "portr.tunnel.selectorLabels" -}}
{{ include "portr.selectorLabels" . }}
app.kubernetes.io/component: tunnel
{{- end }}

{{/*
PostgreSQL component labels
*/}}
{{- define "portr.postgresql.labels" -}}
{{ include "portr.labels" . }}
app.kubernetes.io/component: postgresql
{{- end }}

{{/*
PostgreSQL selector labels
*/}}
{{- define "portr.postgresql.selectorLabels" -}}
{{ include "portr.selectorLabels" . }}
app.kubernetes.io/component: postgresql
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "portr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "portr.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PostgreSQL connection string
*/}}
{{- define "portr.postgresql.connectionString" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgres://%s:%s@%s-postgresql:%d/%s" .Values.postgresql.auth.username (.Values.postgresql.auth.password | urlquery) (include "portr.fullname" .) (int .Values.postgresql.service.port) .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.externalDatabase.connectionString }}
{{- end }}
{{- end }}

{{/*
PostgreSQL host
*/}}
{{- define "portr.postgresql.host" -}}
{{- printf "%s-postgresql" (include "portr.fullname" .) }}
{{- end }}

{{/*
Admin service name
*/}}
{{- define "portr.admin.serviceName" -}}
{{- printf "%s-admin" (include "portr.fullname" .) }}
{{- end }}

{{/*
Tunnel service name
*/}}
{{- define "portr.tunnel.serviceName" -}}
{{- printf "%s-tunnel" (include "portr.fullname" .) }}
{{- end }}

{{/*
PostgreSQL service name
*/}}
{{- define "portr.postgresql.serviceName" -}}
{{- printf "%s-postgresql" (include "portr.fullname" .) }}
{{- end }}
