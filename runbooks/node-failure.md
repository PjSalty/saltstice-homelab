# Kubernetes Node Failure Runbook

## Overview

This runbook covers procedures for handling Kubernetes node failures in the Salty Homelab RKE2 cluster.

## Cluster Architecture

```
                        ┌┐
                           HAProxy VIP   
                          <internal-ip>   
                        ┬┘
                                 
         ┌┼┐
                                                       
   ┌▼┐          ┌▼┐          ┌▼┐
     Master 1             Master 2             Master 3 
      (etcd)  ◄►   (etcd)  ◄►   (etcd)  
   ┘          ┘          ┘
                                 
         ┌┼┐
                                                       
   ┌▼┐          ┌▼┐          ┌▼┐
    Worker 1             Worker 2             Worker 3  
                                                (GPU)   
   ┘          ┘          ┘
```

## Quick Diagnosis

```bash
# Check all node status
kubectl get nodes -o wide

# Check node conditions
kubectl describe node <node-name> | grep -A 20 Conditions

# Check system pods on specific node
kubectl get pods -A -o wide --field-selector spec.nodeName=<node-name>

# Check node resource usage
kubectl top nodes
```

## Scenario 1: Worker Node Failure

### Symptoms

- Node shows `NotReady` in `kubectl get nodes`
- Pods on node are `Pending` or `Unknown`
- Workloads not serving traffic

### Immediate Actions

1. **Verify node is actually down**:

   ```bash
   # Ping the node
   ping <node-ip>

   # Try SSH
   ssh <node-name>

   # Check Proxmox
   ssh proxmox "qm status <vmid>"
   ```

2. **Cordon the node** (if partially responsive):

   ```bash
   kubectl cordon <node-name>
   ```

3. **Drain workloads** (if node is responsive):

   ```bash
   kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
   ```

4. **Check if workloads rescheduled**:

   ```bash
   kubectl get pods -A -o wide | grep -v Running
   ```

### Recovery Options

**Option A: Restart the Node**

```bash
# Via Proxmox
ssh proxmox "qm reboot <vmid>"

# Wait for node to come back
kubectl get nodes -w
```

**Option B: Rebuild the Node**

```bash
# Remove from cluster
kubectl delete node <node-name>

# Rebuild VM
cd terraform
terraform apply -target=module.k8s_worker_<n>

# Rejoin to cluster
ansible-playbook ansible/playbooks/rke2-join-worker.yml -l <node-name>

# Uncordon if needed
kubectl uncordon <node-name>
```

## Scenario 2: Master Node Failure

### Single Master Down (Cluster Operational)

**Symptoms**:

- One master shows `NotReady`
- Cluster still operational (2/3 etcd quorum)
- API may be slower

**Actions**:

1. **Verify cluster is still operational**:

   ```bash
   kubectl get nodes
   kubectl get pods -n kube-system
   ```

2. **Check etcd health**:

   ```bash
   kubectl -n kube-system exec -it etcd-k8s-master-1 -- \
     etcdctl endpoint health \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key
   ```

3. **Remove failed master from etcd** (if not recovering):

   ```bash
   # Get member ID
   kubectl -n kube-system exec -it etcd-k8s-master-1 -- \
     etcdctl member list \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key

   # Remove member
   kubectl -n kube-system exec -it etcd-k8s-master-1 -- \
     etcdctl member remove <member-id> \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key
   ```

4. **Delete node from Kubernetes**:

   ```bash
   kubectl delete node <failed-master>
   ```

5. **Rebuild master**:

   ```bash
   terraform apply -target=module.k8s_master_<n>
   ansible-playbook ansible/playbooks/kubernetes.yml -l <master-name>
   ```

### Multiple Masters Down (Quorum Lost)

**CRITICAL SITUATION** - Cluster is non-functional

**Symptoms**:

- `kubectl` commands hang or fail
- API server unreachable
- 2+ masters down

**Recovery**:

1. **Check which masters are up**:

   ```bash
   for i in 1 2 3; do
     echo "Master $i:"
     ping -c 1 k8s-master-$i 2>/dev/null && echo "UP" || echo "DOWN"
   done
   ```

2. **If only one master needed to restore quorum**:

   ```bash
   # Restart the failed master VM
   ssh proxmox "qm start <vmid>"

   # Wait for etcd to rejoin
   # This may take several minutes
   ```

3. **If etcd cluster corrupted, restore from backup**:

   ```bash
   # Stop all masters
   for i in 1 2 3; do
     ssh k8s-master-$i "systemctl stop rke2-server"
   done

   # Restore etcd snapshot on first master
   ssh k8s-master-1 "rke2 server \
     --cluster-reset \
     --cluster-reset-restore-path=/path/to/snapshot"

   # Rejoin other masters
   # (Follow RKE2 documentation for cluster restore)
   ```

## Scenario 3: All Workers Down

**Symptoms**:

- All workloads in `Pending` state
- No worker nodes showing `Ready`

**Actions**:

1. **Check if it's a network issue**:

   ```bash
   # From master, ping workers
   for w in k8s-worker-{1,2,3}; do ping -c 1 $w; done
   ```

2. **Check if it's a Proxmox issue**:

   ```bash
   ssh proxmox "qm list"
   ```

3. **Restart workers in Proxmox**:

   ```bash
   for vmid in <worker-vmids>; do
     ssh proxmox "qm reboot $vmid"
   done
   ```

4. **If VMs won't start, check Proxmox resources**:

   ```bash
   ssh proxmox "pvesh get /nodes/proxmox/status"
   ```

## Scenario 4: Node Disk Full

**Symptoms**:

- Node goes `NotReady`
- Pods evicted with `DiskPressure`
- `kubectl describe node` shows disk pressure

**Actions**:

1. **Identify the problem**:

   ```bash
   ssh <node> "df -h"
   ssh <node> "du -sh /var/lib/rancher/*"
   ```

2. **Clean up container images**:

   ```bash
   ssh <node> "/var/lib/rancher/rke2/bin/crictl rmi --prune"
   ```

3. **Clean up old logs**:

   ```bash
   ssh <node> "find /var/log -name '*.log' -mtime +7 -delete"
   ```

4. **Clean up old pods logs**:

   ```bash
   ssh <node> "find /var/log/pods -mtime +3 -delete"
   ```

5. **Force garbage collection**:

   ```bash
   # Kubernetes will GC when disk pressure is detected
   # You can also trigger manually:
   kubectl delete pods --field-selector=status.phase==Failed -A
   ```

## Preventive Measures

### Enable Node Problem Detector

Already configured via Flux - monitors for:

- Kernel issues
- Disk issues
- Network issues
- Container runtime issues

### Resource Monitoring

```bash
# Check resource usage across nodes
kubectl top nodes

# Check per-node pod count
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c

# Watch for resource pressure
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
DISK:.status.conditions[?(@.type=="DiskPressure")].status,\
MEM:.status.conditions[?(@.type=="MemoryPressure")].status,\
PID:.status.conditions[?(@.type=="PIDPressure")].status
```

## Post-Recovery Checklist

After recovering from any node failure:

- [ ] All nodes show `Ready`
- [ ] All system pods running (`kubectl get pods -n kube-system`)
- [ ] Workloads rescheduled and running
- [ ] Flux reconciliation working (`flux get all -A`)
- [ ] Storage mounts working (check PVCs)
- [ ] Monitoring shows node healthy
- [ ] Document incident for review

## Related Files

| File | Purpose |
|------|---------|
| `terraform/modules/k8s-node/` | Node VM definitions |
| `ansible/playbooks/kubernetes.yml` | Cluster setup |
| `ansible/playbooks/rke2-join-worker.yml` | Worker join |
| `ansible/playbooks/rke2-node-upgrade.yml` | Node upgrade |
| `docs/runbooks/disaster-recovery.md` | Full DR procedures |
