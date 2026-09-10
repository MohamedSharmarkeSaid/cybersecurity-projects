# PowerShell Infrastructure Automation & Identity Governance

[![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue.svg?logo=powershell)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20Server%202019%20%2F%202022-0078D6.svg?logo=windows)](https://www.microsoft.com/en-us/windows-server)
[![Security Standard](https://img.shields.io/badge/Security-CIS%20%7C%20Least%20Privilege-success.svg)](https://www.cisecurity.org/)
[![Module Architecture](https://img.shields.io/badge/Architecture-IaC%20%7C%20RBAC%20%7C%20Zero--Trust-orange.svg)](.)

## Executive Overview

This module demonstrates production-grade, enterprise infrastructure automation authored by **Mohamed Said**. Built from verified systems engineering implementations across Windows Server Active Directory, Hyper-V virtualization, and network services, the toolset provides an automated, idempotent Infrastructure-as-Code (IaC) framework.

The automation suite addresses three critical administrative and cybersecurity disciplines:
1. **Dynamic Network Service Provisioning**: Automated deployment, Active Directory Domain Services (AD DS) authorization, IPv4 scope creation, static IP reservation, and post-installation state management for Windows Server DHCP.
2. **Identity Lifecycle & Access Governance**: Schema-validated bulk identity ingestion from CSV, dynamic Global Security Group creation, role-based access control (RBAC), Group Policy Object (GPO) security baseline enforcement, and defense-in-depth filesystem hardening using native `icacls` security descriptors.
3. **Enterprise Virtualization & Storage Tiering**: Rapid Generation 2 Hyper-V virtual machine deployment with UEFI firmware, Dynamic Memory ballooning, and an automated 6-disk SCSI storage tier optimized for SQL Server high-performance database workloads (formatted with 64KB cluster allocation sizes).

---

## Automation Suite & Core Components

| Script | Domain / Purpose | Key Capabilities & Security Controls |
|:---|:---|:---|
| [`Invoke-DHCPDeployment.ps1`](./Invoke-DHCPDeployment.ps1) | **Core Network Services** | Automated DHCP role installation, AD DS authorization (`Add-DhcpServerInDC`), IPv4 scope creation, exclusion ranges (gateways, switches, SQL VIPs), standard options (003, 006, 015), MAC reservations, and Server Manager post-install registry cleanup. |
| [`Sync-ADUsersAndGroups.ps1`](./Sync-ADUsersAndGroups.ps1) | **Identity & Access Governance** | Bulk CSV roster ingestion, dynamic Global Security Group creation, temporary `SecureString` credential generation, GPO security baseline enforcement (Ctrl+Alt+Del mandated, 14-char minimum password, 5-attempt lockout), and NTFS inheritance stripping with strict `icacls` least-privilege ACLs. |
| [`Deploy-HyperV-VM.ps1`](./Deploy-HyperV-VM.ps1) | **Virtualization Infrastructure** | Generation 2 UEFI VM provisioning with Secure Boot, dynamic memory ballooning (2GB–16GB), and automated 6-disk SCSI storage tiering (OS, Program, SystemDB, UserData, UserLog, TempDB) formatted with optimal 64KB cluster allocation for SQL Server workloads. |

---

## Security Hardening & Engineering Best Practices

* **Zero Plaintext Credential Exposure**: All account creation routines mandate `[SecureString]` parameters or utilize CSPRNG-generated ephemeral 16-character passwords. No passwords are ever stored or emitted in cleartext.
* **Least Privilege Access Control (PoLP)**: File shares explicitly break NTFS inheritance (`icacls /inheritance:d`), strip broad `Users`/`Domain Users` permissions, and assign departmental `Modify` rights. Sensitive project assets (`Alpha`) are restricted strictly to designated project leads (`Jacob.Hoover`) and vetted members.
* **CIS Benchmark Alignment**: Domain GPOs enforce secure logon sequences (`DisableCAD = 0`) to prevent credential harvesting overlay attacks, alongside strict lockout and passphrase complexity thresholds.
* **Idempotency & Safe Execution**: All scripts perform pre-flight state checks before write operations, supporting native PowerShell `-WhatIf` and `-Confirm` flags (`[CmdletBinding(SupportsShouldProcess)]`).

---

## Deliverables & Artifacts

| Deliverable | Description | Format / Location |
|:---|:---|:---|
| **DHCP Automation Script** | Production PowerShell deployment script for Windows Server DHCP with AD authorization. | [`Invoke-DHCPDeployment.ps1`](./Invoke-DHCPDeployment.ps1) |
| **AD & Identity Governance Script** | PowerShell lifecycle script for CSV import/export, RBAC, GPO, and `icacls` NTFS security. | [`Sync-ADUsersAndGroups.ps1`](./Sync-ADUsersAndGroups.ps1) |
| **Hyper-V IaC VM Provisioner** | PowerShell automation script for Gen 2 VMs with 6-disk SCSI SQL database storage arrays. | [`Deploy-HyperV-VM.ps1`](./Deploy-HyperV-VM.ps1) |
| **Hyper-V Automation Guide** | University course lab manual for Hyper-V VM automation and disk array configuration. | [`HyperV_VM_Automation_Lab_Guide.pdf`](./HyperV_VM_Automation_Lab_Guide.pdf) (132 KB) |
