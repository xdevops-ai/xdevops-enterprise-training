{{- define "xdevops-training.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "xdevops-training.image" -}}
{{- $root := index . 0 -}}
{{- $name := index . 1 -}}
{{- if $root.Values.global.imageRegistry -}}
{{ printf "%s/%s:%s" $root.Values.global.imageRegistry $name $root.Values.global.imageTag }}
{{- else -}}
{{ printf "%s:%s" $name $root.Values.global.imageTag }}
{{- end -}}
{{- end -}}
