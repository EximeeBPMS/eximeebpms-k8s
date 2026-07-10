{{/*
A template to handle constraints.
*/}}

{{/*
Fail in case H2 database is used and replicaCount is more than "1".
*/}}
{{- if eq (include "eximeebpms.h2DatabaseIsUsed" .) "true" }}
{{- if gt (.Values.general.replicaCount | int) 1 }}
    {{ fail "Deployment replicaCount cannot be more than 1 when the H2 database is used. Configure an external database (see values-ha.yaml) for multi-replica/HA deployments." }}
{{- end }}
{{- end }}
