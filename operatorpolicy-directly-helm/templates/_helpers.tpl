{{/*
Find an item in a list of objects by its "name" field.
Expects a dict: { "list": [...], "name": "qa" }
Returns the matching object as JSON (use with fromJson at the call site).
*/}}
{{- define "findByNameInList" -}}
    {{- $name := required "name is required" .name -}}
    {{- $list := required "list is required" .list -}}
    {{- $found := dict -}}
    {{- range $list -}}
        {{- if eq .name $name -}}
            {{- $found = . -}}
        {{- end -}}
    {{- end -}}
    {{- if empty $found -}}
        {{- fail (printf "no item with name %q found in environments list" $name) -}}
    {{- end -}}
    {{- $found | mustToJson -}}
{{- end -}}


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
    {{- slice $versions 0 (add $endIndex 1) | toYaml -}}
{{- end -}}