# =============================================================================
# Terraform Outputs - BPG Provider
# Last verified: 2026-03-18
# =============================================================================

output "haproxy_ips" {
  description = "HAProxy load balancer IPs"
  value = {
    haproxy1 = module.haproxy_1.ip_address
    haproxy2 = module.haproxy_2.ip_address
  }
}

output "k8s_master_ips" {
  description = "Kubernetes master node IPs"
  value = {
    master1 = module.k8s_master_1.ip_address
    master2 = module.k8s_master_2.ip_address
    master3 = module.k8s_master_3.ip_address
  }
}

output "k8s_worker_ips" {
  description = "Kubernetes worker node IPs"
  value = {
    worker1_gpu = module.k8s_worker_1_gpu.ip_address
    worker2     = module.k8s_worker_2.ip_address
    worker3     = module.k8s_worker_3.ip_address
  }
}

output "gpu_worker_node" {
  description = "Worker node with GPU passthrough"
  value = {
    name = module.k8s_worker_1_gpu.vm_name
    ip   = module.k8s_worker_1_gpu.ip_address
    gpu  = "nvidia-rtx-a2000"
  }
}

output "amp_server" {
  description = "AMP game server control panel"
  value = {
    name = module.amp.vm_name
    ip   = module.amp.ip_address
    url  = "https://amp.example.com"
  }
}

output "ci_runner" {
  description = "CI Runner VM for deploy jobs"
  value = {
    name = module.ci_runner.vm_name
    ip   = module.ci_runner.ip_address
    url  = "https://ci-runner.example.com"
  }
}


output "infrastructure_summary" {
  description = "Complete infrastructure summary"
  value = {
    total_vms          = 17
    infrastructure_vms = 7 # truenas, adguard, harbor, gitlab, netbox, vpn, ci-runner
    haproxy_nodes      = 2
    k8s_master_nodes   = 3
    k8s_worker_nodes   = 3
    gpu_workers        = 1
    game_servers       = 1
    provider           = "bpg/proxmox ~> 0.94.0"
  }
}
