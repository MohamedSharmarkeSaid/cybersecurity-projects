# Smart Home & IoT Security Assessment

A hands-on security assessment of a smart home environment that we built in the lab during the
course **Ethical Hacker, IoT and Cloud Services** (*Ethical Hacker, IoT och Molntjänster*). We set
up a consumer router, a Raspberry Pi 4 running Home Assistant OS, an IP surveillance camera, smart
plugs, LED strips, and environmental sensors, and then tested the network from a Kali Linux machine
connected to our Cisco switch.

The goal was to see what actually happens on the wire when you plug off-the-shelf smart home devices
into a flat network, test how hard it is for an attacker on the same LAN to hijack them, and design
a segmented network architecture that locks the devices down without breaking Home Assistant.

**Course:** Ethical Hacker, IoT and Cloud Services (Group IoT3, Lab Room D208, April 2025) ·
**Tools:** Kali Linux, Nmap, Wireshark, Cisco IOS (`SPAN` port mirroring), THC-Hydra, `ffplay`
(FFmpeg), Home Assistant OS · **Report:**
[`IoT_Security_Assessment_Report.pdf`](IoT_Security_Assessment_Report.pdf)

---

## Contents

- [What we built and tested](#what-we-built-and-tested)
- [Lab topology and hardware](#lab-topology-and-hardware)
- [Step by step](#step-by-step)
- [Findings and how to fix them](#findings-and-how-to-fix-them)
- [How we redesigned the network (VLAN segmentation)](#how-we-redesigned-the-network-vlan-segmentation)
- [The most important things I learned](#the-most-important-things-i-learned)
- [Files in this folder](#files-in-this-folder)

---

## What we built and tested

- Built a complete **smart home testbed** around an ASUS wireless router (`192.168.1.1`), a Cisco
  Catalyst switch (`SW_IOT3`), and a **Raspberry Pi 4** running **Home Assistant OS 2025.4.1**
- Connected five different IoT devices using Ethernet, Wi-Fi, MQTT, Tuya Cloud, and Bluetooth Low
  Energy (BLE)
- Configured **Cisco SPAN (Switched Port Analyzer)** on the Catalyst switch so our Kali machine on
  `Fa0/13` could capture unicast traffic going to and from the wired IP camera on `Fa0/4`
- Mapped every open port and service with **Nmap**, uncovering unencrypted RTSP (`554/tcp`), HTTP
  (`80/tcp`), ONVIF (`8000/tcp`), MQTT (`1883/tcp`), and Tuya local control (`6668/tcp`)
- Ran a dictionary attack with **THC-Hydra** against the Reolink camera's RTSP stream, cracking the
  admin password in **78 seconds** (`1,928` attempts, zero rate limiting) and opening the live video
  feed in `ffplay`
- Caught the "local" IP camera sending continuous **UDP packets (`58200/udp`) to an AWS EC2 server
  in Paris (`15.236.144.249`)**
- Designed a **3-VLAN network segmentation plan** and firewall rules to isolate the IoT devices from
  both the internet and the rest of the LAN

---

## Lab topology and hardware

```mermaid
flowchart LR
    Internet((Internet)) --- Router["ASUS RT-AC52U B1 Router<br/>192.168.1.1<br/>Firmware 3.0.0.4.380_10388"]
    Router --- SW["Cisco Catalyst Switch (SW_IOT3)<br/>SPAN: Fa0/4 -> Fa0/13"]

    subgraph Wired["Wired LAN (192.168.1.0/24)"]
        HA["Raspberry Pi 4<br/>Home Assistant OS 2025.4.1<br/>Ports: 8123, 1883 (MQTT)"]
        Cam["Reolink RLC-520A IP Camera<br/>Port Fa0/4<br/>Ports: 80, 554 (RTSP), 8000"]
        Kali["Kali Linux (Attacker)<br/>Port Fa0/13 (SPAN Destination)<br/>Nmap, Wireshark, Hydra, ffplay"]
    end

    subgraph Wireless["2.4 GHz Wi-Fi & BLE"]
        ShellyTH["Shelly H&T Sensor<br/>Wi-Fi / MQTT (1883)"]
        ShellyBLU["Shelly BLU Door/Window<br/>Bluetooth Low Energy"]
        NedisPlug["Nedis Smart Plug<br/>Wi-Fi (Tuya 6668/tcp)"]
        NedisLED["Nedis RGB LED Strip<br/>Wi-Fi (Tuya 6668/tcp)"]
    end

    SW --- HA
    SW --- Cam
    SW -. "Mirrored traffic (SPAN)" .-> Kali
    Router --- Wireless
    Cam -. "Unexpected UDP 58200<br/>cloud heartbeats" .-> AWS["AWS EC2 (eu-west-3 Paris)<br/>15.236.144.249"]
```

### Devices in our lab (`192.168.1.0/24`)

| Device | Connection | Open Ports / Protocols | Role in the lab |
|---|---|---|---|
| **ASUS RT-AC52U B1** | WAN / LAN / Wi-Fi | `53`, `80/tcp` (HTTP), `8443/tcp` | Gateway router (`192.168.1.1`), DHCP server, and 2.4 GHz Wi-Fi access point |
| **Cisco Catalyst (`SW_IOT3`)** | Wired Ethernet | Cisco IOS CLI | Layer 2 switch connecting wired devices and mirroring `Fa0/4` to `Fa0/13` |
| **Raspberry Pi 4 Model B** | Wired Ethernet | `8123/tcp` (HTTP), `1883/tcp` (Mosquitto MQTT), `111/tcp` | Local smart home controller running Home Assistant OS 2025.4.1 |
| **Reolink RLC-520A** | Wired Ethernet (`Fa0/4`) | `80/tcp` (HTTP), `554/tcp` (RTSP), `8000/tcp` (ONVIF), `58200/udp` | PoE/wired surveillance camera integrated into Home Assistant |
| **Shelly H&T Gen3** | 2.4 GHz Wi-Fi | `80/tcp` (Web UI), `1883/tcp` (MQTT client) | Temperature and humidity sensor publishing telemetry over MQTT |
| **Shelly BLU Door/Window** | Bluetooth (BLE) | BLE advertisements | Window/door contact sensor paired via Bluetooth |
| **Nedis Smart Plug & LED Strip** | 2.4 GHz Wi-Fi | `6668/tcp` (Tuya local protocol) + Tuya Cloud | Wi-Fi power plug and RGB light strip controlled via Tuya integration |

---

## Step by step

### 1. Setting up the smart home and discovering the switch blind spot

We first set up the lab the way a normal home user would: we plugged the Raspberry Pi 4 and the
Reolink camera into the switch, connected the wireless sensors and Nedis devices to the ASUS router's
Wi-Fi, and added everything into Home Assistant.

When we opened Wireshark on our Kali Linux laptop (plugged into switch port `Fa0/13`), we immediately
hit a classic networking reality: we could only see broadcast traffic (ARP, DHCP, mDNS) and traffic
sent directly to our own laptop. We could not see any of the camera's video traffic or cloud
connections.

To fix that, we logged into the Cisco switch (`SW_IOT3`) over serial console and configured **SPAN
(port mirroring)** so every packet entering or leaving the camera's port (`Fa0/4`) was copied to our
Kali port (`Fa0/13`):

```ios
SW_IOT3# configure terminal
SW_IOT3(config)# monitor session 1 source interface FastEthernet0/4
SW_IOT3(config)# monitor session 1 destination interface FastEthernet0/13
SW_IOT3(config)# end
SW_IOT3# show monitor session 1
```

**What I learned**
- A network switch is not a hub. It learns MAC addresses in its CAM table and only forwards unicast
  frames between the two ports involved in the conversation.
- If you want to inspect traffic from a wired IoT device with Wireshark (or an IDS like Suricata),
  you either need **SPAN port mirroring** on the switch, a physical network tap, or an inline
  gateway.

### 2. Scanning the network with Nmap

With all devices online, we ran service and OS discovery scans across `192.168.1.0/24`:

```bash
nmap -sS -sV -O -p- 192.168.1.0/24
```

The scan gave us a clear picture of the attack surface:
- The **Reolink camera** had ports `80/tcp` (HTTP admin page), `554/tcp` (RTSP video stream), and
  `8000/tcp` (ONVIF management) wide open.
- The **Raspberry Pi (Home Assistant)** had `8123/tcp` (web UI), `1883/tcp` (plaintext MQTT broker),
  and `111/tcp` (`rpcbind`) open.
- The **Nedis smart plug and LED strip** had `6668/tcp` open (the standard Tuya local control port)
  and required a cloud developer account to integrate with Home Assistant.
- The **ASUS router (`192.168.1.1`)** exposed its administration login over plain HTTP (`80/tcp`)
  and was running outdated 380-branch firmware (`3.0.0.4.380_10388`).

**What I learned**
- Almost every service on a default consumer IoT network runs **unencrypted** (`HTTP` on 80/8123,
  `RTSP` on 554, `MQTT` on 1883). Anyone who gets onto the same Wi-Fi network can read credentials,
  sensor states, and video streams in cleartext.

### 3. Brute-forcing the IP camera's RTSP stream (`554/tcp`)

Next, we tested whether the Reolink camera protected its live video stream (`rtsp://192.168.1.x:554/h264Preview_01_main`)
against password guessing. We ran **THC-Hydra** against port `554` using the `admin` account and the
`rockyou.txt` wordlist:

```bash
hydra -l admin -P /usr/share/wordlists/rockyou.txt -t 4 -V rtsp://192.168.1.x:554/h264Preview_01_main
```

The camera did not slow down responses, block our IP, or lock the account. Hydra tested **1,928
passwords in 1 minute and 18 seconds** (~25 attempts per second) and found the password
(`Pa55w0rd`). We immediately verified the credential by opening the live camera feed directly from
Kali using `ffplay`:

```bash
ffplay rtsp://admin:Pa55w0rd@192.168.1.x:554/h264Preview_01_main
```

**What I learned**
- Embedded IoT services like RTSP daemons often lack the brute-force protections that web login
  forms have. Even if the web UI on port 80 had a lockout timer, the RTSP server on port 554 allowed
  25 password guesses per second without restriction.
- Once an attacker has the RTSP credentials, they can watch the live camera feed silently without
  ever logging into Home Assistant.

### 4. Catching the camera talking to AWS in Paris (`58200/udp`)

While watching the mirrored traffic from `Fa0/4` in Wireshark, we noticed something we had not
configured: even though the Reolink camera was only set up for local RTSP streaming inside Home
Assistant, it was constantly sending UDP packets (`58200/udp`) out to the internet.

Looking up the destination IP (`15.236.144.249`) showed an **Amazon Web Services (AWS EC2) server in
the `eu-west-3` (Paris) region**.

**What I learned**
- Many consumer cameras keep a permanent **UDP hole-punching / P2P heartbeat** open to the vendor's
  cloud servers so their mobile app can connect from outside the home without port forwarding.
- Even if you only plan to use an IP camera locally in Home Assistant, it will still phone home to
  external cloud servers unless you explicitly block its outbound internet access in the firewall.

### 5. Inspecting MQTT, Tuya cloud dependencies, and Wi-Fi onboarding

We also looked at how the sensors and smart plugs communicated across the network:
- **Plaintext MQTT (`1883/tcp`):** The Shelly H&T sensor published temperature and humidity readings
  to the Mosquitto broker on port `1883` without TLS. In Wireshark we could read the MQTT topic paths
  and JSON payloads in plain text.
- **Cleartext Wi-Fi onboarding:** During initial setup, the Wi-Fi smart devices broadcast open setup
  access points (`Shelly...`) and receive the home Wi-Fi SSID and WPA2 password over unencrypted
  HTTP (`192.168.33.1`).
- **Tuya Cloud dependency (`6668/tcp`):** Unlike the Shelly sensor (which worked 100% locally), the
  Nedis smart plug and LED strip required registering a Tuya IoT Platform cloud account just to get
  the device keys, tying local smart home control to an external cloud API.

---

## Findings and how to fix them

| Finding | Severity | Cause | How to fix it |
|---|---|---|---|
| **RTSP camera password cracked in 78 seconds** | **Critical** | Port `554/tcp` has no rate limiting or lockout after failed logins (`1,928` attempts in 78s) | Set a long random password, disable RTSP/ONVIF if unused, and block workstations/guests from reaching port `554` directly (only allow Home Assistant's IP) |
| **Plaintext management & telemetry (`HTTP`, `MQTT`, `RTSP`)** | **High** | Router UI (`80/tcp`), Home Assistant (`8123/tcp`), and MQTT (`1883/tcp`) run without TLS | Enable HTTPS/TLS on the router and Home Assistant, and switch Mosquitto from port `1883` to **MQTTS (`8883/tcp`)** with username/password ACLs |
| **Outdated router firmware (`3.0.0.4.380_10388`)** | **High** | The ASUS RT-AC52U B1 was running legacy 380-series firmware with known CVEs | Upgrade firmware immediately, disable WAN management, UPnP, and WPS |
| **Unwanted UDP cloud traffic from the camera (`15.236.144.249`)** | **Medium** | Reolink P2P/UID feature phones home to AWS Paris over `58200/udp` by default | Turn off UID/P2P in the camera settings and block the camera's IP from reaching the internet at the firewall |
| **Flat network (`192.168.1.0/24`)** | **Medium** | Laptops, phones, Home Assistant, and cheap IoT devices all sit in the same subnet | Split the network into separate VLANs so a compromised smart plug or guest phone cannot reach the camera or Home Assistant |

---

## How we redesigned the network (VLAN segmentation)

To fix the flat network problem, we designed a segmented architecture using three VLANs on the
switch and firewall rules on the gateway:

```mermaid
flowchart TB
    FW["Firewall / Router Gateway"]

    subgraph VLAN10["VLAN 10: MGMT_CORE (10.10.10.0/24)"]
        HA2["Home Assistant OS (10.10.10.10)<br/>MQTTS (8883/tcp) + HTTPS (8123/tcp)"]
    end

    subgraph VLAN20["VLAN 20: IOT_UNTRUSTED (10.10.20.0/24)"]
        Cam2["Reolink Camera (10.10.20.20)<br/>No Internet Access"]
        Sensors["Shelly & Nedis Devices<br/>Isolated from LAN"]
    end

    subgraph VLAN30["VLAN 30: USER_GUEST (10.10.30.0/24)"]
        Laptops["User Laptops & Phones<br/>Can reach HA HTTPS (8123) only"]
    end

    FW --- VLAN10
    FW --- VLAN20
    FW --- VLAN30

    HA2 -- "Allowed: Pull RTSP (554/tcp)" --> Cam2
    Sensors -- "Allowed: Push MQTTS (8883/tcp)" --> HA2
    Laptops -- "Allowed: HTTPS (8123/tcp)" --> HA2
```

### Firewall rules between the VLANs

| Source | Destination | Port / Protocol | Action | Why |
|---|---|---|---|---|
| `VLAN 10` (Home Assistant `10.10.10.10`) | `VLAN 20` (Camera `10.10.20.20`) | `554/tcp` (RTSP), `8000/tcp` | **ALLOW** | Lets Home Assistant pull the video stream from the camera |
| `VLAN 20` (Sensors) | `VLAN 10` (Home Assistant `10.10.10.10`) | `8883/tcp` (MQTTS) | **ALLOW** | Lets sensors publish encrypted MQTT data to the broker |
| `VLAN 20` (`IOT_UNTRUSTED`) | `VLAN 10` / `VLAN 30` (Any) | Any | **DENY** | Stops a compromised IoT device from attacking computers or Home Assistant |
| `VLAN 20` (Camera `10.10.20.20`) | `WAN / Internet` | Any (`58200/udp`, etc.) | **DENY** | Completely stops the camera from phoning home to AWS |
| `VLAN 30` (Users) | `VLAN 10` (Home Assistant `10.10.10.10`) | `8123/tcp` (HTTPS) | **ALLOW** | Users view cameras and switches *through* Home Assistant, never by connecting directly to IoT devices |

---

## The most important things I learned

- **Never trust an IoT device to be "local only" without checking the packets.** Setting up the
  Cisco SPAN port and seeing the Reolink camera constantly send UDP packets to an AWS server in Paris
  was a great reminder that you only know what a device does when you look at the wire.
- **A flat home or office LAN is a gift to an attacker.** As soon as our Kali machine was on the
  same subnet as the camera, it took 78 seconds for Hydra to brute-force the RTSP password and pull
  up the live video feed. Putting cameras on an isolated VLAN where only Home Assistant can talk to
  port 554 stops that completely.
- **Prefer local-first devices over cloud-tethered ones.** Devices that support local MQTT/MQTTS
  (like Shelly) can run in a completely offline VLAN, whereas cloud-dependent devices (like Tuya)
  force you to punch holes to external servers just to turn on a lamp.

---

## Files in this folder

```
03-iot-security-assessment/
├── README.md                                <- This overview
└── IoT_Security_Assessment_Report.pdf       <- Full Swedish lab report with Wireshark, Nmap & Hydra screenshots
```
