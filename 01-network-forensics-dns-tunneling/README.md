# Security Incident Response Report: Operation Kattastrofen
## Advanced Network Forensics, Covert DNS Tunneling & Cryptographic Reverse Engineering

[![Incident Classification: CRITICAL](https://img.shields.io/badge/Incident%20Severity-CRITICAL-red?style=for-the-badge&logo=shield)](https://mitre-attack.github.io/)
[![Investigation Standard: NIST SP 800-61 Rev. 2](https://img.shields.io/badge/Investigation%20Framework-NIST%20SP%20800--61%20Rev.%202-blue?style=for-the-badge)](https://csrc.nist.gov/publications/detail/sp/800-61/rev-2/final)
[![TLP: CLEAR](https://img.shields.io/badge/Traffic%20Light%20Protocol-TLP%3ACLEAR-green?style=for-the-badge)](https://www.first.org/tlp/)
[![MITRE ATT&CK: T1071.004](https://img.shields.io/badge/MITRE%20ATT%26CK-T1071.004-orange?style=for-the-badge)](https://attack.mitre.org/techniques/T1071/004/)

---

## 1. Executive Summary & Incident Overview

### 1.1 Engagement Context
This formal incident response report documents the forensic investigation of **Operation Kattastrofen**, a simulated advanced persistent threat (APT) scenario modeled after a real-world technical assessment developed by **FRA (Försvarets radioanstalt — Swedish National Defence Radio Establishment)**. The incident involves the compromise of a high-security government workstation, the harvesting of classified internal documentation, and the subsequent exfiltration of that data across a covert **DNS Tunneling** Command and Control (C2) channel designed to bypass standard perimeter security controls.

### 1.2 Incident Synopsis
On the target network, an employee holding high-level security clearance was compromised via social engineering. The initial entry point was a drive-by download/watering-hole mechanism disguised as innocuous images of kittens (`kitten-*.jpg`). One of these image files (`kitten-3.jpg`) contained a polyglot steganographic bash dropper that activated upon download. 

The payload executed entirely in memory and temporary directories (`/tmp`), harvested the victim's `$HOME/Documents` directory, archived it into a TAR file, applied a multi-layer encryption scheme combining a repeating 32-byte bitwise XOR key with Base64 framing, and spawned a native compiled ELF dropper binary named `mjau`. The binary chunked the encrypted payload into hexadecimal subdomains, appending an 18-character sequence tracking prefix, and exfiltrated the entire archive through high-frequency recursive DNS lookups directed at the malicious external domain `cutekittenzz.xyz`.

* **Attack Chain Flow**: Social engineering steganography &rarr; `/tmp` payload execution &rarr; Document harvesting & archiving &rarr; 32-byte XOR cipher &rarr; Multi-stage DNS C2 tunneling &rarr; External reassembly at `cutekittenzz.xyz`.

### 1.3 Key Investigation Findings & Impact Assessment
- **Primary Compromised Host**: Internal workstation `10.0.0.10`, responsible for **99.93%** of all network frames in the forensic capture (`kattastrofen.pcap`).
- **Internal Resolver Exploited**: Enterprise DNS resolver `10.0.0.20`, responsible for **93.96%** of frames, used as an unwitting recursive conduit.
- **Malicious Apex Domain**: `cutekittenzz.xyz`, registered and operated by the adversary as an authoritative nameserver for C2 and data reassembly.
- **Data Compromised**: Full extraction of `$HOME/Documents`, including sensitive government intelligence (`topphemligt.pdf`).
- **Forensic Flags Recovered**:
  - **Flag 1** (`flagga1{klassiska_lösenord_för_100}`): Recovered by inspecting web traffic and extracting the password-protected ZIP archive using credential `hunter2`.
  - **Flag 2** (`flagga2{every_day_is_caturday}`): Recovered by reconstructing the exfiltrated TAR archive from the DNS capture and inspecting the watermarked classified PDF.
  - **Flag 3** (`flagga3{mj4u!}`): Recovered through static reverse engineering of an obfuscated JSFuck script embedded in the PDF, bypassing an IEEE 754 floating-point anti-analysis sandbox check, and decoding a 106-bit binary matrix ASCII art banner.

### 1.4 Primary Project Deliverables & Artifacts
* 📄 **Formal Forensic Investigation Report**: [Incident_Report_DNS_Tunneling_Exfiltration.pdf](./Incident_Report_DNS_Tunneling_Exfiltration.pdf) — Full technical investigation dossier featuring Wireshark packet capture telemetry, CyberChef deobfuscation formulas, and evidence recovery.
* 🛡️ **Detection Signatures**: Production-ready Suricata, Snort, and Sigma detection rules included in the forensic report.

---

## 2. Attack Lifecycle & Incident Reconstruction

1. **Initial Access & Delivery**: Workstation `10.0.0.10` downloads steganographic image `kitten-03.jpg` and password-protected `archive.zip` via HTTP. Decrypting the archive with credential `hunter2` recovers **Flag 1** (`flagga1{klassiska_lösenord_för_100}`).
2. **Steganographic Extraction & Cryptographic Staging**: An embedded bash dropper extracted from `kitten-3.jpg` executes in `/tmp`, displaying a decoy kitten image while archiving `$HOME/Documents` into `/tmp/exfil.tar`. It applies a 32-byte repeating XOR key and Base64 encoding to produce `/tmp/exfil.dat`.
3. **Covert DNS Tunneling Exfiltration**: The adversary deploys the `./mjau` ELF executable, chunking the encrypted ciphertext into hexadecimal subdomains prepended with an 18-character sequence tracking header (`[seq].[chunk].cutekittenzz.xyz`). These are queried against internal recursive resolver `10.0.0.20`, which forwards them upstream to authoritative C2 nameserver `cutekittenzz.xyz`.
4. **Adversary Reassembly & Flag Recovery**: The C2 server strips sequence headers and concatenates the hexadecimal stream, reconstructing the TAR archive and extracting `topphemligt.pdf` to uncover **Flag 2** (`flagga2{every_day_is_caturday}`). Static analysis of obfuscated JSFuck inside the PDF and bypassing an IEEE 754 float precision check (`0.1 + 0.2 == 0.3`) uncovers **Flag 3** (`flagga3{mj4u!}`).
 
---

## 3. Project Deliverables & Investigation Files

The complete technical report detailing full packet filters, CyberChef deobfuscation recipes, and detection signatures is available below:

| Deliverable | Description | Link |
|:---|:---|:---:|
| 📄 **Incident Response Report** | Formal forensic investigation dossier featuring PCAP telemetry, Wireshark/tshark packet filters, CyberChef formulas, and Sigma/Suricata detection rules. | [**Incident_Report_DNS_Tunneling_Exfiltration.pdf**](./Incident_Report_DNS_Tunneling_Exfiltration.pdf) |

```
01-network-forensics-dns-tunneling/
├── README.md                                  # Executive incident summary & attack reconstruction
└── Incident_Report_DNS_Tunneling_Exfiltration.pdf # Complete forensic investigation report (PDF)
```
