{{/*
Return a sublist of versions from the first up to the expected targetVersion.
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

{{/*
Generates the RHACM template expressions around each versions based on the "env" cluster label where they are needed.
Expects a dict: { "environments": [...], "versions": "[...]" }
*/}}
{{- define "versionsPerEnvironment" -}}
    {{- $environments := required "environments is required" .environments -}}
    {{- $versions := required "versions is required" .versions -}}

    {{/* Go through environments and extend with the list of allowed versions  */}}
    {{- $environmentsWithVersions := list -}}
    {{- range $environments -}}
        {{- $allowedVersionsForEnv := include "versionsUpTo" (dict "versions" $versions "targetVersion" .targetVersion) | fromJsonArray -}}
        {{- $extended := merge (deepCopy .) (dict "allowedVersions" $allowedVersionsForEnv) -}}
        {{- $environmentsWithVersions = append $environmentsWithVersions $extended -}}
    {{- end -}}

    {{/* Go through version list and add template expressions based on which environment allows them */}}
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