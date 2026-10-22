# Cybersecurity & Infrastructure Portfolio — Mohamed Said

Hi! I'm **Mohamed Said**, an Information Systems graduate (B.Sc. in Informatics, University of Borås,
2026) focusing on cybersecurity, network defense, and Windows/Linux infrastructure.

This repository collects **seven hands-on projects** from my degree and my own home lab: from
reconstructing a DNS tunneling incident in Wireshark and testing local LLMs on vulnerability root
cause analysis for my Bachelor's thesis, to hacking a smart home lab, automating Windows Server with
PowerShell, building multi-site Cisco networks and OPNsense firewalls, pentesting a Ruby on Rails
web app, and building Active Directory domains from scratch.

For each project, the `README.md` in its folder walks through **what I built or tested**, **how it
worked step by step**, **what went wrong and how I solved it**, and **what I learned**, alongside
the full Swedish lab reports (PDFs) and scripts.

**Contact:** [LinkedIn](https://www.linkedin.com/in/mohamed-sharmarke-661582338/) ·
[GitHub (@MohamedSharmarkeSaid)](https://github.com/MohamedSharmarkeSaid) · [Email](mailto:mohamedsaid_99@outlook.com)

---

## Projects in this repository

| # | Project | What it covers | Key tools | Deliverables |
|---|---|---|---|---|
| **01** | [**Network Forensics & DNS Tunneling**](./01-network-forensics-dns-tunneling/) | Investigated a PCAP from a compromised Linux host ("Operation Kattastrofen"), found a polyglot JPEG/bash dropper, decrypted a 32-byte XOR + Base64 DNS tunneling stream (`cutekittenzz.xyz`), deobfuscated a JSFuck payload, and wrote Suricata/Sigma detection rules. | Wireshark, `tshark`, CyberChef, Suricata, Sigma | [Incident Report (PDF)](./01-network-forensics-dns-tunneling/Incident_Report_DNS_Tunneling_Exfiltration.pdf) |
| **02** | [**Local LLMs for Vulnerability Root Cause Analysis (B.Sc. Thesis)**](./02-llm-vulnerability-rca/) | Tested 4 local LLMs (7B–14B) across 40 runs on OWASP Juice Shop pentest reports and source code, comparing direct file context (LM Studio, 58.3%) against full-repo RAG (Open WebUI + ChromaDB, 31.7%). | Ollama, LM Studio, Open WebUI, ChromaDB, OWASP Juice Shop | [B.Sc. Thesis — 111 pages (PDF)](./02-llm-vulnerability-rca/BSc_Thesis_LLM_Vulnerability_RCA.pdf) |
| **03** | [**Smart Home & IoT Security Assessment**](./03-iot-security-assessment/) | Built a smart home lab with Home Assistant, set up Cisco SPAN port mirroring, cracked a Reolink camera's RTSP stream in 78 seconds with Hydra, caught the camera sending UDP packets to AWS in Paris, and designed a 3-VLAN segmentation fix. | Kali Linux, Nmap, Wireshark, Cisco IOS (`SPAN`), THC-Hydra, `ffplay` | [IoT Security Report (PDF)](./03-iot-security-assessment/IoT_Security_Assessment_Report.pdf) |
| **04** | [**PowerShell Infrastructure & Security Automation**](./04-powershell-infrastructure-automation/) | Wrote three reusable PowerShell scripts to automate DHCP deployment & AD authorization, CSV user/group migration + `icacls` NTFS permissions + GPO baselines, and Gen 2 Hyper-V VMs with 6-disk SCSI SQL storage arrays. | PowerShell 5.1+, `ActiveDirectory`, `DhcpServer`, `Hyper-V`, `icacls` | [`Invoke-DHCPDeployment.ps1`](./04-powershell-infrastructure-automation/Invoke-DHCPDeployment.ps1) · [`Sync-ADUsersAndGroups.ps1`](./04-powershell-infrastructure-automation/Sync-ADUsersAndGroups.ps1) · [`Deploy-HyperV-VM.ps1`](./04-powershell-infrastructure-automation/Deploy-HyperV-VM.ps1) · [Lab Guide (PDF)](./04-powershell-infrastructure-automation/HyperV_VM_Automation_Lab_Guide.pdf) |
| **05** | [**Enterprise Network Architecture & OPNsense UTM Firewall**](./05-enterprise-network-architecture/) | Part 1: Designed a dual-site school network (Borås & Göteborg) with VLSM, LACP, Rapid PVST+, HSRPv2 with WAN tracking, GRE tunnels, OSPFv2, and Extended ACLs. Part 2: Built an OPNsense UTM firewall with Suricata IPS, ClamAV proxy, DNSBL filtering, and OpenVPN. | Cisco IOS, Packet Tracer, OPNsense, Suricata, Squid + ClamAV, OpenVPN | [Multi-Site Network Design (PDF)](./05-enterprise-network-architecture/MultiSite_Enterprise_Network_Design.pdf) · [OPNsense UTM Report (PDF)](./05-enterprise-network-architecture/OPNsense_UTM_Firewall_Implementation.pdf) |
| **06** | [**Web Application Penetration Testing (OWASP WSTG)**](./06-web-application-penetration-testing/) | Built an isolated Hyper-V Private Switch lab and tested the **Decidim** platform (Ruby on Rails / Puma 6.5.0) against OWASP WSTG v4.2, finding stack trace disclosure, missing login rate limiting, and cleartext HTTP, while verifying Rails' XSS and SQLi defenses. | Kali Linux, Nmap, Nikto, Gobuster, Burp Suite, SQLMap, XSStrike | [Pentest Report — 36 pages (PDF)](./06-web-application-penetration-testing/Web_Application_Penetration_Testing_Report.pdf) |
| **07** | [**Active Directory Home Lab & School Infrastructure Project**](./07-active-directory-lab/) | Part 1: Solo AD home lab (`lab.internal`, Windows Server 2025 & Windows 11) built for deliberate practice—DNS SRV records, OUs, `redircmp`, least-privilege delegation, and GPO troubleshooting. Part 2: 15-machine school branch environment (`fjunne.local`) with dual DCs, Cisco NAT, 4-node SQL AlwaysOn cluster, WDS, DHCP, and Linux Apache. | Hyper-V, Windows Server 2025 & 2019, AD DS, DNS, GPMC, SQL Server, WDS, Cisco IOS | [Solo Lab Journal](./07-active-directory-lab/docs/lab-journal.md) · [School Project Walkthrough](./07-active-directory-lab/school-project-fjunne.md) · [School Report — 59 pages (PDF)](./07-active-directory-lab/Serversystem%20och%20Infrastruktur.pdf) |

---

## Short overview of each project

### 1. [Network Forensics & DNS Tunneling ("Operation Kattastrofen")](./01-network-forensics-dns-tunneling/)
Investigated `kattastrofen.pcap` after an employee downloaded cat pictures over HTTP. I extracted a
polyglot bash dropper from the end of `kitten-3.jpg`, found its 32-byte XOR key, reassembled the
hex-encoded DNS queries sent to `cutekittenzz.xyz` via the internal DNS resolver (`10.0.0.20`), and
recovered the stolen `topphemligt.pdf` file in CyberChef. Then I deobfuscated an embedded JSFuck
script (bypassing a `0.1 + 0.2 == 0.3` IEEE 754 floating-point trap) and wrote Suricata and Sigma
rules to detect DNS tunneling.

### 2. [Can Local LLMs Find and Fix Security Bugs from Pentest Reports? (B.Sc. Thesis)](./02-llm-vulnerability-rca/)
Together with Aiman Ibrahim Belhadj and Brian Muhirwa, I tested four local open-weight LLMs
(`Ministral 3 14B Reasoning`, `Qwen 3.5-9B`, `qwen2.5-coder:14b`, and `qwen2.5-coder:7b`) on consumer
hardware (Ryzen 5 7600, 32 GB RAM) across five vulnerabilities in **OWASP Juice Shop**. We found
that giving a model the relevant source file directly in LM Studio scored **58.3% (70/120)**, while
indexing all 955 files into a naive text-chunking RAG pipeline in Open WebUI dropped accuracy to
**31.7% (38/120)**—and when a human pentest report misclassified a DOM-XSS bug as Reflected XSS
(TC3), every single model scored **0/6** because none of them questioned the report's label.

### 3. [Smart Home & IoT Security Assessment](./03-iot-security-assessment/)
Set up a smart home lab with Home Assistant OS on a Raspberry Pi 4, a Reolink IP camera, Shelly
sensors, and Nedis/Tuya smart plugs. After configuring **Cisco SPAN port mirroring** on the switch
so Wireshark on Kali could see unicast traffic to the camera, we cracked the camera's RTSP stream
(`554/tcp`) in **78 seconds** with THC-Hydra (`1,928` attempts) and spotted it sending constant UDP
packets (`58200/udp`) to an AWS EC2 server in Paris (`15.236.144.249`). We finished by designing a
3-VLAN segmentation plan (`MGMT_CORE`, `IOT_UNTRUSTED`, `USER_GUEST`) and firewall rules.

### 4. [PowerShell Infrastructure & Security Automation](./04-powershell-infrastructure-automation/)
Three PowerShell scripts built from our Windows Server and Active Directory labs:
- **`Invoke-DHCPDeployment.ps1`**: Installs DHCP, authorizes the server in AD (`Add-DhcpServerInDC`),
  sets up the scope, exclusions, router/DNS options, and MAC reservations, and clears the Server
  Manager registry warning flag.
- **`Sync-ADUsersAndGroups.ps1`**: Exports and imports AD users and their group memberships via CSV,
  creates departmental folders and locks down NTFS permissions with `icacls` (`(OI)(CI)M` vs.
  `(OI)(CI)F`), and sets GPO security registry keys (`DisableCAD = 0`).
- **`Deploy-HyperV-VM.ps1`**: Builds Generation 2 UEFI VMs with Secure Boot and attaches a 6-disk
  SCSI storage array formatted with 64 KB NTFS clusters for SQL Server.

### 5. [Enterprise Network Architecture & OPNsense UTM Firewall](./05-enterprise-network-architecture/)
Two networking projects in one folder:
- **Part 1 (Cisco Multi-Site Design):** Designed a two-campus school network (Borås `10.0.0.0/16` &
  Göteborg `172.16.0.0/16`) with VLSM subnetting for 2,500+ students, LACP port-channels, Rapid
  PVST+, HSRPv2 with WAN link tracking, dual-ISP GRE tunnels with OSPFv2 cost tuning (`10` vs.
  `100`), and Extended ACLs isolating the student VLANs.
- **Part 2 (OPNsense UTM Firewall):** Built a small-business UTM firewall on a dual-NIC PC using
  OPNsense with stateful `pf` rules, inline Suricata IPS (`ET Open`), Squid + C-ICAP + ClamAV
  antivirus, Unbound DNSBL content filtering (blocking `bt.com`, `bet365.com`, and `facebook.com`
  over both HTTP and HTTPS), and OpenVPN with a local CA.

### 6. [Web Application Penetration Testing (OWASP WSTG — Decidim)](./06-web-application-penetration-testing/)
Built a two-VM lab on a Hyper-V **Private Virtual Switch** (`192.168.50.0/24`) and tested **Decidim**
(`Ruby on Rails` / `Puma 6.5.0`) from Kali Linux using the OWASP WSTG v4.2 checklist. I found three
Medium-severity deployment/configuration flaws—a full stack trace leak on malformed HTTP requests
(`GET / GOLD ERROR/1.0`), missing login rate limiting in Burp Intruder, and cleartext HTTP credentials—and
verified why Rails' built-in CSRF tokens, `HttpOnly`/`SameSite` cookies, ERB HTML auto-escaping, and
ActiveRecord parameterized queries stopped XSStrike and SQLMap.

### 7. [Active Directory Lab (`lab.internal` & `fjunne.local`)](./07-active-directory-lab/)
Documents both my solo Active Directory home lab (`lab.internal` on Windows Server 2025 and Windows
11, built to practice DNS SRV records, OUs, `redircmp`, password-reset delegation, and GPO
troubleshooting) and our 15-machine school branch project (`fjunne.local` on Windows Server 2019,
with two domain controllers, Cisco NAT & port forwarding, Folder Redirection, Roaming Profiles, a
4-node SQL Server Failover Cluster with AlwaysOn Availability Groups, PowerShell DHCP, WDS PXE boot,
and an Ubuntu Apache web server).

---

## Repository structure

```text
cybersecurity-portfolio/
├── README.md
│
├── 01-network-forensics-dns-tunneling/
│   ├── README.md
│   └── Incident_Report_DNS_Tunneling_Exfiltration.pdf
│
├── 02-llm-vulnerability-rca/
│   ├── README.md
│   └── BSc_Thesis_LLM_Vulnerability_RCA.pdf
│
├── 03-iot-security-assessment/
│   ├── README.md
│   └── IoT_Security_Assessment_Report.pdf
│
├── 04-powershell-infrastructure-automation/
│   ├── README.md
│   ├── Invoke-DHCPDeployment.ps1
│   ├── Sync-ADUsersAndGroups.ps1
│   ├── Deploy-HyperV-VM.ps1
│   └── HyperV_VM_Automation_Lab_Guide.pdf
│
├── 05-enterprise-network-architecture/
│   ├── README.md
│   ├── MultiSite_Enterprise_Network_Design.pdf
│   └── OPNsense_UTM_Firewall_Implementation.pdf
│
├── 06-web-application-penetration-testing/
│   ├── README.md
│   └── Web_Application_Penetration_Testing_Report.pdf
│
└── 07-active-directory-lab/
    ├── README.md
    ├── school-project-fjunne.md
    ├── Serversystem och Infrastruktur.pdf
    └── docs/
        ├── lab-journal.md
        └── screenshots/
```
