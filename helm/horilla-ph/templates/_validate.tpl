{{/*
Validation: prevent accidental production deployments with default secrets.
This check runs during `helm install` / `helm upgrade` (not `helm template`).
*/}}
{{- define "horilla-ph.validate" -}}
{{- $defaultSecretKey := "change-me-in-production-use-sealed-secrets" }}
{{- $defaultDbPassword := "horilla_secret" }}
{{- if and (ne (toString .Values.app.debug) "true") (eq .Values.appSecrets.secretKey $defaultSecretKey) }}
{{- fail "SECURITY ERROR: appSecrets.secretKey is set to the default placeholder. Set a unique SECRET_KEY before deploying to a non-development environment." }}
{{- end }}
{{- if and (ne (toString .Values.app.debug) "true") .Values.postgresql.enabled (eq .Values.postgresql.auth.password $defaultDbPassword) }}
{{- fail "SECURITY ERROR: postgresql.auth.password is set to the default placeholder. Set a strong password before deploying to a non-development environment." }}
{{- end }}
{{- end -}}
