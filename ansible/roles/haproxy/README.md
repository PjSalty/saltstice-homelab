# HAProxy

Deploys an HAProxy + keepalived HA pair for Kubernetes API server load balancing. Two VMs (HAProxy-1 as MASTER, HAProxy-2 as BACKUP) share a Virtual IP (<internal-ip>) via VRRP.

## Tasks (tasks/main.yml)

1. Install HAProxy and keepalived
2. Deploy HAProxy configuration (validated with `haproxy -c`)
3. Deploy keepalived configuration
4. Enable HAProxy and keepalived services
5. Enable `net.ipv4.ip_nonlocal_bind` sysctl (required for VIP binding)

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `haproxy_stats_password` | (from SOPS) | HAProxy stats UI password |
| `haproxy_keepalived_auth_pass` | (from SOPS) | VRRP authentication password |

### Group Variables (group_vars/load_balancers/vars.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `haproxy_stats_port` | `9000` | Stats UI port |
| `haproxy_stats_user` | `admin` | Stats UI username |
| `haproxy_vip` | `<internal-ip>` | Virtual IP address (from all.yml) |

### Per-Host Variables (inventory/hosts.yml)

| Variable | Description |
|----------|-------------|
| `haproxy_role` | `master` or `backup` |
| `keepalived_priority` | VRRP priority (100 for master, 90 for backup) |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `haproxy.cfg.j2` | `/etc/haproxy/haproxy.cfg` | HAProxy config: K8s API + RKE2 registration backends, stats UI, Prometheus metrics |
| `keepalived.conf.j2` | `/etc/keepalived/keepalived.conf` | VRRP instance: health check script, VIP, failover notifications |

### HAProxy Frontends/Backends

- **K8s-api** -- VIP:6443 to master nodes:6443 (roundrobin, TCP health checks)
- **RKE2-registration** -- VIP:9345 to master nodes:9345
- **stats** -- Port 9000, HTTP stats UI with auth
- **prometheus** -- Port 8405, metrics exporter endpoint

### Keepalived Configuration

- VRRP health check: monitors HAProxy process via `killall -0 haproxy`
- MASTER/BACKUP state derived from `haproxy_role` inventory variable
- Failover notifications start/stop HAProxy on state transitions

## Handlers

- `Restart haproxy` -- Restarts HAProxy
- `Reload haproxy` -- Graceful reload of HAProxy
- `Restart keepalived` -- Restarts keepalived

## Tags

`haproxy`, `packages`, `config`, `keepalived`, `sysctl`

## Notes

HTTP/HTTPS ingress traffic is handled by Traefik via MetalLB at <internal-ip>, not through HAProxy.
