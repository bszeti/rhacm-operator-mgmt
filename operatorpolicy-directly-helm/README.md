# Create OperatorPolicy directly on managed clusters

This Helm chart can be used to create `OperatorPolicy` resources directly on the managed clusters which is already connected to RHACM. The chart requires the `env` value to be set additionally to the values file, so we don't have to maintain a separate file for each environment, we can simply change the `targetVersion`.

For example first we can deploy the _OpenShift Pipelines Operator_ in the "qu" and "uat" environments like this: 

Set desired version in the values file:

```yaml
# values-pipelines.yaml...
environments:
  - name: qa
    targetVersion: openshift-pipelines-operator-rh.v1.15.0
  - name: uat
    targetVersion: openshift-pipelines-operator-rh.v1.15.0
```

Deploy Helm chart:
```
# Login to QA environment and run:
helm upgrade -i openshift-pipelines-operator ./operatorpolicy-directly-helm -f ./operatorpolicy-directly-helm/values-pipelines.yaml --set env=qa

# Login to UAT environment and run:
helm upgrade -i openshift-pipelines-operator ./operatorpolicy-directly-helm -f ./operatorpolicy-directly-helm/values-pipelines.yaml --set env=uat
```

To upgrade operator version in QA, change its `targetVersion` and run the related `helm` command again:
```yaml
# values-pipelines.yaml...
environments:
  - name: qa
    targetVersion: openshift-pipelines-operator-rh.v1.18.1
  ...
```

This will deploy an `OperatorPolicy` with a version list up to the target, so RHACM will approve any _InstallPlans_ up to that version.
```
apiVersion: policy.open-cluster-management.io/v1beta1
kind: OperatorPolicy
metadata:
  name: openshift-pipelines-operator-rh
  namespace: open-cluster-management-policies
spec:
  remediationAction: enforce
  complianceType: musthave
  severity: critical
  subscription:
    name: openshift-pipelines-operator-rh
    namespace: openshift-pipelines-operator
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    channel: latest
    startingCSV: openshift-pipelines-operator-rh.v1.18.1
  versions:
    - openshift-pipelines-operator-rh.v1.15.0
    - openshift-pipelines-operator-rh.v1.15.1
    - openshift-pipelines-operator-rh.v1.15.2
    - openshift-pipelines-operator-rh.v1.15.3
    - openshift-pipelines-operator-rh.v1.15.4
    - openshift-pipelines-operator-rh.v1.16.0
    - openshift-pipelines-operator-rh.v1.16.1
    - openshift-pipelines-operator-rh.v1.16.2
    - openshift-pipelines-operator-rh.v1.16.3
    - openshift-pipelines-operator-rh.v1.16.4
    - openshift-pipelines-operator-rh.v1.17.0
    - openshift-pipelines-operator-rh.v1.17.1
    - openshift-pipelines-operator-rh.v1.17.2
    - openshift-pipelines-operator-rh.v1.18.0
    - openshift-pipelines-operator-rh.v1.18.1
  upgradeApproval: Automatic
```

The Helm chart requires the list of available operator versions in the desired channel, which can be queried by a command like this:

    oc get packagemanifest openshift-pipelines-operator-rh -o jsonpath='{range .status.channels[?(@.name == "latest")].entries[::]}- {.name}{"\n"}{end}' | tac

> [!NOTE]
> The `OperatorPolicy` manifests created directly on the managed clusters show up under _Discovered policies_ on the RHACM console instead of the usual _Policies_ table.

Additional notes:

- Adding `disabled: true` to an environment sets `complianceType: mustnothave` which uninstalls the operator. If you're not planning to reinstall the operator later, make sure to remove any related custom CRs first to avoid stuck deletions later due to missing finalizers.
- The namespace for the operator is NOT created automatically by the `OperatorPolicy`. Make sure to use a separate dedicated namespace for every operator, otherwise the _InstallPlans_ can overlap.
- Changing the `channel` requires a full uninstall/reinstall
- The `startingCSV` field only matters for the first installation, but not during upgrades
- Getting operator versions possibly could be automated somehow, but it really depends on the tools we have available.
- The actual versions we can upgrade to depends on the _InstallPlans_ created by OLM - RHACM only approves them - which is operator specific. Usually the last z-stream version can be used within a minor version.

## ArgoCD Application

If we use RHACM in combination with _OpenShift GitOps_ on the managed clusters - which is a very common pattern - we can create a _Policy_ like this to deploy the Helm chart via an _Application_ using the environment specific values file: [policy-app.yaml](./policy-app.yaml) 

Create the Policy on Hub cluster:

    oc apply -f policy-app.yaml