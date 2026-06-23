# Create Policy on a Hub cluster

The most common - and recommended - approach with RHACM is to create a _Policy_ object on the Hub cluster, which includes `OperatorPolicy` and `ConfigurationPolicy` items enforced on the managed clusters based on _Placement_ rules. These policies show up on the _Policy table_ on the UI under _Governance_ as expected. This Helm chart follows this pattern and it should be deployed only on the Hub cluster, which takes care of creating the required resources on the managed clusters afterwards. 

For example first we can deploy the _OpenShift Pipelines Operator_ in the "qa", "uat" and "prod" environments - that are expected to have a matching `env` label: 

```yaml
# In values-pipelines.yaml...
environments:
  - name: qa
    targetVersion: openshift-pipelines-operator-rh.v1.15.4
  - name: uat
    targetVersion: openshift-pipelines-operator-rh.v1.15.4
  - name: prod
    targetVersion: openshift-pipelines-operator-rh.v1.15.4
```

Deploy Helm chart:
```
# Login to the Hub cluster and run:
helm upgrade -i openshift-pipelines-operator ./operatorpolicy-policy-template -f ./operatorpolicy-policy-template/values-pipelines.yaml
```

To upgrade operator versions in QA and UAT, change their `targetVersion` and run the `helm` command again:
```yaml
# In values-pipelines.yaml...
environments:
  - name: qa
    targetVersion: openshift-pipelines-operator-rh.v1.18.1
  - name: uat
    targetVersion: openshift-pipelines-operator-rh.v1.16.4
  - name: prod
    targetVersion: openshift-pipelines-operator-rh.v1.15.4
```

This will generate a `Policy` with an `OperatorPolicy` - and a `ConfigurationPolicy` for its namespace - but each version is surrounded by a template expression to limit which environments can have the given version. These expressions are evaluated on the managed cluster based on the `env` label they have and RHACM will approve _InstallPlans_ only for versions allowed for that cluster:
```yaml
# Source: operatorpolicy-policy-template/templates/policy.yaml
apiVersion: policy.open-cluster-management.io/v1
kind: Policy
metadata:
  name: openshift-pipelines-operator
  namespace: open-cluster-policies
spec:
  disabled: false
  policy-templates:
    ...
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1beta1
        kind: OperatorPolicy
        metadata:
          name: openshift-pipelines-operator
        spec:
          remediationAction: enforce
          complianceType: '{{hub if (fromConfigMap "" (printf "openshift-pipelines-operator-%s" .ManagedClusterLabels.env) "disabled" | default "false" | toBool) hub}}mustnothave{{hub else hub}}musthave{{hub end hub}}'
          severity: critical
          subscription:
            name: openshift-pipelines-operator-rh
            namespace: openshift-pipelines-operator
            source: redhat-operators
            sourceNamespace: openshift-marketplace
            channel: latest
            startingCSV: '{{hub fromConfigMap "" (printf "openshift-pipelines-operator-%s" .ManagedClusterLabels.env) "targetVersion" hub}}'
          upgradeApproval: Automatic
          versions:
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" "prod" -}}openshift-pipelines-operator-rh.v1.15.0{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" "prod" -}}openshift-pipelines-operator-rh.v1.15.1{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" "prod" -}}openshift-pipelines-operator-rh.v1.15.2{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" "prod" -}}openshift-pipelines-operator-rh.v1.15.3{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" "prod" -}}openshift-pipelines-operator-rh.v1.15.4{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" -}}openshift-pipelines-operator-rh.v1.16.0{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" -}}openshift-pipelines-operator-rh.v1.16.1{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" -}}openshift-pipelines-operator-rh.v1.16.2{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" -}}openshift-pipelines-operator-rh.v1.16.3{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" "uat" -}}openshift-pipelines-operator-rh.v1.16.4{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" -}}openshift-pipelines-operator-rh.v1.17.0{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" -}}openshift-pipelines-operator-rh.v1.17.1{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" -}}openshift-pipelines-operator-rh.v1.17.2{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" -}}openshift-pipelines-operator-rh.v1.18.0{{- end -}}'
            - '{{- if eq (fromClusterClaim "env")  "qa" -}}openshift-pipelines-operator-rh.v1.18.1{{- end -}}'
```

The Helm chart requires the - ordered - list of available operator versions in the desired channel, which can be queried by a command like this:

    oc get packagemanifest openshift-pipelines-operator-rh -o jsonpath='{range .status.channels[?(@.name == "latest")].entries[::]}- {.name}{"\n"}{end}' | tac

Additional notes:

- The `eq` function allows more than two arguments. It compares the first argument against each subsequent argument sequentially and acts like a logical OR.
- The policy also uses hub cluster templates with `fromConfigMap` so we can keep environment specific parameters in _ConfigMaps_. This is a common pattern which makes the _Policy_ more readable in case of many clusters.
- Adding `disabled: true` to an environment sets `complianceType: mustnothave` which uninstalls the operator. If you're not planning to reinstall the operator later, make sure to remove any related custom CRs first to avoid stuck deletions later due to missing finalizers.
- The namespace for the operator is created by the `ConfigurationPolicy`. Make sure to use a separate dedicated namespace for every operator, otherwise the _InstallPlans_ can overlap.
- Changing the `channel` requires a full uninstall/reinstall
- The `startingCSV` field only matters for the first installation, but not during upgrades
- Getting operator versions possibly could be automated somehow, but it really depends on the tools we have available.
- The actual versions we can upgrade to depends on the _InstallPlans_ created by OLM - RHACM only approves them - which is operator specific. Usually only the last z-stream version can be used within a minor version, but for simplicity we can list all versions in the catalog.
