{{/*
Expand the name of the chart.
*/}}
{{- define "sonarr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "sonarr.fullname" -}}
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
{{- define "sonarr.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sonarr.labels" -}}
helm.sh/chart: {{ include "sonarr.chart" . }}
{{ include "sonarr.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sonarr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sonarr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "sonarr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "sonarr.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Common OpenShift/OKD annotations
*/}}
{{- define "sonarr.commonAnnotations" -}}
openshift.io/generated-by: "Helm"
{{- if .Values.podAnnotations }}
{{- toYaml .Values.podAnnotations }}
{{- end }}
{{- end }}

{{/*
Storage class name helper
*/}}
{{- define "sonarr.storageClassName" -}}
{{- if .storageClass }}
{{- if (eq "-" .storageClass) }}
storageClassName: ""
{{- else }}
storageClassName: {{ .storageClass }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create PVC name for config
*/}}
{{- define "sonarr.configPvcName" -}}
{{- if .Values.persistence.config.existingClaim }}
{{- .Values.persistence.config.existingClaim }}
{{- else }}
{{- include "sonarr.fullname" . }}-config
{{- end }}
{{- end }}

{{/*
Create PVC name for TV
*/}}
{{- define "sonarr.tvPvcName" -}}
{{- if .Values.persistence.tv.existingClaim }}
{{- .Values.persistence.tv.existingClaim }}
{{- else }}
{{- include "sonarr.fullname" . }}-tv
{{- end }}
{{- end }}

{{/*
Create PVC name for downloads
*/}}
{{- define "sonarr.downloadsPvcName" -}}
{{- if .Values.persistence.downloads.existingClaim }}
{{- .Values.persistence.downloads.existingClaim }}
{{- else }}
{{- include "sonarr.fullname" . }}-downloads
{{- end }}
{{- end }}