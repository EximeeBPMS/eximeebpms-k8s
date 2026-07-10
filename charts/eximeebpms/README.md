# eximeebpms

Helm chart for [EximeeBPMS](https://eximeebpms.org), a mission-critical BPMN 2.0 process engine forked from Camunda 7.

## Installing

```shell
helm repo add eximeebpms https://eximeebpms.github.io/eximeebpms-k8s
helm repo update
helm install my-release eximeebpms/eximeebpms
```

Or from a checkout of this repository:

```shell
helm install my-release ./charts/eximeebpms
```

## Highly available / production deployments

The default `values.yaml` targets a quick, single-replica demo deployment backed by the embedded H2
database. **H2 does not support clustering** -- deploying more than one replica against it is refused
by the chart (see `templates/constraints.tpl`).

For a real, highly-available deployment see [`values-ha.yaml`](values-ha.yaml), which configures:

- Multiple replicas against an external PostgreSQL database
- `HorizontalPodAutoscaler`
- `PodDisruptionBudget`
- Pod anti-affinity across nodes
- Tuned startup/readiness/liveness probes
- `NetworkPolicy` (restricts pod ingress/egress -- tighten the default rules for your environment)

```shell
helm install my-release ./charts/eximeebpms \
  -f charts/eximeebpms/values-ha.yaml \
  --set database.credentialsSecretName=eximeebpms-db-credentials
```

## Security defaults

The chart runs the container as the non-root `eximeebpms` user (uid/gid 1000, matching the published
image), drops all Linux capabilities, disallows privilege escalation, runs with a read-only root
filesystem, and applies the `RuntimeDefault` seccomp profile -- all by default, not opt-in. The JVM/Tomcat
temp dir is provided via an `emptyDir` automatically mounted at `/tmp` whenever
`securityContext.readOnlyRootFilesystem` is `true` (the default) -- no extra configuration needed.

This satisfies the [Pod Security Standards "Restricted"](https://kubernetes.io/docs/concepts/security/pod-security-standards/#restricted)
profile out of the box, so the chart can be installed into namespaces that enforce
`pod-security.kubernetes.io/enforce: restricted`.

## Values

See [`values.yaml`](values.yaml) for the full list of configurable values and [`values.schema.json`](values.schema.json)
for their expected types.

| Key | Description | Default |
|-----|-------------|---------|
| `image.repository` | Container image repository | `ghcr.io/eximeebpms/eximeebpms-bpm-platform` |
| `image.tag` | Container image tag (`<distro>-<version>`); empty defaults to `run-{appVersion}` | `""` |
| `general.replicaCount` | Number of replicas | `1` |
| `database.url` | JDBC URL | `jdbc:h2:./eximeebpms-h2-dbs/process-engine` |
| `ingress.enabled` | Enable an Ingress resource | `false` |
| `autoscaling.enabled` | Enable a HorizontalPodAutoscaler | `false` |
| `podDisruptionBudget.enabled` | Enable a PodDisruptionBudget | `false` |
| `networkPolicy.enabled` | Enable a NetworkPolicy | `false` |
| `metrics.enabled` | Expose the JMX/Prometheus metrics port and Service | `false` |
| `securityContext.readOnlyRootFilesystem` | Run the container with a read-only root filesystem (`/tmp` is auto-mounted as `emptyDir`) | `true` |

## See also

- [Kustomize manifests](https://github.com/EximeeBPMS/eximeebpms-k8s/tree/main/kustomize) -- a templating-free alternative, including an OpenShift-friendly overlay
- [eximeebpms-docker](https://github.com/EximeeBPMS/eximeebpms-docker) -- the container image this chart deploys
- [eximeebpms](https://github.com/EximeeBPMS/eximeebpms) -- the EximeeBPMS process engine
- [EximeeBPMS documentation](https://docs.eximeebpms.org/) -- getting started guides and reference docs for the process engine this chart deploys
- [eximeebpms.org](https://eximeebpms.org/) -- the EximeeBPMS product site
