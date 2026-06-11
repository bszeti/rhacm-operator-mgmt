{{/*
Return list items of versions up to targetVersion.
Expects a dict: { "versions": [...], "targetVersion": "..." }
*/}}
{{- define "versionsUpTo" -}}
    {{- $target := required "targetVersion is required" .targetVersion -}}
    {{- $versions := required "versions is required" .versions -}}
    {{- $endIndex := -1 -}}
    {{- range $i, $v := $versions -}}
        {{- if eq $v $target -}}
        {{- $endIndex = $i -}}
        {{- end -}}
    {{- end -}}
    {{- if lt $endIndex 0 -}}
        {{- fail (printf "targetVersion %q not found in operator.versions" $target) -}}
    {{- end -}}
    {{- slice $versions 0 (add $endIndex 1) | mustToJson -}}
{{- end -}}

{{- define "versionsPerEnvironment" -}}
    {{- $environments := required "environments is required" .environments -}}
    {{- $versions := required "versions is required" .versions -}}

    {{- $environmentsWithVersions := list -}}
    {{- range $environments -}}
        {{- $allowedVersionsForEnv := include "versionsUpTo" (dict "versions" $versions "targetVersion" .targetVersion) | fromJsonArray -}}
        {{- $extended := merge (deepCopy .) (dict "allowedVersions" $allowedVersionsForEnv) -}}
        {{- $environmentsWithVersions = append $environmentsWithVersions $extended -}}
    {{- end -}}

    {{- $versionsWithTemplateExpression := list -}}
    {{- range $v := $versions -}}
        
        {{- $environmentNames := list -}}
        {{- range $e := $environmentsWithVersions -}}
            {{- if has $v $e.allowedVersions -}}
                {{- $environmentNames = append $environmentNames $e.name -}}
            {{- end -}}
        {{- end -}}

        {{- if not (empty $environmentNames) -}}
            {{- $envArgs := "" -}}
            {{- range $environmentNames -}}
                {{- $envArgs = printf "%s \"%s\"" $envArgs . -}}
            {{- end -}}
            {{- $s := printf "'{{- if eq (fromClusterClaim \"env\") %s -}}%s{{- end -}}'" $envArgs $v -}}
            {{- $versionsWithTemplateExpression = append $versionsWithTemplateExpression $s -}}
        {{- end -}}
        
    {{- end -}}
    
    {{- $versionsWithTemplateExpression | mustToJson -}}
{{- end -}}