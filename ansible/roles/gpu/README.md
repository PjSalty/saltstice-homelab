# GPU

Installs NVIDIA GPU drivers and the NVIDIA container toolkit on GPU-enabled Kubernetes worker nodes. Enables GPU workloads in containers via containerd runtime configuration.

## Tasks (tasks/main.yml)

1. Install NVIDIA driver packages (NVIDIA-driver, NVIDIA-kernel-dkms, NVIDIA-smi)
2. Clean up existing NVIDIA APT sources and GPG keys
3. Download and dearmor the NVIDIA container toolkit GPG key
4. Configure the NVIDIA container toolkit APT repository
5. Install NVIDIA-container-toolkit package
6. Check if containerd has NVIDIA runtime configured
7. Configure NVIDIA runtime for containerd via `nvidia-ctk`
8. Verify GPU accessibility via `nvidia-smi`

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `gpu_driver_packages` | `[nvidia-driver, nvidia-kernel-dkms, nvidia-smi]` | NVIDIA driver packages |
| `gpu_container_toolkit` | `true` | Install NVIDIA container toolkit |
| `gpu_container_toolkit_packages` | `[nvidia-container-toolkit]` | Container toolkit packages |
| `gpu_default_runtime` | `nvidia` | Default container runtime |

## Handlers

- `Restart containerd` -- Restarts containerd after runtime configuration changes

## Tags

`gpu`, `packages`, `config`, `verify`

## Applied To

Only runs on hosts in the `gpu_workers` group (currently K8s-worker-1 with NVIDIA RTX A2000 via PCI passthrough from the Dell R740xd).
