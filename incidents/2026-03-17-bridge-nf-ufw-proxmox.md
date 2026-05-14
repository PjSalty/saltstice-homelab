# Three-way firewall outage: bridge-nf, UFW, and the Proxmox cluster firewall

**Date:** 2026-03-17
**Impact:** All Kubernetes VM-to-VM TCP traffic dropped. Etcd lost quorum. Three repeat occurrences while debugging.

## Summary

Enabling the Proxmox cluster firewall took the Kubernetes cluster offline three
times in a row. The fault was the interaction between three correctly-configured
firewall layers, not any single one of them. ICMP kept working throughout, which
made the diagnosis longer than it should have been.

## Symptoms

- All TCP traffic between Kubernetes VMs dropped within seconds of enabling the
 Proxmox cluster firewall.
- ICMP between the same hosts still worked.
- etcd lost quorum within ~30 seconds. Pods went unscheduled.
- The Proxmox host itself stayed reachable.

## Stack at the time

Three firewalls active on every K8s VM:

1. **Proxmox cluster firewall** at the host level (`vmbr1`)
2. **`br_netfilter`** kernel module (`bridge-nf-call-iptables`)
3. **UFW** on the guest, with `default deny FORWARD`

Each was configured "correctly" in isolation. UFW's `default deny FORWARD` is
the secure default and what hardening guides recommend. The Proxmox firewall
had a clean allow list. K8s required `bridge-nf-call-iptables=1` for CNI
NetworkPolicy enforcement.

## Root cause

Enabling the Proxmox cluster firewall causes `br_netfilter` to load on the
host, which sets `bridge-nf-call-iptables=1` on every VM bridged to the affected
interface. Every bridged frame between two VMs on the same bridge is then
hooked through the iptables `FORWARD` chain on the *guest*. With UFW set to
`default deny FORWARD`, all that bridged TCP gets dropped silently.

ICMP passed because UFW's `before.rules` explicitly allows ICMP early in the
chain. TCP has no such bypass.

## Fix

Add an explicit ACCEPT for VM-to-VM bridge forwarding in UFW:

```
# /etc/ufw/before.rules
-A ufw-before-forward -i vmbr+ -o vmbr+ -j ACCEPT
```

Codified into the Ansible role that bootstraps every K8s VM:

```yaml
- name: Allow VM-to-VM bridge forwarding through UFW
  ansible.builtin.blockinfile:
    path: /etc/ufw/before.rules
    insertbefore: '^# End required lines'
    block: |
      -A ufw-before-forward -i vmbr+ -o vmbr+ -j ACCEPT
  notify: Reload ufw
```

**Do not** "fix" this by setting `bridge-nf-call-iptables=0`. Kubernetes CNI
plugins require it to be `1` to enforce NetworkPolicy at all. Setting it to 0
silently disables NetworkPolicy enforcement, a much worse outcome than the
outage you were trying to fix.

## Lessons

1. **Three correct firewalls can produce one wrong outcome.** Each layer was
 doing exactly what it was configured to do. The fault was at the seams.

2. **"ICMP works, TCP fails" is a layer-bypass tell.** When one transport
 passes between hosts and others don't, look for a layer that has an explicit
 per-protocol bypass. The layer with the bypass is the layer to investigate.

3. **Firewall changes that look local often aren't.** Enabling the cluster
 firewall on the host changed kernel sysctls on the guest. Implicit blast
 radius is the worst kind.

4. **Don't fix a security setting by disabling another security setting.** The
 tempting `bridge-nf-call-iptables=0` would have ended the outage and opened
 a much worse hole.

5. **Make the rule infrastructure-as-code.** Manual `ufw allow` survives the
 current incident and is lost on the next reimage.
