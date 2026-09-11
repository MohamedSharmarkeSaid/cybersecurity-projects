# Mohamed Said — Cybersecurity & Network Security Portfolio

<div align="center">

[![Live Website](https://img.shields.io/badge/Website-Live%20Portfolio-06b6d4?style=flat-square&logo=googlechrome&logoColor=white)](https://mohamedsharmarkesaid.github.io/cybersecurity-projects/)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Mohamed%20Said-0A66C2?style=flat-square&logo=linkedin)](https://www.linkedin.com/in/mohamed-sharmarke-661582338/)
[![GitHub](https://img.shields.io/badge/GitHub-cybersecurity--projects-181717?style=flat-square&logo=github)](https://github.com/MohamedSharmarkeSaid/cybersecurity-projects)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](./LICENSE)

**SOC Analyst • Network Security Engineer • Incident Response • Systems Automation**

</div>

---

## Executive Profile

I am a **Cybersecurity and SOC Analyst** with a Bachelor of Science in Engineering (**Computer Engineering – IT Infrastructure & Cybersecurity**) from the **University of Borås**, Sweden.

My background combines operational defensive security (**Security Operations Center, alert triage, incident response, packet forensics**) with enterprise infrastructure engineering (**Cisco routing/switching, UTM firewalls, Active Directory hardening**) and automation (**PowerShell, Infrastructure as Code**).

> 💡 **Certifications & Credentials**: All active professional certifications and verified digital badges are maintained on my **[LinkedIn Profile](https://www.linkedin.com/in/mohamed-sharmarke-661582338/)**.

---

## Technical Skill Matrix

| Domain | Key Technologies & Methodologies |
|:---|:---|
| **SOC & Blue Team** | Alert Triage, Incident Response (NIST SP 800-61), SIEM Telemetry, MITRE ATT&CK, Suricata, Sigma Rules |
| **Digital Forensics** | Packet Analysis (**Wireshark, tshark**), Network Forensics, Deobfuscation (**CyberChef**), C2 / DNS Tunneling Detection |
| **Enterprise Networking** | Cisco IOS, OSPFv2, HSRP Gateway Redundancy, LACP, 802.1Q VLANs, GRE Tunnels, Extended ACLs, NAT/PAT |
| **Perimeter Security** | **OPNsense UTM**, Inline IPS (Suricata / Netmap), Web Proxy & Antivirus (ClamAV/C-ICAP), DNSBL Filtering, OpenVPN |
| **Systems & IaC** | **PowerShell 7 / 5.1**, Active Directory Domain Services, GPO Security Hardening, NTFS / `icacls`, Hyper-V Gen 2 IaC |
| **AppSec & Penetration Testing** | **OWASP WSTG v4.2**, Burp Suite, SQLMap, XSStrike, Gobuster, Nikto, Vulnerability RCA, Local LLMs (LM Studio, Open WebUI) |

---

## Project Directory

Each project directory below provides a structured case study (**Objective → Methodology → Results**) along with the primary reports and script files:

| # | Project | Domain | Key Findings & Results | Deliverables |
|:---:|:---|:---|:---|:---:|
| **01** | [**Network Forensics: DNS Tunneling Detection**](./01-network-forensics-dns-tunneling/) | DFIR / Threat Hunting | Reconstructed multi-stage APT intrusion; identified covert DNS exfiltration to `cutekittenzz.xyz`; recovered 3 flags via CyberChef; authored Sigma/Suricata detection rules. | [Report & Evidence](./01-network-forensics-dns-tunneling/) |
| **02** | [**AI-Assisted Vulnerability Root Cause Analysis**](./02-llm-vulnerability-rca/) | AppSec / Local AI | Evaluated 4 local LLMs across 40 test runs on OWASP Juice Shop. Bounded context outperformed RAG (58.3% vs 31.7%). Uncovered vulnerability inversion risks in naive RAG. | [111-Page Thesis PDF](./02-llm-vulnerability-rca/) |
| **03** | [**IoT Security Assessment & Penetration Testing**](./03-iot-security-assessment/) | IoT / Hardening | Cracked camera RTSP credentials in 78 seconds (CVSS 9.1); intercepted unauthorized AWS telemetry via Cisco SPAN; mitigated threat via 3-VLAN segmentation and ACLs. | [Report & SPAN Config](./03-iot-security-assessment/) |
| **04** | [**PowerShell Infrastructure Automation & IaC**](./04-powershell-infrastructure-automation/) | Systems / Automation | Production-grade automation scripts for AD user/group provisioning, CIS GPO baselines, `icacls` permission hardening, DHCP deployment, and Gen 2 Hyper-V multi-disk arrays. | [PowerShell Scripts](./04-powershell-infrastructure-automation/) |
| **05** | [**Enterprise Dual-Campus Network & UTM Firewall**](./05-enterprise-network-architecture/) | Network / Perimeter | Designed dual-campus network (HQ Borås & Branch Göteborg) with OSPF, GRE tunnels, and HSRP redundancy. Deployed OPNsense UTM firewall with inline IPS and proxy filtering. | [Network & UTM Guides](./05-enterprise-network-architecture/) |
| **06** | [**Web Application Penetration Testing (OWASP WSTG)**](./06-web-application-penetration-testing/) | Web AppSec / Pentest | Executed OWASP WSTG evaluation against Decidim (Ruby on Rails/Puma) in Hyper-V sandbox. Identified stacktrace leakage & rate limiting gaps; validated ORM & template defenses. | [36-Page Pentest Report](./06-web-application-penetration-testing/) |

---

## Repository Structure

```text
cybersecurity-projects/
├── README.md                                  # Portfolio landing page and executive summary
├── LICENSE                                    # MIT License
├── .gitignore                                 # Git ignore configuration
│
├── 01-network-forensics-dns-tunneling/        # Module 01: PCAP analysis, CyberChef, Sigma rules
│   ├── README.md                              # Case study & detection playbook
│   └── Incident_Report_DNS_Tunneling_Exfiltration.pdf # Primary forensic investigation report
│
├── 02-llm-vulnerability-rca/                  # Module 02: B.Sc. Engineering Thesis
│   ├── README.md                              # Benchmark summary, results & AppSec guidelines
│   └── BSc_Thesis_LLM_Vulnerability_RCA.pdf   # Complete 111-page thesis research paper
│
├── 03-iot-security-assessment/                # Module 03: Home Assistant pentest & hardening
│   ├── README.md                              # Vulnerability findings, SPAN mirroring & VLAN design
│   └── IoT_Security_Assessment_Report.pdf     # Hardware assessment & remediation report
│
├── 04-powershell-infrastructure-automation/   # Module 04: Production PowerShell IaC scripts
│   ├── README.md                              # Script documentation & parameter guides
│   ├── Invoke-DHCPDeployment.ps1              # Automated Windows Server DHCP provisioning
│   ├── Sync-ADUsersAndGroups.ps1              # CSV identity sync, GPO baselines, icacls hardening
│   ├── Deploy-HyperV-VM.ps1                   # Gen 2 Hyper-V VM IaC & 6-disk database array
│   └── HyperV_VM_Automation_Lab_Guide.pdf     # Infrastructure implementation reference
│
├── 05-enterprise-network-architecture/        # Module 05: Cisco campus & OPNsense UTM
│   ├── README.md                              # Dual-campus routing, switching & UTM blueprint
│   ├── MultiSite_Enterprise_Network_Design.pdf # Enterprise network engineering design
│   └── OPNsense_UTM_Firewall_Implementation.pdf # Hardware UTM setup & threat management
│
└── 06-web-application-penetration-testing/    # Module 06: OWASP WSTG web penetration testing
    ├── README.md                              # Assessment summary, methodology & test matrix
    └── Web_Application_Penetration_Testing_Report.pdf # Complete 36-page penetration test report
```

---

## Contact & Connect

* **LinkedIn**: [linkedin.com/in/mohamed-sharmarke-661582338](https://www.linkedin.com/in/mohamed-sharmarke-661582338/)
* **GitHub**: [github.com/MohamedSharmarkeSaid/cybersecurity-projects](https://github.com/MohamedSharmarkeSaid/cybersecurity-projects)
* **Location**: Borås / Gothenburg, Sweden (Open to on-site in Saudi Arabia, Hybrid & Remote)

---

## Standards & Methodologies Followed

All implementations, reports, and codebases in this repository adhere to globally recognized industry cybersecurity, networking, and governance standards:

* **Incident Response & Digital Forensics**: NIST SP 800-61 Rev. 2 (*Computer Security Incident Handling Guide*), MITRE ATT&CK Enterprise Framework, SANS Incident Handler's Handbook.
* **Penetration Testing & Security Assessment**: OWASP Internet of Things Top 10, NIST SP 800-115 (*Technical Guide to Information Security Testing and Assessment*), NIST SP 800-213 (*IoT Device Cybersecurity Guidance*), PTES (Penetration Testing Execution Standard).
* **Application Security & Vulnerability Analysis**: OWASP Top 10 (2021), OWASP Web Security Testing Guide (WSTG v4.2), Common Weakness Enumeration (CWE/SANS Top 25).
* **Enterprise Networking**: IEEE 802.1Q (VLAN Trunking), IEEE 802.3ad (LACP), IEEE 802.1w (Rapid Spanning Tree), RFC 2328 (OSPFv2), RFC 2784 (GRE), RFC 2281 (HSRP), RFC 1918 (Private Address Allocation).
* **Systems Hardening & Governance**: CIS Microsoft Windows Server Benchmarks, Principle of Least Privilege (PoLP), Zero Trust Architecture (NIST SP 800-207).

---

## Recruiter & Professional Connect

I am actively open to discussing roles in:
* **Security Operations Center (SOC) Analyst (L1 / L2)**
* **Network Security Engineer / Infrastructure Security Specialist**
* **Incident Response & Threat Hunting Analyst**
* **Application Security / DevSecOps Engineer**

| Parameter | Details |
|:---|:---|
| **Name** | Mohamed Said (Mohamed Sharmarke Said) |
| **Location** | Sweden (Borås / Gothenburg / Open to Hybrid & Remote) |
| **Degree** | B.Sc. in Computer Engineering, University of Borås (2026) |
| **Target Roles** | SOC Analyst, Network Security Engineer, DFIR, AppSec |
| **Languages** | Swedish (Native / Fluent) &bull; English (Full Professional Proficiency) |
| **Availability** | Full-time / Immediate availability |
| **Certifications** | Verified credentials & digital badges maintained on [LinkedIn](https://www.linkedin.com/in/mohamed-sharmarke-661582338/) |

* **GitHub**: [github.com/MohamedSharmarkeSaid/cybersecurity-projects](https://github.com/MohamedSharmarkeSaid/cybersecurity-projects)
* **LinkedIn**: [linkedin.com/in/mohamed-sharmarke-661582338](https://www.linkedin.com/in/mohamed-sharmarke-661582338/)
* **Direct Inquiries**: Professional contact details and formal references available upon request.

---

<div align="center">
  <small>© 2026 Mohamed Said. Released under the <a href="./LICENSE">MIT License</a>. Engineered with precision.</small>
</div>
