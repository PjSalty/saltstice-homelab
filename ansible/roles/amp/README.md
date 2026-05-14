# amp

Deploys CubeCoders AMP (Application Management Panel) game server via Docker Compose. Manages container lifecycle and handles licence reactivation for instances that lose their licence after VM rebuilds.

## Tasks (tasks/main.yml)

1. Create AMP data directory
2. Deploy Docker Compose file from template
3. Start AMP containers via docker_compose_v2
4. Get AMP instance list (if licence key configured)
5. Check for unlicensed instances
6. Reactivate unlicensed instances using the licence key from SOPS
7. Start reactivated instances

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `amp_data_dir` | `/data/amp` | Root data directory |
| `amp_web_port` | `8081` | AMP Web UI port |
| `amp_fqdn` | `amp.example.com` | AMP hostname |
| `amp_licence_key` | (from SOPS) | AMP licence key for activation |
| `amp_game_port_start` | `25000` | Game server port range start |
| `amp_game_port_end` | `25199` | Game server port range end |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `docker-compose.yml.j2` | `/data/amp/docker-compose.yml` | AMP container: cubecoders/amp:latest, ADS module, port mappings |

## Tags

`amp`, `config`, `amp-licence`

## Dependencies

Requires the `docker` role to be applied first.
