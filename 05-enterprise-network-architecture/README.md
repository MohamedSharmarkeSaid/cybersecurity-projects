# Enterprise Network Architecture & UTM Security Blueprint
## Dual-Campus High-Availability Design, Resilient Dynamic Routing & Multi-Layer Unified Threat Management

**Author**: Mohamed Said  
**Target Environment**: Multi-Site Enterprise Campus (Site 1 - HQ Borås / Site 2 - Branch Göteborg)  
**Primary Technologies**: Cisco IOS (L2/L3 Switching & Routing), HSRP, LACP (802.3ad), Rapid PVST+ (802.1w), OSPFv2 Multi-Area, GRE Tunneling, Dynamic NAT/PAT, Extended ACLs, OPNsense UTM, FreeBSD Netmap IPS, C-ICAP, ClamAV, Unbound DNS, OpenVPN PKI  
**Classification**: Production Network Engineering & Security Architecture Deliverable  

---



## 1. Executive Summary & Architectural Scope

Modern distributed enterprise operations depend entirely on continuous network availability, strict cryptographic isolation across WAN circuits, and deep boundary inspection capable of detecting advanced persistent threats. This architectural blueprint documents the complete end-to-end design, implementation snippets, and operational validation for a dual-site enterprise educational and administrative campus:

- **Site 1 (Headquarters - Borås)**: Houses central enterprise data center workloads, core administrative departments, faculty clusters, and primary student computing infrastructure.
- **Site 2 (Branch Campus - Göteborg)**: Provides local branch operations, local caching, secondary classroom computing, and branch administrative services.

| Security Directive | Implementation Strategy & Technical Controls |
|:---|:---|
| **High Availability & Redundancy** | Zero single points of failure across L2 switching (LACP), L3 default gateways (HSRPv2), and inter-campus WAN transit paths (OSPFv2 GRE). |
| **Deterministic Traffic Engineering** | Primary traffic utilizes flat-rate, high-capacity ISP links. Metered secondary ISP circuits remain passive until failure (Floating AD 10). |
| **Least-Privilege Segmentation** | Strict 802.1Q VLAN separation enforced via stateful Extended ACLs. Finance and Management subnets isolated from students. |
| **Deep Content & Perimeter Hardening** | Open-source Unified Threat Management (OPNsense) featuring ZFS integrity, C-ICAP/ClamAV proxy scanning, inline Suricata IPS (FreeBSD netmap), Unbound DNSBL, and OpenVPN TLS 1.3 PKI. |

The underlying technical implementations conform to rigorous Cisco IOS command standards, RFC specifications (RFC 1918, RFC 2818, RFC 2784, RFC 2281, RFC 2328, RFC 7348), and production enterprise hardening standards.

### 1.1 Primary Project Deliverables & Artifacts
* 📄 **Dual-Campus Network Engineering Project (PDF)**: [`MultiSite_Enterprise_Network_Design.pdf`](./MultiSite_Enterprise_Network_Design.pdf) — Complete 1.5hp enterprise network design, VLAN layout, and physical rack implementation documentation.
* 📄 **OPNsense UTM Firewall Implementation (PDF)**: [`OPNsense_UTM_Firewall_Implementation.pdf`](./OPNsense_UTM_Firewall_Implementation.pdf) — Complete hardware UTM setup, content filtering, and threat management manual.

---

## 2. Campus Topology & Network Architecture

The multi-site enterprise infrastructure employs a hierarchical modular design across both campuses (Site 1 HQ Borås and Site 2 Branch Göteborg):

* **Perimeter & Edge UTM Inspection**: Hardened OPNsense UTM appliances are deployed inline at each campus boundary, performing deep packet inspection, IDS/IPS, and application proxying before traffic enters edge routing.
* **Dual Edge Routers with Gateway Redundancy**: Dual Cisco routers at each site configured with HSRPv2 (Priority 110 active on R1, Priority 90 standby on R2) and WAN interface tracking to guarantee sub-second default gateway failover.
* **Core & Distribution Switching Layer**: Redundant switches connected via 802.3ad LACP Port-Channels in a triangle topology, running Rapid PVST+ (802.1w) to prevent bridging loops and enable sub-second Spanning Tree convergence.
* **Dual-Provider WAN & Dynamic GRE Encapsulation**: Inter-campus traffic traverses point-to-point GRE tunnels across high-speed ISP 1 (OSPF Cost 10), with automatic failover to metered ISP 2 (OSPF Cost 100) via floating static routes.

---

## 3. VLSM IP Addressing & WAN Infrastructure

The enterprise addressing scheme applies Variable Length Subnet Masking (VLSM) to achieve route summarization and departmental isolation (HQ `10.0.0.0/16`, Branch `172.16.0.0/16`):

### Departmental Subnet Allocations

| Department / Function | Site 1 HQ (Borås)<br/>VLAN / CIDR | Site 2 Branch (Göteborg)<br/>VLAN / CIDR | Usable Hosts<br/>(HQ / Branch) | HSRP Default Gateway (VIP)<br/>(HQ / Branch) |
|:---|:---|:---|:---:|:---|
| **Studenter (Students)** | VLAN 10 &bull; `10.0.8.0/21` | VLAN 50 &bull; `172.16.10.0/23` | 2046 / 510 | `10.0.15.254` / `172.16.11.254` |
| **Lärare (Faculty / Staff)** | VLAN 20 &bull; `10.0.20.0/23` | VLAN 60 &bull; `172.16.20.0/26` | 510 / 62 | `10.0.21.254` / `172.16.20.62` |
| **Ekonomi (Finance)** | VLAN 30 &bull; `10.0.30.0/25` | VLAN 70 &bull; `172.16.30.0/27` | 126 / 30 | `10.0.30.126` / `172.16.30.30` |
| **Management (Admin / SVI)** | VLAN 40 &bull; `10.0.40.0/26` | VLAN 80 &bull; `172.16.40.0/26` | 62 / 62 | `10.0.40.62` / `172.16.40.62` |
| **Data Center / Local Servers** | VLAN 50 &bull; `10.0.50.0/24` | VLAN 90 &bull; `172.16.50.0/27` | 254 / 30 | `10.0.50.254` / `172.16.50.30` |
| **DMZ (Perimeter / Proxies)** | VLAN 60 &bull; `10.0.60.0/27` | VLAN 100 &bull; `172.16.60.0/28` | 30 / 14 | `10.0.60.30` / `172.16.60.14` |

### WAN Circuits & Point-to-Point GRE Tunnels

| Link Designation | Interface | Subnet Network | Node A (HQ) | Node B (Branch / ISP) | Routing Role & Failover |
|:---|:---|:---|:---|:---|:---|
| **Primary WAN (ISP 1)** | Serial `0/0/0` | `132.10.5.0/30` / `149.99.2.0/30` | `132.10.5.2` (R1-S1) | `149.99.2.2` (R1-S2) | High-speed flat-rate circuit |
| **Backup WAN (ISP 2)** | Serial `0/0/0` | `78.15.82.128/30` / `82.22.4.252/30` | `78.15.82.130` (R2-S1) | `82.22.4.254` (R2-S2) | Metered backup (Floating AD 10) |
| **Primary GRE Tunnel** | `Tunnel 0` | `192.168.10.0/30` | `192.168.10.1` (R1-S1) | `192.168.10.2` (R1-S2) | Active inter-site backbone (OSPF Cost 10) |
| **Backup GRE Tunnel** | `Tunnel 0` | `192.168.20.0/30` | `192.168.20.1` (R2-S1) | `192.168.20.2` (R2-S2) | Standby inter-site backbone (OSPF Cost 100) |

---

## 4. Core Enterprise Network & Security Architecture

The dual-campus enterprise network implements defense-in-depth across the following critical architectural domains:

### Layer 2 Switching & High Availability
* **Triangle LACP Aggregation**: Switches at each campus are interconnected via dual FastEthernet/Gigabit links bundled into IEEE 802.3ad LACP Port-Channels (Port-Channel 1, 2, and 3), creating a resilient distribution loop with automated bandwidth aggregation.
* **Rapid PVST+ (802.1w) Root Engineering**: Deterministic sub-second Spanning Tree convergence with explicit root bridge priorities (Site 1: `Switch-Kontor` Priority 4096 primary, `Switch-Serverrum` Priority 8192 secondary). Edge ports enforce `spanning-tree portfast` and `bpduguard enable`.

* **First-Hop Redundancy (HSRPv2)**: Gateway high availability configured across all departmental subinterfaces (`standby version 2`) with priority preemption and WAN interface tracking (`standby track Serial0/0/0 25`), achieving sub-second default gateway failover during edge uplink loss.

### Layer 3 Dynamic Routing & Point-to-Point GRE Tunnels
* **Multi-Area OSPFv2**: Scalable hierarchical routing partitioned into Area 0 (Backbone GRE tunnels), Area 1 (Site 1 HQ `10.0.0.0/16`), and Area 2 (Site 2 Branch `172.16.0.0/16`). All edge client VLANs configure `passive-interface default` to suppress routing broadcasts and eliminate rogue neighbor formation.
* **Resilient GRE Interconnects**: Primary traffic traverses GRE `Tunnel0` (`192.168.10.0/30`, OSPF Cost 10) across high-capacity flat-rate ISP 1. Backup GRE `Tunnel0` (`192.168.20.0/30`, OSPF Cost 100) across metered ISP 2 activates automatically upon primary circuit disruption.
* **MTU/MSS Optimization**: Point-to-point GRE tunnel interfaces enforce `ip mtu 1476` and `ip tcp adjust-mss 1436` to prevent fragmentation overhead across WAN transit paths.

### Edge Perimeter Security & Least-Privilege Access Control
* **Dynamic PAT Overload**: Border routers translate internal private subnets to external serial WAN IPs with overload pools, providing controlled outbound Internet transit.
* **Extended Access Control Lists (ACLs)**: Strict inter-VLAN boundary enforcement deployed on router subinterfaces (`ACL_STUDENTER`, `ACL_LARARE`, `ACL_EKONOMI`, `ACL_MANAGEMENT`). Student segments are explicitly denied access to administrative SVIs, finance records, and internal database servers while permitting filtered Internet access.

---

## 5. OPNsense UTM Firewall Hardening & Deep Content Security

To protect the campus perimeter from web-borne malware, application exploits, command-and-control communication, and unauthorized remote access, dedicated x86_64 Unified Threat Management (UTM) appliances running hardened OPNsense (FreeBSD-based) are deployed in line at both campuses.

| UTM Subsystem | Implementation Architecture & Hardening Controls |
|:---|:---|
| **Filesystem Baseline** | ZFS Root Pool (`zpool`) with Copy-on-Write snapshots & dataset compression. |
| **Web Proxy & AV** | C-ICAP daemon coupled with ClamAV streaming scanning (`icap://[::1]:1344`). |
| **Intrusion Prevention** | Suricata multi-threaded engine using FreeBSD netmap inline packet dropping. |
| **Secure DNS Layer** | Unbound DNS with DNSBL malware domain filtering & DNS-over-TLS (DoT). |
| **Remote Access PKI** | OpenVPN SSL/TLS server with dedicated CA (`TNFW-ROOTCA`) & client isolation. |


## Deliverables & Artifacts

| Deliverable | Description | Format / Location |
|:---|:---|:---|
| **Multi-Site Network Design Dossier** | Comprehensive engineering paper covering dual-campus topology, VLSM IP schemes, LACP, HSRPv2, OSPFv2, and GRE failover. | [`MultiSite_Enterprise_Network_Design.pdf`](./MultiSite_Enterprise_Network_Design.pdf) (371 KB) |
| **OPNsense UTM Implementation Guide** | Complete production firewall hardening guide covering FreeBSD Netmap, Suricata inline IPS, C-ICAP/ClamAV, and OpenVPN PKI. | [`OPNsense_UTM_Firewall_Implementation.pdf`](./OPNsense_UTM_Firewall_Implementation.pdf) (1.3 MB) |
