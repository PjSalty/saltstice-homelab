# grafana/base/jobs

One-time initialization jobs for the Grafana deployment.

## Files

| File | Description |
|------|-------------|
| `dashboards-init-job.yaml` | Job (`grafana-dashboards-init`) that verifies dashboard files are correctly mounted from the `grafana-dashboards-files` ConfigMap. Lists all files at `/dashboards/` and exits. |

## Job Details

| Property | Value |
|----------|-------|
| Image | `${IMAGE_BUSYBOX}` |
| Restart policy | Never |
| Backoff limit | 3 retries |
| TTL after finished | 600 seconds (10 minutes) |

This job serves as a deployment validation step, confirming that the `configMapGenerator`-created dashboard ConfigMap is correctly populated and mountable. It does not modify any data.
