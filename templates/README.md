# Templates

Generic starting points for the patterns this cluster uses. Drop into
a new app, replace the bracketed placeholders, ship.

| File | Use |
|---|---|
| [HelmRelease.yaml](helmrelease.yaml) | Flux HelmRelease with security context, postBuild substitution, ServiceMonitor |
| [external-secret.yaml](external-secret.yaml) | Per-namespace ESO SecretStore + ExternalSecret reading from a shared decrypted Secret |
| [Cilium-NetworkPolicy.yaml](cilium-networkpolicy.yaml) | Default-deny + explicit allows, with the toEndpoints/toCIDR pre-DNAT trap documented |
| [IngressRoute-with-Authentik-forward-auth.yaml](ingressroute-with-authentik-forward-auth.yaml) | Traefik IngressRoute with two-route pattern (HTML behind SSO, API passthrough) |
| [vpa-with-hpa.yaml](vpa-with-hpa.yaml) | HPA on CPU + VPA on memory, the no-fight configuration |
