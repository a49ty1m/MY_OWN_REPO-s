# Metasploitable 2 & OWASP BWA KVM Setup Guide

This guide covers how to correctly import and run VMware-based vulnerable VMs (Metasploitable, OWASP BWA) in **KVM (virt-manager)**.

## 1. Prerequisites
Ensure you have the necessary tools installed on your Linux host:
- `qemu-utils` (for `qemu-img` conversion tool)
- `virt-manager` (GUI for managing KVM)

## 2. Converting VMware Disks to KVM (QCOW2)
VMware uses `.vmdk` files. KVM works best with `.qcow2`.

### For OWASP BWA (Split VMDK)
Identify the small descriptor file (e.g., `OWASP Broken Web Apps-cl1.vmdk`) that doesn't have `-s001` in the name and run:
```bash
qemu-img convert -p -O qcow2 "OWASP Broken Web Apps-cl1.vmdk" owaspbwa.qcow2
```

### For Metasploitable 2 (Single VMDK)
```bash
qemu-img convert -p -O qcow2 "Metasploitable.vmdk" metasploitable2.qcow2
```
*-p: Shows progress bar.*
*-O qcow2: Specifies the output format.*

## 3. Creating the VM in virt-manager
1. **Choose "Import existing disk image"**.
2. **Select the .qcow2 file** you created.
3. **Configure Settings (CRITICAL for older VMs):**
   - **Disk Bus:** Change from `VirtIO` to **IDE** or **SATA** (Older OS like Ubuntu 10.04/Debian 4 lack VirtIO drivers).
   - **Network (NIC) Model:** Change from `virtio` to **e1000** (Intel).
   - **Video:** Change to **VGA** or **VMVGA**.
   - **Display:** Use **Spice server** or **VNC**.

## 4. Default Credentials
| VM | Username | Password |
| :--- | :--- | :--- |
| **OWASP BWA** | `root` | `owaspbwa` |
| **Metasploitable 2** | `msfadmin` | `msfadmin` |

---
*Created on: 2026-03-17*
