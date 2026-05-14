# SSH

SSH server hardening via a drop-in configuration file. Enforces key-only authentication, strong ciphers, and removes insecure host keys.

## Tasks (tasks/main.yml)

1. Create `/etc/ssh/sshd_config.d/` directory
2. Deploy hardened SSH config with sshd validation
3. Set SSH directory permissions
4. Deploy authorized keys for the Debian user
5. Remove insecure SSH host keys (DSA, ECDSA)

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `ssh_port` | `22` | SSH listen port |
| `ssh_permit_root_login` | `no` | Root login policy (overridden to `prohibit-password` for Proxmox) |
| `ssh_password_authentication` | `no` | Disable password auth |
| `ssh_permit_empty_passwords` | `no` | Deny empty passwords |
| `ssh_max_auth_tries` | `3` | Max authentication attempts |
| `ssh_login_grace_time` | `30` | Seconds before disconnect on failed login |
| `ssh_client_alive_interval` | `300` | Seconds between keepalive probes |
| `ssh_client_alive_count_max` | `2` | Max missed keepalives before disconnect |
| `ssh_x11_forwarding` | `no` | Disable X11 forwarding |
| `ssh_allow_tcp_forwarding` | `no` | Disable TCP forwarding |
| `ssh_allow_agent_forwarding` | `no` | Disable agent forwarding |
| `ssh_log_level` | `VERBOSE` | SSH log verbosity |
| `ssh_allowed_users` | `debian` | Space-separated list of allowed users |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `99-hardening.conf.j2` | `/etc/ssh/sshd_config.d/99-hardening.conf` | Full hardening config: auth, ciphers, KEX, MACs |

### Enforced Ciphers

- KEX: `sntrup761x25519-sha512@openssh.com`, `curve25519-sha256`
- Ciphers: `chacha20-poly1305@openssh.com`, `aes256-gcm@openssh.com`, `aes128-gcm@openssh.com`
- MACs: `hmac-sha2-512-etm@openssh.com`, `hmac-sha2-256-etm@openssh.com`

## Handlers

- `Restart sshd` -- Restarts the SSH daemon

## Tags

`ssh`, `hardening`, `keys`
