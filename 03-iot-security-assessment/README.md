# IoT Security Assessment & Penetration Testing: Smart Home Infrastructure Hardening

[![Assessment Standard](https://img.shields.io/badge/Methodology-OWASP%20IoT%20Top%2010%20%7C%20NIST%20SP%20800--213-blue.svg)](#assessment-scope-methodology--severity-matrix)
[![Target Platform](https://img.shields.io/badge/Platform-Home%20Assistant%20OS%202025.4.1-41BDF5.svg)](#target-environment--hardware-inventory)
[![Switch Infrastructure](https://img.shields.io/badge/Network-Cisco%20Catalyst%20SPAN%20%7C%20802.1Q-049fd9.svg)](#network-sniffing--cisco-catalyst-span-port-mirroring)
[![Exploitation Proof](https://img.shields.io/badge/Exploit-THC--Hydra%20RTSP%20Auth%20Bypass-critical.svg)](#finding-01-reolink-rlc-520a-rtsp-authentication-brute-force-and-stream-hijacking)
[![Telemetry Leakage](https://img.shields.io/badge/Telemetry-AWS%20EC2%20Exfiltration%20Detected-orange.svg)](#finding-02-unauthorized-cloud-telemetry-and-covert-data-leakage-to-aws-ec2)
[![Architecture](https://img.shields.io/badge/Remediation-Zero--Trust%20VLAN%20Segmentation-success.svg)](#enterprise-vlan-network-segmentation--isolation-architecture)

---

## Executive Summary

During an authorized technical security evaluation conducted in April 2025 (*Ethical Hacker, IoT och Molntjänster*, Test Facility D208, Test Group **IoT3**), a comprehensive penetration test and architectural security assessment was executed against an active Internet of Things (IoT) ecosystem managed by **Home Assistant OS 2025.4.1** deployed on a **Raspberry Pi 4 Model B**. The target infrastructure integrated physical IP surveillance cameras, smart plugs, smart environmental sensors, Wi-Fi LED controllers, an ASUS perimeter gateway, and an enterprise **Cisco Catalyst managed switch** (`SW_IOT3`).

The assessment revealed critical vulnerabilities across multiple layers of the IoT deployment:
1. **Critical Protocol & Authentication Weakness (CVSS 9.1)**: The **Reolink RLC-520A** IP surveillance camera exposed an unauthenticated RTSP stream daemon (port 554) with zero rate-limiting or lockout mechanisms. A dictionary brute-force attack utilizing **THC-Hydra** successfully cracked the camera's administrative credentials (`admin:Pa55w0rd`) in **1 minute 18 seconds** (1,928 attempts), allowing instantaneous hijacking of live audio/video feeds.
2. **Covert Cloud Telemetry & Data Exfiltration**: Deep packet inspection via **Cisco SPAN port mirroring** intercepted continuous, unprompted outbound UDP traffic from the Reolink camera directed to an external AWS EC2 endpoint (`15.236.144.249:58200` in Paris, France), exfiltrating telemetry despite local-only operational constraints.
3. **Protocol-Level Security Exposures**: Smart plugs and LED strips utilizing **Tuya Cloud** and **MQTT** exhibited cleartext Wi-Fi credential leakage during UDP provisioning, lack of message broker Access Control Lists (ACLs), topic sniffing, and exposure of legacy unencrypted control port 6668.
4. **Perimeter Gateway Exposure**: The border **ASUS RT-AC52U B1** router operated vulnerable firmware (`3.0.0.4.380_10388-g8072fff`), susceptible to critical authentication bypass flaws and transmitting administrative credentials in cleartext HTTP.

To neutralize these threat vectors, this report specifies an **Enterprise 802.1Q Network Segmentation Architecture** (VLANs 10, 20, and 30), stateful firewall Access Control Lists (ACLs), strict WAN blackholing for untrusted cameras, and TLS-encrypted message broker configurations.

* 📄 **Primary Assessment Dossier (PDF)**: [IoT_Security_Assessment_Report.pdf](./IoT_Security_Assessment_Report.pdf) — Complete hardware inventory, testing log, and device configuration documentation.

---

### Executive Risk Dashboard

| Vulnerability ID | Vulnerability Finding | Affected Target | Protocol / Port | CVSS v3.1 | Risk Rating | Status |
|:---|:---|:---|:---|:---:|:---:|:---:|
| **VULN-IOT-01** | RTSP Credential Brute-Force & Stream Hijacking | Reolink RLC-520A Camera | RTSP / TCP 554 | **9.1** | `CRITICAL` | **PoC Verified** |
| **VULN-IOT-02** | Covert AWS Cloud Telemetry & Egress Leakage | Reolink RLC-520A Camera | UDP / 58200 -> AWS | **7.5** | `HIGH` | **PCAP Verified** |
| **VULN-IOT-03** | Gateway Remote Authentication Bypass & Cleartext HTTP | ASUS RT-AC52U B1 Router | HTTP / TCP 80 | **9.8** | `CRITICAL` | **Known CVE** |
| **VULN-IOT-04** | Cleartext Wi-Fi Provisioning & Legacy Port Exposure | Nedis Smart Plug & LED Strip | UDP Broadcast & TCP 6668 | **7.2** | `HIGH` | **Analyzed** |
| **VULN-IOT-05** | Unauthenticated MQTT Broker & Wildcard Sniffing | Home Assistant OS Broker | MQTT / TCP 1883 | **7.5** | `HIGH` | **PoC Verified** |
| **VULN-IOT-06** | Unauthenticated RPCbind & Physical Storage Vector | Home Assistant / Raspberry Pi 4 | RPC / TCP & UDP 111 | **5.3** | `MEDIUM` | **Identified** |

---

## Assessment Methodology & Key Findings

* **Reconnaissance & Service Enumeration**: Profiled active hosts and open daemons on `192.168.1.0/24` using **Nmap**, identifying exposed RTSP (port 554), HTTP (80), ONVIF/gSOAP (8000), unauthenticated Mosquitto MQTT (1883), and RPCbind (111).
* **Hardware Port Mirroring (Cisco SPAN)**: Standard switched Ethernet prevents sniffing unicast traffic. Configured a hardware **Switched Port Analyzer (SPAN)** session on Cisco Catalyst `SW_IOT3` mirroring all ingress and egress frames on camera port `Fa0/4` to Kali tap `Fa0/13` in promiscuous mode without packet loss or stream latency.
* **Authentication Brute-Force Testing**: Executed **THC-Hydra** dictionary attacks against the camera's unthrottled RTSP service, cracking `admin:Pa55w0rd` in 78 seconds (1,928 attempts) and verifying live video feed takeover via `ffplay`.
* **Unauthorized Cloud Egress Detection**: Deep packet analysis intercepted continuous outbound UDP packets (`58200/udp`) from the Reolink camera to AWS EC2 (`15.236.144.249`) in Paris, violating local-only security policy.
* **Smart Plug & Cloud Protocol Risks**: Captured cleartext Wi-Fi provisioning broadcasts on UDP and identified unauthenticated MQTT broker topics allowing unauthorized telemetry inspection.

---

## Enterprise VLAN Network Segmentation & Isolation Architecture

### Defense-in-Depth Architecture Overview

To eliminate the systemic risk of lateral movement between vulnerable IoT endpoints, management controllers, and administrative workstations, an **Enterprise 802.1Q Network Segmentation Architecture** was designed and implemented. 

The architecture enforces a strict **Zero-Trust Containment Model**:
1. **Untrusted IoT devices are quarantined** in an isolated broadcast domain (VLAN 20).
2. **IP Cameras are completely blackholed from the Internet (WAN)**, terminating covert telemetry leaks to AWS.
3. **Home Assistant in VLAN 10 controls IoT devices strictly via one-way stateful pulls** (e.g., pulling RTSP video streams) while dropping all device-initiated connection attempts from VLAN 20 into VLAN 10.
4. **All DNS traffic is forcibly redirected** to an internal, filtering recursive resolver (Pi-hole / Unbound) to block telemetry domains via Response Policy Zones (RPZ).

---

### 802.1Q Network Segmentation Schema

| VLAN ID | VLAN Name | Subnet Range | Gateway IP | Security Trust Level | Purpose & Permitted Traffic |
|:---:|:---|:---|:---|:---:|:---|
| **10** | `MGMT_CORE` | `192.168.10.0/24` | `192.168.10.1` | **High Trust** | Home Assistant controller, administrative workstations, SSH/HTTPS switch management, DNS/NTP services. |
| **20** | `IOT_UNTRUSTED` | `192.168.20.0/24` | `192.168.20.1` | **Zero Trust** | All smart cameras, plugs, bulbs, and climate sensors. Strictly isolated from management; no direct WAN access for cameras. |
| **30** | `GUEST_BYOD` | `192.168.30.0/24` | `192.168.30.1` | **Untrusted** | Guest smartphones, tablets, and personal devices. Internet access only; completely firewalled from VLAN 10 and VLAN 20. |

---

### Stateful Firewall Rule Matrix & Inter-VLAN Access Policies

| Rule # | Source Zone / Subnet | Destination Zone / Subnet | Protocol & Port | Firewall Action | Security Rationale |
|:---:|:---|:---|:---|:---:|:---|
| **FW-01** | `VLAN 10 (Management)` | `VLAN 20 (IoT Subnet)` | `TCP 554` (RTSP), `TCP 80/443` | **PASS** | Permits Home Assistant to initiate and stream video from Reolink camera. |
| **FW-02** | `VLAN 10 (Management)` | `VLAN 20 (IoT Subnet)` | `TCP 80, 443, 6668` | **PASS** | Permits Home Assistant to dispatch local control commands to smart plugs. |
| **FW-03** | `VLAN 20 (IoT Subnet)` | `VLAN 10 (Home Assistant)` | `TCP 8883` (MQTTS) | **PASS (Stateful)**| Permits climate sensors to deliver encrypted telemetry; requires TLS authentication. |
| **FW-04** | `VLAN 20 (IoT Subnet)` | `VLAN 10 (Management)` | **ALL Protocols** | **DROP & LOG** | **Anti-Lateral Movement**: Blocks IoT devices from probing or attacking management nodes. |
| **FW-05** | `192.168.20.100 (Camera)` | `WAN (0.0.0.0/0)` | **ALL Protocols** | **DROP & LOG** | **Total WAN Quarantine**: Terminated outbound AWS telemetry exfiltration (`15.236.144.249`). |
| **FW-06** | `VLAN 20 (Smart Plugs)` | `WAN (0.0.0.0/0)` | `TCP 443, 8883` (Tuya) | **PASS (Scoped)**| Permits necessary Tuya cloud synchronization if local integration is unavailable. |
| **FW-07** | `VLAN 20 (IoT Subnet)` | `Local DNS (192.168.10.2)`| `UDP/TCP 53` | **PASS** | Redirects all IoT DNS queries through internal RPZ filtering resolver. |
| **FW-08** | `VLAN 20 (IoT Subnet)` | `External DNS` | `UDP/TCP 53` | **REDIRECT** | Intercepts rogue hardcoded DNS queries (e.g. `8.8.8.8`) and forces local resolution. |
| **FW-09** | `VLAN 30 (Guest)` | `VLAN 10 / VLAN 20` | **ALL Protocols** | **DROP** | Complete guest isolation from internal automation and management infrastructure. |
| **FW-10** | `ANY` | `ANY` | **ALL Protocols** | **DEFAULT DROP** | Explicit default-deny posture for all unmatched ingress/egress packets. |

---

### Security Remediation & Containment Strategy

* **802.1Q Network Segmentation**: Quarantined untrusted IoT hardware on `VLAN 20 (IOT_UNTRUSTED)` and isolated the Home Assistant controller to `VLAN 10 (MGMT_CORE)`.
* **Zero-Trust Egress Blackholing**: Deployed border ACLs terminating outbound WAN connectivity from IP cameras, permanently neutralizing unauthorized AWS Paris telemetry exfiltration.
* **Service Hardening**: Replaced unauthenticated MQTT with MQTTS (port 8883, TLS 1.3) with strict topic-level ACLs, and disabled legacy unencrypted discovery/control daemons.

---

## Deliverables & Artifacts

| Deliverable | Description | Format / Location |
|:---|:---|:---|
| **Full Security Assessment Report** | Comprehensive technical evaluation dossier with full hardware inventory, scan logs, PoC exploits, and network remediation guidelines. | [IoT_Security_Assessment_Report.pdf](./IoT_Security_Assessment_Report.pdf) (1.0 MB) |
