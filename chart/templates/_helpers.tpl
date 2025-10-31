{{/*
Expand the name of the chart.
*/}}
{{- define "media-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "media-stack.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "media-stack.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "media-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "media-stack.labels" -}}
helm.sh/chart: {{ include "media-stack.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Generate fullname for a specific app
Usage: include "media-stack.appFullname" (dict "root" . "app" "jellyfin")
*/}}
{{- define "media-stack.appFullname" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{- printf "%s-%s" (include "media-stack.fullname" $root) $app | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
App-specific labels
Usage: include "media-stack.appLabels" (dict "root" . "app" "jellyfin")
*/}}
{{- define "media-stack.appLabels" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{ include "media-stack.labels" $root }}
app.kubernetes.io/name: {{ $app }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/component: {{ $app }}
{{- end }}

{{/*
Selector labels for an app
Usage: include "media-stack.appSelectorLabels" (dict "root" . "app" "jellyfin")
*/}}
{{- define "media-stack.appSelectorLabels" -}}
{{- $root := .root -}}
{{- $app := .app -}}
app.kubernetes.io/name: {{ $app }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use for an app
Usage: include "media-stack.serviceAccountName" (dict "root" . "app" "jellyfin")
*/}}
{{- define "media-stack.serviceAccountName" -}}
{{- $root := .root -}}
{{- $app := .app -}}
{{- $values := index $root.Values $app -}}
{{- if $values.serviceAccount.create }}
{{- default (include "media-stack.appFullname" (dict "root" $root "app" $app)) $values.serviceAccount.name }}
{{- else }}
{{- default "default" $values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Storage class name helper
*/}}
{{- define "media-stack.storageClassName" -}}
{{- if .storageClass }}
{{- if (eq "-" .storageClass) }}
storageClassName: ""
{{- else }}
storageClassName: {{ .storageClass }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Get timezone from global or default
*/}}
{{- define "media-stack.timezone" -}}
{{- .Values.global.timezone | default "UTC" }}
{{- end }}
