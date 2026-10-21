# Lab Journal

My notes from the Active Directory lab, October 16–20, 2026. Here I write down what I did, what went
wrong, and what I learned, in my own words. This lab is deliberate practice: in school I built an AD
environment in a group using Windows Server 2019 and Windows 10. Here I rebuilt the fundamentals on
my own with Windows Server 2025 and Windows 11.

At the end of each section there are **questions to review**. Cover the answer and try to answer in
your own words.

---

## 1. Network and virtual machines

**What I did**
I created everything by hand. An internal switch, `ADLabSwitch`, in Virtual Switch Manager. I gave
my laptop the address `10.10.50.1` on that switch adapter in `ncpa.cpl`, and turned on NAT with
`New-NetNat`. Then I created DC01 and CLIENT01 in Hyper-V Manager: Generation 2, static memory (2 GB
on DC01, 4 GB on CLIENT01), 2 processors, automatic checkpoints turned off, and Guest Services turned
on. CLIENT01 got TPM enabled.

**What went wrong**
- The lab originally used `192.168.50.0/24`, the exact same subnet as my home network, where the
  router is `192.168.50.1`. My laptop ended up with the router's IP address on the lab adapter, so
  the same subnet existed on two network cards. I spotted this in `ipconfig`, changed the lab
  network to `10.10.50.0/24`, and recreated the NAT.
- The lab adapter initially showed a `169.254` address because the static IP had not been set yet.
- DC01 was created with dynamic memory and 6 processors, and CLIENT01 was missing TPM. I caught both
  when verifying with `Get-VM` and fixed them in VM Settings.

**What I learned**
- I chose *Internal* because only my laptop and the VMs should reach the lab network, not the rest of
  my home network. *Private* would not have worked because the VMs would not be able to reach my
  laptop, which is what gives them internet access. *External* would have put the VMs straight on my
  home Wi-Fi.
- An address starting with `169.254` is an address Windows assigns to itself when no DHCP server
  answers. That is called APIPA.
- Two networks that are connected together cannot use the same IP range. Each network has its own
  gateway: VM → my laptop (`10.10.50.1`) → home router (`192.168.50.1`) → internet.
- My laptop has no default gateway configured on the lab adapter. It *is* the gateway for the lab,
  and it already has a default route out through the home router.
- Generation 2 boots with UEFI and supports Secure Boot and TPM, which is modern and more secure.
  Windows 11 requires TPM and therefore requires Generation 2.
- A domain controller should have static memory. With dynamic memory, Hyper-V can reclaim RAM from
  the VM, making AD and DNS slow.
- Never trust that a click was saved. Always verify.

**Questions to review**
- *What is the difference between Private, Internal, and External?* Private: only the VMs. Internal:
  the VMs and my host computer. External: also the physical home network.
- *What does `169.254` mean?* The machine did not get an address from a DHCP server.

---

## 2. Installing Windows

**What I did**
I installed Windows Server 2025 Standard Evaluation (Desktop Experience) on DC01 and Windows 11
Enterprise on CLIENT01, both from ISO files.

**What went wrong**
Windows 11 stopped at *Let's connect you to a network*. It was not a driver issue. The client had no
network connection yet because there is no DHCP server on the lab switch.

**What I learned**
- Server Core only has a command prompt, which is harder to navigate if you are not used to
  PowerShell. Core servers are usually managed remotely from another machine.
- Many companies run Core because it uses fewer resources, and above all because it is more secure:
  less code means a smaller attack surface and fewer updates and reboots.
- Inside a VM you press Ctrl+Alt+End. Regular Ctrl+Alt+Del is always intercepted by the physical
  host's Windows first and never reaches the VM. That applies to all VMs, not just Windows Server.
- Ctrl+Alt+Del is a *Secure Attention Sequence*. Regular programs cannot intercept it, so you know
  the sign-in screen is genuine. It protects against fake sign-in prompts, not bots.

**Questions to review**
- *Why did CLIENT01 have no network during setup?* There is no DHCP server on the switch, so it only
  got a `169.254` address.
- *Why press Ctrl+Alt+End?* Ctrl+Alt+Del never reaches the VM.

---

## 3. A static address for the server

**What I did**
I set a static IP by hand on DC01 in `ncpa.cpl`: `10.10.50.10/24`, gateway `10.10.50.1`, and DNS
`127.0.0.1`. I renamed the server to DC01 in `sysdm.cpl` and set the time zone to Stockholm.

**What happened**
`ping 10.10.50.1` did not reply, but `ping 1.1.1.1` did. Traffic to the internet goes through the
gateway, so the gateway clearly works. It is the Windows Firewall on my laptop that blocks incoming
ping on the lab adapter, because Windows classifies the lab network as an *Unidentified network* with
the *Public* firewall profile.

**What I learned**
- A DC needs a static IP because clients go to that address to authenticate with Kerberos, and they
  find it both through their DNS settings and the DNS records. If the IP changes, clients cannot find
  the domain.
- DC01 points to itself (`127.0.0.1`) for DNS because it will become the DNS server and AD writes its
  own records into that local DNS.
- The server name should be changed before promoting it to a DC, because the name gets written into
  AD, DNS, and Kerberos. In school we had to rename DC01 afterwards with `netdom`, which was a hassle.
- No reply to `ping` does not mean a machine is down. A firewall may simply be blocking ICMP.
- The Windows Firewall has three profiles: Domain (when joined to a domain), Private (trusted home or
  work network), and Public (untrusted network, strictest rules).
- The time zone only changes how the clock is displayed. The actual clock time is much more
  important: Kerberos allows at most a 5-minute difference between client and DC.

**Questions to review**
- *Why does DC01 point to `127.0.0.1`?* It is its own DNS server and holds the domain's DNS records.
- *Ping does not reply, but the internet works. Why?* The firewall blocks incoming ping to the host,
  but allows routed NAT traffic passing through.

---

## 4. Building the domain

**What I did**
I installed the Active Directory Domain Services role in Server Manager and promoted DC01 to a domain
controller in a new forest, `lab.internal` (NetBIOS `LAB`), with DNS and Global Catalog. I signed in
as `LAB\Administrator`, and `whoami` showed `lab\administrator`.

**What happened**
After the reboot, AD DS and DNS did not show up in Server Manager right away. Closing and reopening
Server Manager fixed it. The firewall already showed *Domain: On*, confirming that the server was in
the domain.

**What I learned**
- A forest can contain multiple domains. The forest is the outer security boundary, and all domains
  inside it share the schema and Global Catalog. A domain has its own users, computers, and policies.
  I have a single-domain forest, like most small and medium organizations.
- The DSRM password is used to repair AD if it breaks. The DC is booted into recovery mode where AD
  is offline, which is why DSRM uses a separate local password. Normal day-to-day administration is
  done as `LAB\Administrator`.
- Reverting a running DC to an old VM checkpoint wipes everything done after that point. The real
  danger is that the rest of the network has moved on: computers have rotated their machine account
  passwords, so they lose trust with the domain. With multiple DCs, AD also falls out of sync (USN
  rollback).
- The NetBIOS name `LAB` is the short legacy domain name (up to 15 characters) used in `LAB\username`.
- The summary page in the wizard has a *View script* button that shows the exact PowerShell command
  for the promotion. Everything in the GUI runs PowerShell under the hood.
- `SYSVOL` is the shared folder on the DC where GPO files are stored and replicated.

**Questions to review**
- *What is DSRM?* An emergency local password used to repair AD when AD is offline.
- *Forest vs. domain?* The forest is the outer security boundary; a domain is a unit inside it.

---

## 5. DNS

**What I did**
I added forwarders `1.1.1.1` and `8.8.8.8` in DNS Manager (DC01 > Properties > Forwarders) and
inspected the `_msdcs.lab.internal` zone.

**What happened**
`nslookup microsoft.com` already worked before adding forwarders thanks to *Root Hints*: DC01 queried
the internet's root servers on its own, though the first lookup took over 2 seconds (*DNS request
timed out*). With forwarders, the timeout disappeared. `Server: UnKnown` only happens because there
is no reverse lookup zone yet, and is harmless.

**What I learned**
- A forwarder is not a list of allowed domains. It is another DNS server that DC01 sends queries to
  when it cannot answer them itself. Queries for `lab.internal` are answered directly by DC01;
  everything else is forwarded.
- Forwarders make external lookups faster and more predictable. Root Hints stay as a fallback.
- The `_msdcs` zone contains SRV records that tell clients where the domain controllers are, such as
  `_ldap._tcp.dc._msdcs.lab.internal` and `_kerberos`, which point to `dc01.lab.internal`. A client
  joining the domain or signing in asks DNS for those records. That is why clients must use DC01 for
  DNS.

**Questions to review**
- *What is a forwarder?* Another DNS server that DC01 asks when it cannot answer a query itself.
- *What is inside `_msdcs`?* The SRV records that tell clients where the domain controller is.

---

## 6. OU structure

**What I did**
I created the OUs by hand in ADUC: `Lab` containing `Users` (IT, HR, Sales, Finance), `Groups`, and
`Computers`. Then I ran `redircmp "OU=Computers,OU=Lab,DC=lab,DC=internal"` so newly joined computers
land in `Lab\Computers`.

**What went wrong**
The first time, I accidentally created a computer account named "Computers" and a security group
named "Groups" instead of OUs, because I clicked *New > Computer* and *New > Group*. I noticed it in
the *Type* column, deleted both, and created OUs with *New > Organizational Unit*. An OU has a yellow
folder icon with a small book/card inside it.

**What I learned**
- Inside an OU, I control the objects and which policies apply to them. The built-in *Users* folder
  is a container, not an OU, and you cannot link GPOs to a container.
  Container = storage. OU = storage + GPO + delegation.
- Users do not land in the right OU automatically—the administrator chooses where each user account
  is created. Only new computers are redirected automatically, using `redircmp`.
- New computers should land in their own OU so I can apply GPOs to all workstations at once instead
  of one machine at a time.
- `redircmp` has no GUI equivalent. A Distinguished Name path is read backwards: the domain
  `lab.internal`, then the OU `Lab`, then the OU `Computers`.

**Questions to review**
- *Container vs. OU?* Only an OU can have GPOs linked to it.
- *What does `redircmp` do?* Sets the default OU where newly joined computers are placed.

---

## 7. Users

**What I did**
I created the department managers by hand (Anna, Maria, Peter, Karl) and then copied each manager to
create the second person in the same department (Sara, Johan, Emma, Sofia). I filled in *Title* and
*Department* on the *Organization* tab and added the *Job Title* and *Department* columns in ADUC
(*View > Add/Remove Columns*) so I could verify all eight users at once.

**What I learned**
- `LAB\anna.lindqvist` and `anna.lindqvist@lab.internal` point to the exact same account, just in
  different formats. The first (sAMAccountName) uses the NetBIOS name and comes from older Windows
  versions. The second (UPN) is newer and looks like an email address.
- Users should change their password at first logon. That way I can set a temporary initial password
  when creating accounts, and each person sets their own private password when they sign in. Only the
  user should know their password, so actions taken by that account can be tied to that person.
- When you copy a user in ADUC, role-related fields carry over: OU, department, company, manager,
  group memberships, and account flags. Personal fields do not carry over: name, username, password,
  job title, and email.

**Questions to review**
- *sAMAccountName vs. UPN?* `LAB\name` is the older format; `name@lab.internal` is the modern UPN.
- *What carries over when copying a user?* The role settings, not the personal details.

---

## 8. Groups and delegation

**What I did**
I created four groups in `Lab\Groups`: `GG_IT`, `GG_HR`, `GG_Sales`, and `GG_Finance` (Global,
Security), and added two users to each with *Add to a group...*. Using *Delegate Control...* on
`Lab\Users`, I gave `GG_IT` permission to reset user passwords and force password changes at next
logon. I verified it in *Advanced Security Settings*: `GG_IT` has *Reset password* on *Descendant
User objects*, meaning only on user accounts inside `Lab\Users`.

**What I learned**
- An OU is a folder for organizing objects, linking GPOs, and delegating administration. A group is
  used to grant permissions to a set of people, such as IT or HR. A user lives in a single OU (where
  they are), but can belong to many groups (what they are allowed to do).
- Least privilege means nobody gets more permissions than they need to do their job. Here, IT can
  only reset passwords, only on user accounts, and only inside `Lab\Users`. IT does not become Domain
  Admins and cannot reset the password of `Administrator`, which sits outside `Lab`.
- *Global* scope is used because we have a single domain and are grouping users from it. *Security*
  type is needed to assign permissions on folders, delegation, and GPO filters. *Distribution* groups
  are only for email lists.
- The `Everyone: Deny` delete entry on the OU comes from the *Protect object from accidental
  deletion* checkbox.
- Always grant permissions to groups, never directly to individual users. When someone new joins IT,
  you just add them to `GG_IT`.

**Questions to review**
- *OU vs. group?* An OU is where an object lives; a group is what permissions it gets.
- *Why Global and Security?* Grouping users from our own domain, and assigning permissions.

---

## 9. Group Policy

**What I did**
I configured the password policy (minimum 12 characters, complexity enabled) and account lockout
policy (5 failed attempts, 15-minute lockout) in Default Domain Policy. Then I created two separate
GPOs: *Lab - Lock Screen 10 min* (Computer Configuration, *Machine inactivity limit* = 600 seconds)
linked to `Lab\Computers`, and *Lab - Sales No Control Panel* (User Configuration, *Prohibit access
to Control Panel and PC settings*) linked to `Lab\Users\Sales`.

**What went wrong**
At first I put the screen lock inside Default Domain Policy. It would have worked, but it would have
applied to every computer in the domain, including DC01. I removed it from Default Domain Policy and
moved it into its own GPO linked to `Lab\Computers`.

**Experiment**
Once everything worked, I deliberately changed a few settings in Default Domain Policy to see if I
could spot them during troubleshooting: a shorter password length (7 characters), the Control Panel
policy set to *Disabled*, and the link set to *Enforced*. I found all of them right away on the
*Settings* tab in Group Policy Management.

**What I learned**
- It is the computer that locks its screen, so the screen lock sits under *Computer Configuration*.
  It is the user who is blocked from opening Control Panel, so that setting sits under *User
  Configuration*. Computer settings are applied when the machine boots; User settings are applied
  when the user logs in.
- The password policy affects all domain accounts. Password and lockout rules for domain users only
  work in a GPO linked to the domain root. Linked to an OU, they only affect local accounts on the
  workstations in that OU.
- Default Domain Policy applies to the entire `lab.internal` domain, so it should only hold account
  and password rules. Putting other rules there makes troubleshooting messy.
- *Not Configured* means the GPO makes no change. *Disabled* actively turns a setting off and can
  override another GPO. Normally the GPO closest to the object wins, unless a higher GPO is marked
  *Enforced*, which always wins.
- The *Settings* tab in Group Policy Management lists every setting configured in a GPO. It is the
  fastest way to audit or troubleshoot a GPO.

**Questions to review**
- *Computer vs. User Configuration?* Settings that apply to the machine vs. settings that follow the
  user.
- *Disabled vs. Not Configured?* Disabled actively turns the rule off; Not Configured leaves it
  alone.

---

## 10. Joining the client

**What I did**
CLIENT01 got the static IP `10.10.50.20` and gateway `10.10.50.1`. First, I tried joining the domain
with DNS set to `1.1.1.1`, on purpose. Then I changed DNS to DC01 (`10.10.50.10`), set the computer
name to CLIENT01, and joined the domain in `sysdm.cpl`: *"Welcome to the lab.internal domain."* I
signed in as `LAB\peter.svensson`. Running `gpresult /r` showed *Lab - Sales No Control Panel*, and
Control Panel was blocked.

**The error message with DNS `1.1.1.1`**

> The following error occurred when DNS was queried for the service location (SRV) resource
> record used to locate an Active Directory Domain Controller (AD DC) for domain "lab.internal":
> The error was: "This operation returned because the timeout period expired."
> (error code 0x000005B4 ERROR_TIMEOUT)
> The query was for the SRV record for _ldap._tcp.dc._msdcs.lab.internal

**What went wrong**
Domain users could not sign in while Hyper-V *Enhanced Session* was turned on. Enhanced Session
connects over Remote Desktop (RDP), and regular domain users are not allowed to log in through
Remote Desktop by default (only administrators and members of *Remote Desktop Users*). Turning off
Enhanced Session solved it immediately.

**What I learned**
- With DNS set to `1.1.1.1` (Cloudflare), the client queried Cloudflare for the SRV record
  `_ldap._tcp.dc._msdcs.lab.internal` to find a domain controller. Cloudflare does not know anything
  about `lab.internal`. Wrong DNS → no SRV record → no DC → no domain join. Kerberos only comes into
  play later, during authentication.
- Joining a computer to the domain creates a computer account in AD with its own machine password,
  which Windows rotates automatically. CLIENT01 landed straight in `Lab\Computers` instead of the
  built-in container thanks to `redircmp`, and immediately received the screen lock GPO.
- Always read the full error message. It named the exact SRV record I had inspected earlier in
  `_msdcs` and explained what to check.

**Questions to review**
- *Why did the domain join fail with `1.1.1.1`?* The client could not look up the SRV record, so it
  could not find the domain controller.
- *What is created in AD when a computer joins the domain?* A computer account.

---

## 11. Helpdesk support

**What I did**
I locked Emma's account by typing the wrong password five times, then unlocked it in ADUC. Next, I
installed the Active Directory management tools (RSAT) on CLIENT01, signed in as `LAB\sara.nilsson`
(IT), and reset Peter Svensson's password. When I tried to delete Peter's account while signed in as
Sara, Windows stopped me with *"You do not have sufficient privileges to delete Peter Svensson"*.

**What I learned**
- When a user cannot sign in, I troubleshoot in this order: network (`ping`), DNS (`nslookup`), the
  account itself (locked, disabled, expired, or wrong password), clock sync (at most 5 minutes of
  skew for Kerberos), and finally permissions and group policy (`gpresult`). The Enhanced Session
  issue belonged to that last step: the user lacked permission to sign in through Remote Desktop.
- Sara could reset Peter's password, but was blocked from deleting him. That is least privilege in
  practice: she has the exact permission needed for helpdesk tickets, and if her account is ever
  compromised, an attacker cannot use it to delete users.

**Questions to review**
- *What order do you troubleshoot logon issues in?* Network, DNS, account status, time sync,
  permissions and policy.
- *Why isn't Sara allowed to delete users?* Least privilege.
