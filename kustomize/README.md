# Kustomize manifests for EximeeBPMS

Plain Kubernetes manifests plus [Kustomize](https://kustomize.io/) overlays -- no templating engine, suitable
for direct consumption by GitOps tools (Argo CD, Flux) or plain `kubectl apply -k`.

## Layout

```
base/                 Single replica, embedded H2 database (demo/quick-start only)
overlays/ha/           3 replicas, external PostgreSQL, HPA, PodDisruptionBudget, pod anti-affinity
overlays/openshift/    SCC-compatible (no fixed runAsUser/fsGroup), adds an OpenShift Route
```

## Usage

```shell
# Quick start
kubectl apply -k base

# Highly available, external PostgreSQL
kubectl create secret generic eximeebpms-db-credentials \
  --from-literal=DB_USERNAME=eximeebpms --from-literal=DB_PASSWORD='<your-password>'
kubectl apply -k overlays/ha

# OpenShift
kubectl apply -k overlays/openshift
```

Preview the rendered manifests without applying them:

```shell
kubectl kustomize overlays/ha
```

## Security defaults

`base` runs the container as the non-root `eximeebpms` user (uid/gid 1000), drops all Linux capabilities,
disallows privilege escalation, runs with a read-only root filesystem (an `emptyDir` is mounted at `/tmp`
for the JVM/Tomcat temp dir), and applies the `RuntimeDefault` seccomp profile -- all overlays inherit these
from `base`. This satisfies the [Pod Security Standards "Restricted"](https://kubernetes.io/docs/concepts/security/pod-security-standards/#restricted)
profile, so these manifests can be deployed into namespaces enforcing `pod-security.kubernetes.io/enforce: restricted`.

## Notes

- `overlays/ha` assumes an external PostgreSQL reachable at the `DB_URL` set in
  [`overlays/ha/db-patch.yaml`](overlays/ha/db-patch.yaml) -- edit it to point at your own database.
- `overlays/openshift` builds on `base`, not `overlays/ha` -- combine the two patch sets yourself
  (a new `overlays/openshift-ha` directory referencing both) if you need HA on OpenShift.
- Sidecars some enterprise platforms commonly add (an APM agent, a Vault Agent / External Secrets Operator
  container for secret injection) are intentionally not included here -- they're environment-specific.
  Add them as an `extraContainers`-style patch of your own; see `overlays/ha/replica-patch.yaml` for the
  strategic-merge patch style used throughout this repo.
