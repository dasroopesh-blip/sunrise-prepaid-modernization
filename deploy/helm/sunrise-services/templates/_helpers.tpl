{{/*
Common helpers for the sunrise-services chart.
*/}}

{{/* Chart name */}}
{{- define "sunrise.chartName" -}}
{{- .Chart.Name -}}
{{- end -}}

{{/*
Standard labels applied to every object. `svcName` is passed in by the caller
via the loop (dict "svc" $name ...).
*/}}
{{- define "sunrise.labels" -}}
app.kubernetes.io/name: {{ .svc }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/part-of: sunrise
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ .root.Chart.Name }}-{{ .root.Chart.Version }}
{{- end -}}

{{/* Selector labels (subset used for matchLabels / service selector) */}}
{{- define "sunrise.selectorLabels" -}}
app.kubernetes.io/name: {{ .svc }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end -}}

{{/* Fully-qualified image reference for a service config */}}
{{- define "sunrise.image" -}}
{{- $reg := .root.Values.global.imageRegistry -}}
{{- printf "%s/%s:%s" $reg .cfg.image .cfg.tag -}}
{{- end -}}
