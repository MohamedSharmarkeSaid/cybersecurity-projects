# Web Application Penetration Testing: OWASP WSTG Security Assessment

[![Assessment Standard](https://img.shields.io/badge/Standard-OWASP%20WSTG%20v4.2-orange.svg)](https://owasp.org/www-project-web-security-testing-guide/)
[![Target Platform](https://img.shields.io/badge/Target-Decidim%20(Ruby%20on%20Rails)-red.svg)](https://decidim.org/)
[![Application Server](https://img.shields.io/badge/Server-Puma%206.5.0%20%7C%20Ubuntu%2024.04-blue.svg)](https://puma.io/)
[![Environment](https://img.shields.io/badge/Environment-Hyper--V%20Private%20Switch%20Sandbox-green.svg)](.)
[![Primary Tools](https://img.shields.io/badge/Tools-Burp%20Suite%20%7C%20SQLMap%20%7C%20XSStrike%20%7C%20Gobuster-lightgrey.svg)](.)

---

## 1. Executive Summary & Assessment Scope

This technical evaluation documents an end-to-end web application penetration test executed by **Mohamed Said** against **Decidim**, an enterprise open-source participatory democracy web platform built on **Ruby on Rails** and the **Puma 6.5.0** application server.

The engagement adhered rigorously to the **OWASP Web Security Testing Guide (WSTG v4.2)**, systematically evaluating input validation, authentication integrity, session lifecycle, authorization boundaries, and server transport resilience within an isolated lab sandbox.

### 1.1 Testbed Architecture & Network Isolation

The assessment was executed entirely inside a secure virtualization boundary to ensure zero risk to external production infrastructure:
* **Target System**: Decidim Web Application (`192.168.50.10:3000`), hosted on Ubuntu Linux 24.04 LTS (Ruby 3.x via `rbenv`, Puma 6.5.0, OpenSSH 9.6p1).
* **Attacker System**: Kali Linux (`192.168.50.11`) equipped with offensive testing frameworks (Burp Suite, SQLMap, XSStrike, Gobuster, Nikto, Nmap).
* **Network Fabric**: Hyper-V Private Virtual Switch (`192.168.50.0/24`), completely isolating the virtual machines from host system adapters and external WAN transit.

---

## 2. Assessment Methodology & OWASP WSTG Test Coverage

| OWASP WSTG ID | Testing Domain | Tools Used | Key Observation & Result | Security Assessment |
|:---|:---|:---|:---|:---:|
| **WSTG-INFO-01** | Vulnerability Research | OSINT / Search Engines | Identified known public CVE disclosures and security advisories for Decidim dependencies. | Informational |
| **WSTG-INFO-02** | Web Server Fingerprinting | Nikto, Nmap (`-sV -p-`) | Fingerprinted Puma 6.5.0, Ruby on Rails, and OpenSSH 9.6p1. Identified lack of fronting reverse proxy. | Low |
| **WSTG-ERR-01** | Error Handling Analysis | Netcat (`nc`), cURL | Malformed HTTP request (`GET / GOLD ERROR/1.0`) triggered HTTP 400 with verbose Ruby/Puma stack trace leakage. | Medium |
| **WSTG-INFO-03** | Metafile & Config Leakage | cURL, Burp Site Map | Probed `robots.txt`, `sitemap.xml`, `.env`, `database.yml`, `Gemfile.lock`. All configuration files returned 403/404. | Pass |
| **WSTG-INFO-04** | Application Enumeration | Gobuster (`dir`) | Discovered `/system/admins/sign_in` administrative login portal. No unlinked or exposed sensitive directories found. | Pass |
| **WSTG-ATHN-01** | Transport Layer Security | Burp Suite Proxy | Captured plain HTTP POST authentication and password reset tokens in cleartext (due to lab-level HTTP operation). | Medium / Config |
| **WSTG-ATHN-03** | Account Lockout Mechanism | Burp Suite Intruder | Executed automated credential stuffing. No account lockout or throttling was enforced on repeated failed logins. | Medium |
| **WSTG-ATHN-04** | Authentication Bypass | Browser, cURL | Tested unauthenticated access to `/system` and post-logout navigation. Application enforced HTTP 302 redirects. | Pass |
| **WSTG-ATHZ-02** | Authorization & IDOR | cURL, Browser | Injected forged session cookies (`FAKESESSION123`); server rejected them. Tested `/users/1` and `/users/2` (no numeric ID routing). | Pass |
| **WSTG-SESS-01** | Session Management | Burp Suite, Browser | Verified session ID regeneration upon login (no session fixation). Verified `HttpOnly` and `SameSite=Lax` cookie flags. | Pass |
| **WSTG-INPV-01/02**| Cross-Site Scripting (XSS) | XSStrike, Burp Intruder | Fuzzed search parameters and comments with script payloads. Rails template auto-escaping neutralized all XSS vectors. | Pass |
| **WSTG-INPV-05** | SQL Injection (SQLi) | SQLMap (`--level 5`) | Automated testing against login parameters confirmed zero SQLi vulnerabilities; protected by ActiveRecord ORM. | Pass |
| **WSTG-INPV-07** | XML / Content Injection | Manual payloads | Tested HTML/JS injection strings in search queries; safely sanitized and rendered without script execution. | Pass |

---

## 3. Vulnerability Findings & Remediation Recommendations

| Finding ID | Vulnerability Description | Impact Rating | Remediation Strategy |
|:---|:---|:---:|:---|
| **VULN-WEB-01** | **Verbose Error Stack Trace Leakage (`WSTG-ERR-01`)**<br/>Malformed HTTP requests return full internal file paths, Ruby gem directories, and runtime versions. | **Medium** | Ensure Rails production configuration disables local debugging: set `config.consider_all_requests_local = false` and configure generic error response templates. |
| **VULN-WEB-02** | **Lack of Rate Limiting & Account Lockout (`WSTG-ATHN-03`)**<br/>Login endpoint allows unlimited automated password attempts, enabling credential stuffing. | **Medium** | Implement rate limiting using `Rack::Attack` or enable Devise `:lockable` strategy to lock accounts after 5 failed attempts with exponential backoff. |
| **VULN-WEB-03** | **Cleartext Transport Protocol (`WSTG-ATHN-01`)**<br/>Credentials and reset tokens transmitted over unencrypted HTTP (port 3000). | **Medium** | Deploy a TLS-terminating reverse proxy (Nginx / OPNsense) enforcing TLS 1.3, HTTP-to-HTTPS redirection, HSTS headers, and the cookie `Secure` flag. |

---

## 4. Deliverables & Artifacts

| Deliverable | Description | Format / Location |
|:---|:---|:---|
| **Web App Penetration Testing Report** | Complete 36-page formal testing dossier detailing OWASP WSTG methodology, command logs, Burp/SQLMap terminal captures, and remediation guidance. | [`Web_Application_Penetration_Testing_Report.pdf`](./Web_Application_Penetration_Testing_Report.pdf) (2.7 MB) |
