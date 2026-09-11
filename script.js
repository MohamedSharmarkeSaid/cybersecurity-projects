/**
 * Mohamed Said - Cybersecurity Portfolio Interactive Script
 */

document.addEventListener('DOMContentLoaded', () => {

  // 1. Mobile Navigation Toggle
  const navToggle = document.getElementById('navToggle');
  const navLinks = document.getElementById('navLinks');

  if (navToggle && navLinks) {
    navToggle.addEventListener('click', () => {
      navLinks.classList.toggle('open');
    });

    // Close menu when clicking links on mobile
    navLinks.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        navLinks.classList.remove('open');
      });
    });
  }

  // 2. Active Navbar Link on Scroll (Scrollspy)
  const sections = document.querySelectorAll('section[id], header[id]');
  window.addEventListener('scroll', () => {
    let current = '';
    const scrollPos = window.pageYOffset + 120;

    sections.forEach(section => {
      const top = section.offsetTop;
      const height = section.offsetHeight;
      if (scrollPos >= top && scrollPos < top + height) {
        current = section.getAttribute('id');
      }
    });

    document.querySelectorAll('.nav-link').forEach(link => {
      link.classList.remove('active');
      if (link.getAttribute('href') === `#${current}`) {
        link.classList.add('active');
      }
    });
  });

  // 3. Project Filter Buttons
  const filterBtns = document.querySelectorAll('.filter-btn');
  const projectCards = document.querySelectorAll('.project-card');

  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      const filterValue = btn.getAttribute('data-filter');

      projectCards.forEach(card => {
        if (filterValue === 'all' || card.getAttribute('data-category') === filterValue) {
          card.style.display = 'flex';
          setTimeout(() => { card.style.opacity = '1'; card.style.transform = 'translateY(0)'; }, 50);
        } else {
          card.style.opacity = '0';
          card.style.transform = 'translateY(10px)';
          setTimeout(() => { card.style.display = 'none'; }, 200);
        }
      });
    });
  });

  // 4. Interactive Terminal Tab Switcher
  const termTabs = document.querySelectorAll('.term-tab');
  const termCodes = document.querySelectorAll('.terminal-code');
  const copyBtn = document.getElementById('copyCodeBtn');
  const copyText = document.getElementById('copyText');

  termTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      termTabs.forEach(t => t.classList.remove('active'));
      termCodes.forEach(c => c.classList.remove('active'));

      tab.classList.add('active');
      const targetId = tab.getAttribute('data-tab');
      const targetCode = document.getElementById(targetId);
      if (targetCode) {
        targetCode.classList.add('active');
      }
    });
  });

  if (copyBtn) {
    copyBtn.addEventListener('click', () => {
      const activeCode = document.querySelector('.terminal-code.active code');
      if (activeCode) {
        navigator.clipboard.writeText(activeCode.innerText).then(() => {
          copyText.innerText = 'Copied!';
          setTimeout(() => { copyText.innerText = 'Copy'; }, 2000);
        }).catch(err => {
          console.error('Failed to copy code: ', err);
        });
      }
    });
  }

  // 5. Interactive Project Case Study Modal Data
  const projectDetails = {
    'project-1': {
      title: 'Network Forensics: Covert DNS Tunneling & C2 Extraction',
      tag: 'DFIR / NIST SP 800-61 / MITRE ATT&CK T1071.004',
      pdfUrl: './01-network-forensics-dns-tunneling/Incident_Report_DNS_Tunneling_Exfiltration.pdf',
      githubUrl: 'https://github.com/MohamedSharmarkeSaid/cybersecurity-projects/tree/main/01-network-forensics-dns-tunneling',
      body: `
        <h4>1. Engagement Context & Threat Scenario</h4>
        <p>This formal incident investigation examines <strong>Operation Kattastrofen</strong>, a simulated advanced persistent threat (APT) scenario inspired by real-world technical assessments developed by <em>Försvarets radioanstalt (FRA)</em>. The adversary compromised an internal government workstation via a steganographic kitten image payload, collected classified records into an archive, and established a covert DNS Command & Control (C2) exfiltration channel directed at <code>cutekittenzz.xyz</code>.</p>

        <h4>2. Technical Investigation & Methodology</h4>
        <ul>
          <li><strong>Deep Packet Inspection:</strong> Analyzed raw PCAP capture using <code>Wireshark</code> and <code>tshark</code> filters. Isolated suspicious DNS traffic and quantified communication volumes.</li>
          <li><strong>Host Attribution:</strong> Confirmed victim workstation <code>10.0.0.10</code> was responsible for 99.93% of capture traffic, unwittingly utilizing corporate recursive resolver <code>10.0.0.20</code> as an exfiltration conduit.</li>
          <li><strong>Cryptographic Reverse Engineering:</strong> Deobfuscated exfiltrated payload fragments using <code>CyberChef</code>, reversing a 32-byte bitwise XOR repeating key and Base64 framing to reconstruct the stolen TAR archive.</li>
          <li><strong>Flag Extraction:</strong> Successfully recovered 3 forensic capture flags, including confidential government records (<code>topphemligt.pdf</code>).</li>
        </ul>

        <h4>3. Detection Engineering & Mitigations</h4>
        <ul>
          <li>Authored a production <strong>Sigma rule</strong> detecting high-frequency hex-encoded subdomains with regex pattern matching.</li>
          <li>Engineered <strong>Suricata IDS/IPS signatures</strong> inspecting DNS query length (> 60 bytes) and entropy thresholds.</li>
          <li>Implemented DNS sinkholing and Response Policy Zones (RPZ) to neutralize unauthorized recursive lookups.</li>
        </ul>
      `
    },
    'project-2': {
      title: 'AI-Assisted Vulnerability Root Cause Analysis (B.Sc. Thesis)',
      tag: 'B.Sc. Engineering Thesis / 111 Pages / Local AI & AppSec',
      pdfUrl: './02-llm-vulnerability-rca/BSc_Thesis_LLM_Vulnerability_RCA.pdf',
      githubUrl: 'https://github.com/MohamedSharmarkeSaid/cybersecurity-projects/tree/main/02-llm-vulnerability-rca',
      body: `
        <h4>1. Research Objective & Academic Scope</h4>
        <p>A comprehensive 111-page Bachelor of Science engineering thesis conducted at the <strong>University of Borås</strong>. The study evaluates the diagnostic precision, hallucination frequency, and enterprise safety of local, privacy-preserving Large Language Models (DeepSeek-Coder, CodeLlama, Llama-3, Mistral) in performing automated Static Application Security Testing (SAST) and Root Cause Analysis (RCA).</p>

        <h4>2. Experimental Methodology & Testbed</h4>
        <ul>
          <li><strong>Testbed:</strong> Deployed OWASP Juice Shop, targeting three critical vulnerability classes: SQL Injection (CWE-89), DOM-based Cross-Site Scripting (CWE-79), and Directory Listing / Path Traversal (CWE-548).</li>
          <li><strong>Comparative Architectures:</strong> Benchmarked 40 experimental runs across two paradigms: <em>Bounded Architectural Context</em> (direct full-function code ingestion) vs. <em>Naive Retrieval-Augmented Generation (RAG)</em> using ChromaDB vector store.</li>
          <li><strong>Privacy & Air-Gap Compliance:</strong> Zero telemetry sent to commercial cloud providers; 100% executed locally via LM Studio and Open WebUI APIs.</li>
        </ul>

        <h4>3. Key Empirical Discoveries</h4>
        <ul>
          <li><strong>Bounded Context Superiority:</strong> Bounded context achieved <strong>58.3% diagnostic accuracy</strong> compared to only <strong>31.7% for RAG</strong>.</li>
          <li><strong>Vulnerability Inversion Phenomenon:</strong> Uncovered that naive semantic chunking often detaches sanitization routines from source inputs, causing LLMs to hallucinate vulnerabilities where secure code patterns existed, or misclassify vulnerable sinks as safe.</li>
          <li><strong>Engineering Recommendations:</strong> Formulated concrete DevSecOps guidelines for safely integrating local AI models into CI/CD pipelines without data leakage or false-positive bloat.</li>
        </ul>
      `
    },
    'project-3': {
      title: 'IoT Security Assessment, SPAN Mirroring & VLAN Isolation',
      tag: 'IoT Security / Hardening / Cisco SPAN & ACLs',
      pdfUrl: './03-iot-security-assessment/IoT_Security_Assessment_Report.pdf',
      githubUrl: 'https://github.com/MohamedSharmarkeSaid/cybersecurity-projects/tree/main/03-iot-security-assessment',
      body: `
        <h4>1. Assessment Scope & Target Environment</h4>
        <p>A comprehensive penetration test and architectural hardening of a smart home ecosystem running <strong>Home Assistant</strong>, commercial IP cameras, smart sensors, and Tuya-based IoT microcontrollers.</p>

        <h4>2. Vulnerability Exploitation & Findings</h4>
        <ul>
          <li><strong>RTSP Video Stream Compromise:</strong> Identified an exposed Real-Time Streaming Protocol (RTSP) port 554. Discovered hardcoded default vendor credentials, enabling unauthenticated live video access in under <strong>78 seconds (CVSS 9.1 Critical)</strong>.</li>
          <li><strong>Unauthorized Cloud Telemetry:</strong> Configured <strong>Cisco SPAN (Port Mirroring)</strong> on hardware switches to inspect raw egress packets in Wireshark. Identified continuous unencrypted telemetry beacons transmitted to offshore AWS cloud endpoints without user consent.</li>
          <li><strong>MQTT Protocol Analysis:</strong> Analyzed plaintext MQTT pub/sub traffic leaking home telemetry and sensor state events across the local subnet.</li>
        </ul>

        <h4>3. Defense-in-Depth Remediation & Architecture</h4>
        <ul>
          <li>Engineered a robust <strong>3-VLAN segmentation architecture</strong> (VLAN 10: Trusted Management, VLAN 20: Isolated IoT, VLAN 30: End-User Clients).</li>
          <li>Applied <strong>Cisco Extended Access Control Lists (ACLs)</strong> restricting IoT devices from accessing RFC 1918 internal subnets and blocking all outbound WAN connectivity.</li>
          <li>Hardened Home Assistant reverse proxy and enforced TLS mutual authentication for local broker communications.</li>
        </ul>
      `
    },
    'project-4': {
      title: 'PowerShell Enterprise Infrastructure Automation & AD Hardening',
      tag: 'Systems Engineering / Infrastructure as Code / PowerShell 7',
      pdfUrl: './04-powershell-infrastructure-automation/HyperV_VM_Automation_Lab_Guide.pdf',
      githubUrl: 'https://github.com/MohamedSharmarkeSaid/cybersecurity-projects/tree/main/04-powershell-infrastructure-automation',
      body: `
        <h4>1. Project Scope & Enterprise Challenges</h4>
        <p>Developed a modular, production-ready PowerShell 7 and 5.1 automation suite to standardize identity lifecycle management, enforce CIS security benchmarks, eliminate configuration drift, and automate Generation 2 Hyper-V virtual infrastructure.</p>

        <h4>2. Delivered Script Modules</h4>
        <ul>
          <li><strong><code>Sync-ADUsersAndGroups.ps1</code>:</strong> Automates bulk CSV employee onboarding, group memberships, and role-based OU distribution. Automatically provisions departmental storage shares and strips inherited permissions using <code>icacls</code> to enforce strict Least-Privilege access controls.</li>
          <li><strong><code>Invoke-DHCPDeployment.ps1</code>:</strong> Automated Windows Server DHCP server authorization in Active Directory, dynamic scope provisioning, IP exclusion ranges, and MAC reservations.</li>
          <li><strong><code>Deploy-HyperV-VM.ps1</code>:</strong> Complete Infrastructure as Code (IaC) deployment for Generation 2 Hyper-V virtual machines, virtual switches, dynamic memory allocations, and multi-disk SCSI database storage arrays.</li>
        </ul>

        <h4>3. Enterprise Security Standards</h4>
        <ul>
          <li>Zero plaintext passwords or secrets in source code; parameterized credentials via <code>PSCredential</code>.</li>
          <li>Enforces CIS Windows Server security baselines and Principle of Least Privilege (PoLP).</li>
          <li>Comprehensive error handling (<code>try/catch</code>), verbose telemetry output, and structured logging.</li>
        </ul>
      `
    },
    'project-5': {
      title: 'Enterprise Dual-Campus Network Design & OPNsense UTM',
      tag: 'Network Architecture / Perimeter Security / Cisco IOS & OPNsense',
      pdfUrl: './05-enterprise-network-architecture/MultiSite_Enterprise_Network_Design.pdf',
      githubUrl: 'https://github.com/MohamedSharmarkeSaid/cybersecurity-projects/tree/main/05-enterprise-network-architecture',
      body: `
        <h4>1. Architectural Blueprint & Requirements</h4>
        <p>Engineered a redundant, multi-site enterprise infrastructure connecting <strong>Headquarters (HQ Borås)</strong> and a <strong>Branch Office (Göteborg)</strong> across a simulated Service Provider WAN with complete high availability and zero single points of failure.</p>

        <h4>2. Routing & Switching Implementation</h4>
        <ul>
          <li><strong>Dynamic Routing:</strong> Configured <code>OSPFv2 Area 0</code> across all core and distribution routers, establishing fast convergence and deterministic path selection.</li>
          <li><strong>Secure Inter-Campus Encapsulation:</strong> Established Point-to-Point <code>GRE (Generic Routing Encapsulation)</code> tunnels connecting HQ and Branch across public IP space.</li>
          <li><strong>Gateway Redundancy:</strong> Deployed <code>HSRP (Hot Standby Router Protocol)</code> on distribution switches to provide sub-second default gateway failover for end-user VLANs.</li>
          <li><strong>Layer 2 Segmentation:</strong> Implemented IEEE 802.1Q trunking, EtherChannel (LACP) link aggregation, and strict extended ACLs enforcing departmental security boundaries.</li>
        </ul>

        <h4>3. Next-Gen UTM Firewall (OPNsense)</h4>
        <ul>
          <li>Deployed an <strong>OPNsense Next-Gen Firewall</strong> as the perimeter security gateway.</li>
          <li>Configured <strong>Netmap-accelerated Inline Suricata IPS</strong> for real-time exploit and malware signature blocking.</li>
          <li>Implemented <strong>Squid Web Proxy</strong> with <strong>ClamAV / C-ICAP</strong> antivirus stream scanning and Unbound DNSBL malicious domain sinkholing.</li>
          <li>Configured <strong>OpenVPN Road Warrior</strong> gateway with multi-factor authentication for remote engineering staff.</li>
        </ul>
      `
    },
    'project-6': {
      title: 'Web Application Penetration Testing (OWASP WSTG v4.2)',
      tag: 'Web AppSec / Penetration Testing / 36-Page Formal Report',
      pdfUrl: './06-web-application-penetration-testing/Web_Application_Penetration_Testing_Report.pdf',
      githubUrl: 'https://github.com/MohamedSharmarkeSaid/cybersecurity-projects/tree/main/06-web-application-penetration-testing',
      body: `
        <h4>1. Target & Assessment Methodology</h4>
        <p>Conducted a formal, rigorous black-box and grey-box security assessment of <strong>Decidim</strong>, a leading open-source citizen participation platform built on <strong>Ruby on Rails 7, Puma web server, and PostgreSQL</strong>. The entire application was hosted in an isolated Hyper-V sandbox to ensure testing integrity.</p>

        <h4>2. OWASP WSTG v4.2 Test Matrix Execution</h4>
        <ul>
          <li>Executed <strong>36 comprehensive test cases</strong> spanning Information Gathering, Configuration & Deployment, Identity Management, Authentication, Authorization, Session Management, Data Validation, Error Handling, and Cryptography.</li>
          <li>Utilized <code>Burp Suite Professional/Community</code>, <code>SQLMap</code>, <code>XSStrike</code>, and custom curl payloads to systematically probe API endpoints and web interfaces.</li>
        </ul>

        <h4>3. Vulnerability Findings & Architecture Validation</h4>
        <ul>
          <li><strong>Puma Verbose Stack Trace Leakage (CWE-209):</strong> Discovered that unhandled exceptions on GraphQL endpoints leaked internal server paths, gem versions, and database schemas. Remediated by disabling verbose error modes in production configuration.</li>
          <li><strong>API Rate Limiting Gaps (CWE-799):</strong> Identified absence of throttling on authentication and comment submission endpoints, creating exposure to brute-force and resource exhaustion attacks.</li>
          <li><strong>Validated Defenses:</strong> Verified robust protection against SQL Injection and Cross-Site Scripting (XSS) due to Rails ActiveRecord parameterized queries and automated template escaping.</li>
          <li><strong>Audit Deliverables:</strong> Compiled a 36-page formal report containing an executive summary, CVSS risk ratings, step-by-step reproduction steps, and patch verification instructions.</li>
        </ul>
      `
    }
  };

  // 6. Modal Functions
  const modalOverlay = document.getElementById('projectModal');
  const modalClose = document.getElementById('modalClose');
  const modalTitle = document.getElementById('modalTitle');
  const modalTag = document.getElementById('modalTag');
  const modalBody = document.getElementById('modalBody');
  const modalFooter = document.getElementById('modalFooter');

  window.openModal = function(projectId) {
    const data = projectDetails[projectId];
    if (!data) return;

    modalTitle.innerText = data.title;
    modalTag.innerText = data.tag;
    modalBody.innerHTML = data.body;

    modalFooter.innerHTML = `
      <a href="${data.githubUrl}" target="_blank" rel="noopener noreferrer" class="btn btn-outline">
        <svg class="icon" viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/></svg>
        GitHub Folder
      </a>
      <a href="${data.pdfUrl}" target="_blank" rel="noopener noreferrer" class="btn btn-primary">
        <svg class="icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
        Download / Open PDF
      </a>
    `;

    modalOverlay.classList.add('open');
    modalOverlay.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
  };

  function closeModal() {
    if (modalOverlay) {
      modalOverlay.classList.remove('open');
      modalOverlay.setAttribute('aria-hidden', 'true');
      document.body.style.overflow = '';
    }
  }

  if (modalClose) {
    modalClose.addEventListener('click', closeModal);
  }

  if (modalOverlay) {
    modalOverlay.addEventListener('click', (e) => {
      if (e.target === modalOverlay) {
        closeModal();
      }
    });
  }

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && modalOverlay && modalOverlay.classList.contains('open')) {
      closeModal();
    }
  });

});
