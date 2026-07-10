# eximeebpms-k8s

[![Lint, Test and Release](https://github.com/EximeeBPMS/eximeebpms-k8s/actions/workflows/lint-test-release.yml/badge.svg?branch=main)](https://github.com/EximeeBPMS/eximeebpms-k8s/actions/workflows/lint-test-release.yml) [![Kustomize validate](https://github.com/EximeeBPMS/eximeebpms-k8s/actions/workflows/kustomize-validate.yml/badge.svg?branch=main)](https://github.com/EximeeBPMS/eximeebpms-k8s/actions/workflows/kustomize-validate.yml) [![License](https://img.shields.io/github/license/EximeeBPMS/eximeebpms-k8s?color=blue&logo=apache)](LICENSE)

Official Kubernetes / OpenShift deployment artifacts for [EximeeBPMS](https://eximeebpms.org), a mission-critical BPMN 2.0
process engine forked from Camunda 7.

This repository provides **two** independent, equivalent ways to deploy EximeeBPMS -- pick whichever fits your
platform's tooling:

| | [`charts/eximeebpms`](charts/eximeebpms) (Helm) | [`kustomize/`](kustomize) (Kustomize) |
|---|---|---|
| Best for | Helm-based platforms, `helm install`/`helm upgrade` workflows, ArtifactHub discovery | GitOps (Argo CD, Flux), teams that prefer plain YAML + overlays over a templating engine, OpenShift |
| Templating | Go templates, values-driven | Strategic merge / JSON6902 patches over plain manifests |
| HA example | [`values-ha.yaml`](charts/eximeebpms/values-ha.yaml) | [`overlays/ha`](kustomize/overlays/ha) |
| OpenShift | Works via `ingress` values, no SCC-specific adjustments | [`overlays/openshift`](kustomize/overlays/openshift) -- drops the fixed `runAsUser`/`fsGroup` for SCC compatibility, adds a `Route` |

Both start from the same defaults: single replica, embedded H2 database (demo/quick-start only -- **not**
suitable for more than one replica), non-root container, dropped Linux capabilities, read-only root
filesystem, `RuntimeDefault` seccomp profile.

## Quick start

**Helm**, from the published chart repo (served from `gh-pages` by the `lint-test-release.yml` release job -- enable GitHub Pages for this repo once, pointing at the `gh-pages` branch, for this URL to work):

```shell
helm repo add eximeebpms https://eximeebpms.github.io/eximeebpms-k8s
helm repo update
helm install my-release eximeebpms/eximeebpms
```

Or from a checkout of this repository:

```shell
helm install my-release ./charts/eximeebpms
```

**Kustomize:**

```shell
kubectl apply -k kustomize/base
```

## Highly available deployment

**Helm:**

```shell
helm install my-release ./charts/eximeebpms \
  -f charts/eximeebpms/values-ha.yaml \
  --set database.credentialsSecretName=eximeebpms-db-credentials
```

**Kustomize:**

```shell
kubectl create secret generic eximeebpms-db-credentials \
  --from-literal=DB_USERNAME=eximeebpms --from-literal=DB_PASSWORD='<your-password>'
kubectl apply -k kustomize/overlays/ha
```

Both HA paths configure: multiple replicas against an external PostgreSQL database, a `HorizontalPodAutoscaler`,
a `PodDisruptionBudget`, pod anti-affinity across nodes, and tuned probes. See
[`charts/eximeebpms/README.md`](charts/eximeebpms/README.md) and [`kustomize/README.md`](kustomize/README.md)
for details.

## OpenShift

```shell
kubectl apply -k kustomize/overlays/openshift
```

## Security defaults

Both the chart and the Kustomize base run the container as the non-root `eximeebpms` user (matching the
published image), drop all Linux capabilities, disallow privilege escalation, run with a read-only root
filesystem (the JVM/Tomcat temp dir is provided via an `emptyDir` mounted at `/tmp`), and apply the
`RuntimeDefault` seccomp profile -- by default, not as an opt-in. A `NetworkPolicy` (Helm, opt-in via
`networkPolicy.enabled`) and a `PodDisruptionBudget` are available for hardened/HA deployments.

This default `securityContext` satisfies the
[Pod Security Standards "Restricted"](https://kubernetes.io/docs/concepts/security/pod-security-standards/#restricted)
profile and the container-level checks of the
[CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes) (non-root, no privilege
escalation, all capabilities dropped, restricted seccomp, read-only root filesystem) out of the box --
verified by running the published image with `docker run --read-only --tmpfs /tmp` and by a `kube-score`
pass in CI (see below). Namespaces enforcing the `restricted`
[Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/) level
(`pod-security.kubernetes.io/enforce: restricted`) can deploy this chart/manifests without further changes.

## Supply chain

- **CI security lint**: rendered manifests (the Helm chart output and every Kustomize overlay) are scanned
  with [kube-score](https://github.com/zegl/kube-score) on every push/PR, catching regressions in the security
  posture above before they reach `main`.
- **Image scanning + SBOM**: every published image is scanned with [Trivy](https://github.com/aquasecurity/trivy)
  (the build fails on CRITICAL findings) and shipped with a CycloneDX SBOM -- see the
  [eximeebpms-docker](https://github.com/EximeeBPMS/eximeebpms-docker) pipeline.
- **Signed images**: published images are signed keylessly with [cosign](https://github.com/sigstore/cosign)
  using GitHub Actions OIDC (Sigstore/Fulcio/Rekor) -- no long-lived signing key to manage or leak:
  ```shell
  cosign verify ghcr.io/eximeebpms/eximeebpms-bpm-platform:run-1.2.0 \
    --certificate-identity-regexp 'https://github.com/EximeeBPMS/eximeebpms-docker/.*' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  ```
- **Signed Helm chart**: on top of the classic `gh-pages` chart repo, the chart is published as an OCI artifact
  to `oci://ghcr.io/eximeebpms/charts/eximeebpms` and signed the same way:
  ```shell
  cosign verify ghcr.io/eximeebpms/charts/eximeebpms:<version> \
    --certificate-identity-regexp 'https://github.com/EximeeBPMS/eximeebpms-k8s/.*' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  ```

## Related repositories

- [eximeebpms](https://github.com/EximeeBPMS/eximeebpms) -- the process engine itself
- [eximeebpms-docker](https://github.com/EximeeBPMS/eximeebpms-docker) -- the container image these manifests deploy
- [Documentation](https://docs.eximeebpms.org/)

## Contributing

Please see [CONTRIBUTING.md](https://github.com/EximeeBPMS/eximeebpms/blob/main/CONTRIBUTING.md) in the main
`eximeebpms` repository -- the same conventions apply here.

## License

The source files in this repository are made available under the [Apache License Version 2.0](./LICENSE).
