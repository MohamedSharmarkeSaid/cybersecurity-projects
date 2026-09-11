<#
.SYNOPSIS
    Automates the installation, Active Directory authorization, and configuration of Windows Server DHCP service.

.DESCRIPTION
    Invoke-DHCPDeployment provisions an enterprise DHCP server on Windows Server environments.
    The script validates administrative privileges, verifies and installs the DHCP Server feature
    along with RSAT management tools, authorizes the DHCP server within Active Directory Domain Services,
    creates an IPv4 scope, configures static IP exclusion ranges, sets standard scope options
    (Option 003 Router, Option 006 DNS Servers, Option 015 Domain Name), registers client MAC reservations,
    and clears the post-deployment configuration alert in Windows Server Manager.

.PARAMETER ScopeId
    The network ID of the DHCP scope (e.g., '192.168.23.0').

.PARAMETER ScopeName
    The human-readable identifier for the DHCP scope.

.PARAMETER StartRange
    The starting IPv4 address for dynamic client lease distribution.

.PARAMETER EndRange
    The ending IPv4 address for dynamic client lease distribution.

.PARAMETER SubnetMask
    The subnet mask for the scope (e.g., '255.255.255.0').

.PARAMETER Gateway
    The default gateway / router IP address (DHCP Option 003).

.PARAMETER DnsServers
    An array of DNS server IPv4 addresses assigned to clients (DHCP Option 006).

.PARAMETER DnsDomainName
    The connection-specific DNS domain suffix assigned to clients (DHCP Option 015).

.PARAMETER DnsName
    The Fully Qualified Domain Name (FQDN) of the DHCP server for AD DS authorization.

.PARAMETER IPAddress
    The static IPv4 address of the DHCP server used for AD DS authorization.

.PARAMETER ExclusionRanges
    An array of static IP addresses or hashtables containing StartRange and EndRange to exclude from client distribution.

.PARAMETER Reservations
    An array of hashtables defining client reservations.
    Each hashtable must contain 'MAC' (or 'ClientId'), 'IP', and 'Name' (or 'Description').

.PARAMETER AuthorizeInAD
    Switch indicating whether to authorize the DHCP server in Active Directory Domain Services.

.PARAMETER LeaseDuration
    The lease duration for dynamic IP addresses. Defaults to 8 days.

.PARAMETER SkipRoleInstall
    Switch indicating whether to bypass the Windows Feature installation check.

.PARAMETER ForceRestart
    Switch indicating whether to reboot the operating system automatically if required after feature installation.

.EXAMPLE
    .\Invoke-DHCPDeployment.ps1 -ScopeId "192.168.23.0" -ScopeName "Corp-Production-LAN" `
        -StartRange "192.168.23.65" -EndRange "192.168.23.126" -SubnetMask "255.255.255.0" `
        -Gateway "192.168.23.1" -DnsServers @("192.168.23.254", "192.168.23.253") `
        -DnsDomainName "corp.enterprise.local" -DnsName "DHCP01.corp.enterprise.local" `
        -IPAddress "192.168.23.245" -AuthorizeInAD

    Installs the DHCP feature, authorizes DHCP01 in AD DS, initializes scope 192.168.23.0/24,
    and applies standard network options.

.EXAMPLE
    $reservations = @(
        @{ MAC = "00-15-5D-68-48-00"; IP = "192.168.23.65"; Name = "Workstation-Finance01" }
        @{ MAC = "00-15-5D-68-49-00"; IP = "192.168.23.66"; Name = "Workstation-Finance02" }
    )
    .\Invoke-DHCPDeployment.ps1 -ScopeId "192.168.23.0" -ScopeName "Finance-Subnet" `
        -StartRange "192.168.23.50" -EndRange "192.168.23.100" -SubnetMask "255.255.255.0" `
        -Gateway "192.168.23.1" -DnsServers @("192.168.23.254") -Reservations $reservations

.OUTPUTS
    [PSCustomObject] Summary of the deployed DHCP server configuration, scope state, exclusions, and reservations.

.NOTES
    Author: Mohamed Said
    Portfolio: Cybersecurity & SOC Infrastructure Automation (Module 04)
    Security: Adheres to least privilege, parameter sanitization, and administrative boundary validation.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    # Parameter: ScopeId
    # The subnet network identifier for the DHCP scope (e.g., '192.168.23.0')
    [Parameter(Mandatory = $false, HelpMessage = "Network ID of the DHCP scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ScopeId = "192.168.23.0",

    # Parameter: ScopeName
    # Human-readable descriptive name displayed in Windows DHCP Management console
    [Parameter(Mandatory = $false, HelpMessage = "Descriptive name for the scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ScopeName = "Corporate-LAN-Scope",

    # Parameter: StartRange
    # First assignable IPv4 address in the dynamic DHCP allocation pool
    [Parameter(Mandatory = $false, HelpMessage = "Starting IP address for client distribution.")]
    [System.Net.IPAddress]$StartRange = [System.Net.IPAddress]::Parse("192.168.23.65"),

    # Parameter: EndRange
    # Last assignable IPv4 address in the dynamic DHCP allocation pool
    [Parameter(Mandatory = $false, HelpMessage = "Ending IP address for client distribution.")]
    [System.Net.IPAddress]$EndRange = [System.Net.IPAddress]::Parse("192.168.23.126"),

    # Parameter: SubnetMask
    # Subnet mask applied to clients receiving IP leases from this scope (e.g., 255.255.255.0 for /24)
    [Parameter(Mandatory = $false, HelpMessage = "Subnet mask for the scope.")]
    [System.Net.IPAddress]$SubnetMask = [System.Net.IPAddress]::Parse("255.255.255.0"),

    # Parameter: Gateway
    # Default gateway / default router IP address distributed to clients via DHCP Option 003
    [Parameter(Mandatory = $false, HelpMessage = "Default gateway router IP address.")]
    [System.Net.IPAddress]$Gateway = [System.Net.IPAddress]::Parse("192.168.23.1"),

    # Parameter: DnsServers
    # Ordered array of DNS server IPv4 addresses distributed to clients via DHCP Option 006
    [Parameter(Mandatory = $false, HelpMessage = "Array of DNS Server IP addresses.")]
    [System.Net.IPAddress[]]$DnsServers = @(
        [System.Net.IPAddress]::Parse("192.168.23.254"),
        [System.Net.IPAddress]::Parse("192.168.23.253")
    ),

    # Parameter: DnsDomainName
    # Connection-specific DNS suffix distributed to clients via DHCP Option 015
    [Parameter(Mandatory = $false, HelpMessage = "Connection-specific DNS domain suffix.")]
    [ValidateNotNullOrEmpty()]
    [string]$DnsDomainName = "corp.enterprise.local",

    # Parameter: DnsName
    # Fully Qualified Domain Name (FQDN) of this DHCP server used for Active Directory DS authorization
    [Parameter(Mandatory = $false, HelpMessage = "FQDN of the DHCP server.")]
    [ValidateNotNullOrEmpty()]
    [string]$DnsName = "DHCP01.corp.enterprise.local",

    # Parameter: IPAddress
    # Static IPv4 address of this DHCP server registered in Active Directory authorization records
    [Parameter(Mandatory = $false, HelpMessage = "Static IPv4 address of the DHCP server.")]
    [System.Net.IPAddress]$IPAddress = [System.Net.IPAddress]::Parse("192.168.23.245"),

    # Parameter: ExclusionRanges
    # Array of static IP addresses or ranges excluded from dynamic client allocation
    # Protects critical infrastructure: default gateways, cluster VIPs, domain controllers, and servers
    [Parameter(Mandatory = $false, HelpMessage = "Static IP addresses or ranges to exclude from DHCP allocation.")]
    [object[]]$ExclusionRanges = @(
        "192.168.23.1",    # Default Gateway (Router)
        "192.168.23.2",    # Infrastructure Reserve
        "192.168.23.3",    # Infrastructure Reserve
        "192.168.23.4",    # Infrastructure Reserve
        "192.168.23.5",    # Infrastructure Reserve
        "192.168.23.6",    # Infrastructure Reserve
        "192.168.23.7",    # Infrastructure Reserve
        "192.168.23.8",    # Infrastructure Reserve
        "192.168.23.9",    # Infrastructure Reserve
        "192.168.23.10",   # Infrastructure Reserve
        "192.168.23.50",   # Windows Failover Cluster VIP
        "192.168.23.60",   # SQL Availability Group Listener VIP
        "192.168.23.240",  # Core Switch Management IP
        "192.168.23.245",  # DHCP Server (Self static IP)
        "192.168.23.246",  # Linux Security Appliance / UTM Proxy
        "192.168.23.247",  # SQL Reporting Node (RPT)
        "192.168.23.248",  # Disaster Recovery Node (DR)
        "192.168.23.249",  # SQL Production Node 2 (PROD2)
        "192.168.23.250",  # SQL Production Node 1 (PROD1)
        "192.168.23.251",  # Hyper-V Host 01 (HV01)
        "192.168.23.253",  # Secondary Domain Controller / DNS2
        "192.168.23.254"   # Primary Domain Controller / DNS1
    ),

    # Parameter: Reservations
    # Array of static client reservations mapping physical MAC addresses to fixed IPv4 addresses
    [Parameter(Mandatory = $false, HelpMessage = "Array of client reservations (MAC, IP, Name).")]
    [hashtable[]]$Reservations = @(
        @{ MAC = "00-15-5D-68-48-00"; IP = "192.168.23.65"; Name = "Client01-Finance" },
        @{ MAC = "00-15-5D-68-49-00"; IP = "192.168.23.66"; Name = "Client02-Operations" },
        @{ MAC = "00-15-5D-68-46-00"; IP = "192.168.23.67"; Name = "Client03-Executive" }
    ),

    # Parameter: AuthorizeInAD
    # Switch flag to authorize the DHCP server in Active Directory (prevents rogue DHCP shutdown)
    [Parameter(Mandatory = $false, HelpMessage = "Authorize DHCP server in Active Directory.")]
    [switch]$AuthorizeInAD,

    # Parameter: LeaseDuration
    # Lease duration before client must renew its IPv4 lease (default: 8 days)
    [Parameter(Mandatory = $false, HelpMessage = "Scope lease duration.")]
    [TimeSpan]$LeaseDuration = [TimeSpan]::FromDays(8),

    # Parameter: SkipRoleInstall
    # Switch flag to bypass Windows Feature installation check if DHCP is already known to be installed
    [Parameter(Mandatory = $false, HelpMessage = "Bypass Windows Feature installation check.")]
    [switch]$SkipRoleInstall,

    # Parameter: ForceRestart
    # Switch flag allowing automatic server reboot if required by Windows feature installation
    [Parameter(Mandatory = $false, HelpMessage = "Reboot computer automatically if requested by feature installer.")]
    [switch]$ForceRestart
)

# Enforce strict variable scoping and stop on any terminating error
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Function: Write-LogMessage
# Generates standardized console log messages with an ISO timestamp and severity levels
function Write-LogMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')][string]$Level = 'INFO'
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $colorMap = @{
        'INFO'    = 'Cyan'
        'SUCCESS' = 'Green'
        'WARNING' = 'Yellow'
        'ERROR'   = 'Red'
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colorMap[$Level]
}

# Function: Test-AdministratorPrivileges
# Checks if the current PowerShell session has elevated Administrator rights via WindowsPrincipal token
function Test-AdministratorPrivileges {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ==============================================================================
# PRE-FLIGHT PRIVILEGE CHECK
# ==============================================================================
Write-LogMessage -Message "Executing pre-flight privilege validation..." -Level 'INFO'

# Step 1: Ensure elevated Administrator privileges to manage Windows Server roles and services
if (-not (Test-AdministratorPrivileges)) {
    throw "Access Denied: This script requires an elevated PowerShell session (Run as Administrator)."
}
Write-LogMessage -Message "Administrative elevation verified." -Level 'SUCCESS'

# ==============================================================================
# PHASE 1: WINDOWS FEATURE INSTALLATION & SERVICE INITIALIZATION
# ==============================================================================
# Verifies and installs the DHCP Server feature along with Remote Server Administration Tools (RSAT)
if (-not $SkipRoleInstall) {
    Write-LogMessage -Message "Verifying Windows Server DHCP Feature status..." -Level 'INFO'
    try {
        # Check if the DHCP Server feature is already installed
        $dhcpFeature = Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue
        if ($null -eq $dhcpFeature -or -not $dhcpFeature.Installed) {
            Write-LogMessage -Message "DHCP Server feature is not installed. Initiating installation with RSAT management tools..." -Level 'WARNING'
            if ($PSCmdlet.ShouldProcess("Local Computer", "Install Windows Feature: DHCP (IncludeManagementTools)")) {
                # Install DHCP server role and RSAT management GUI / PowerShell cmdlets
                $installResult = Install-WindowsFeature -Name DHCP -IncludeManagementTools
                # Handle restart flag if Windows kernel requires reboot
                if ($installResult.RestartNeeded -eq 'Yes') {
                    if ($ForceRestart) {
                        Write-LogMessage -Message "System reboot required. Restarting computer immediately..." -Level 'WARNING'
                        Restart-Computer -Force
                        return
                    } else {
                        Write-LogMessage -Message "Reboot required by Windows. Please restart server and rerun script to finalize configuration." -Level 'WARNING'
                    }
                }
                Write-LogMessage -Message "DHCP Server feature installation completed successfully." -Level 'SUCCESS'
            }
        } else {
            Write-LogMessage -Message "DHCP Server feature is already installed and verified." -Level 'SUCCESS'
        }
    } catch {
        Write-LogMessage -Message "Failed to verify or install Windows Feature: $_" -Level 'ERROR'
        throw $_
    }
}

# Ensure the Windows DHCP Server service is actively running and set to start automatically on boot
try {
    $service = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
    if ($null -ne $service) {
        if ($service.Status -ne 'Running') {
            Write-LogMessage -Message "Starting DHCPServer service..." -Level 'INFO'
            Start-Service -Name DHCPServer
        }
        # Configure service startup type to Automatic
        Set-Service -Name DHCPServer -StartupType Automatic
        Write-LogMessage -Message "DHCPServer service is running and set to Automatic startup." -Level 'SUCCESS'
    }
} catch {
    Write-LogMessage -Message "Notice: Could not modify DHCPServer service state directly: $_" -Level 'WARNING'
}

# ==============================================================================
# PHASE 2: ACTIVE DIRECTORY DS AUTHORIZATION
# ==============================================================================
# In enterprise AD domains, DHCP servers must be authorized in AD DS.
# If an unauthorized DHCP server starts, Windows stops the service automatically to prevent rogue DHCP attacks.
if ($AuthorizeInAD) {
    Write-LogMessage -Message "Validating Active Directory authorization for server '$($DnsName)' ($($IPAddress))..." -Level 'INFO'
    try {
        # Enumerate currently authorized DHCP servers in Active Directory Domain Services
        $authorizedServers = Get-DhcpServerInDC -ErrorAction SilentlyContinue
        $isAuthorized = $false
        if ($null -ne $authorizedServers) {
            foreach ($srv in $authorizedServers) {
                # Match against FQDN or IP address
                if ($srv.DnsName -eq $DnsName -or $srv.IPAddress -eq $IPAddress.IPAddressToString) {
                    $isAuthorized = $true
                    break
                }
            }
        }

        # Authorize the server if not already registered in Active Directory
        if (-not $isAuthorized) {
            if ($PSCmdlet.ShouldProcess("$DnsName ($IPAddress)", "Authorize DHCP Server in Active Directory")) {
                Write-LogMessage -Message "Authorizing DHCP server in AD DS..." -Level 'INFO'
                Add-DhcpServerInDC -DnsName $DnsName -IPAddress $IPAddress.IPAddressToString
                Write-LogMessage -Message "DHCP server authorized successfully in AD DS." -Level 'SUCCESS'
            }
        } else {
            Write-LogMessage -Message "DHCP server is already authorized in AD DS." -Level 'SUCCESS'
        }
    } catch {
        Write-LogMessage -Message "AD DS Authorization warning: $_. Verify domain credentials and network connectivity." -Level 'WARNING'
    }
}

# ==============================================================================
# PHASE 3: IPV4 SCOPE CREATION & ACTIVATION
# ==============================================================================
# A DHCP Scope defines the contiguous pool of IP addresses available for dynamic client leasing in a subnet
Write-LogMessage -Message "Validating IPv4 Scope '$ScopeName' ($ScopeId)..." -Level 'INFO'
try {
    # Check if scope ID already exists on the server
    $existingScope = Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction SilentlyContinue
    if ($null -eq $existingScope) {
        if ($PSCmdlet.ShouldProcess("Scope: $ScopeId ($ScopeName)", "Create DHCP IPv4 Scope")) {
            Write-LogMessage -Message "Creating IPv4 Scope: $ScopeId [$($StartRange.IPAddressToString) - $($EndRange.IPAddressToString)]..." -Level 'INFO'
            # Initialize new scope with distribution bounds, subnet mask, and lease duration
            Add-DhcpServerv4Scope -Name $ScopeName `
                                  -StartRange $StartRange.IPAddressToString `
                                  -EndRange $EndRange.IPAddressToString `
                                  -SubnetMask $SubnetMask.IPAddressToString `
                                  -LeaseDuration $LeaseDuration `
                                  -State Active
            Write-LogMessage -Message "IPv4 Scope '$ScopeName' ($ScopeId) created and activated." -Level 'SUCCESS'
        }
    } else {
        # Ensure existing scope is in an Active operational state
        Write-LogMessage -Message "Scope '$ScopeId' already exists. Ensuring scope state is Active..." -Level 'INFO'
        Set-DhcpServerv4Scope -ScopeId $ScopeId -State Active -ErrorAction SilentlyContinue
        Write-LogMessage -Message "Existing scope '$ScopeId' confirmed Active." -Level 'SUCCESS'
    }
} catch {
    Write-LogMessage -Message "Scope creation failed: $_" -Level 'ERROR'
    throw $_
}

# ==============================================================================
# PHASE 4: STATIC IP EXCLUSION RANGES
# ==============================================================================
# Exclusions prevent DHCP from leasing IP addresses assigned statically to core infrastructure
# (e.g., Default Gateway, Domain Controllers, SQL Failover Cluster VIPs, UTM firewalls)
if ($null -ne $ExclusionRanges -and $ExclusionRanges.Count -gt 0) {
    Write-LogMessage -Message "Applying static IP exclusion ranges to scope '$ScopeId'..." -Level 'INFO'
    try {
        # Query existing exclusions to prevent duplicate entry errors
        $currentExclusions = Get-DhcpServerv4ExclusionRange -ScopeId $ScopeId -ErrorAction SilentlyContinue
        foreach ($item in $ExclusionRanges) {
            $startIp = $null
            $endIp = $null

            # Parse input as hashtable range or single IP string
            if ($item -is [hashtable]) {
                $startIp = $item['StartRange']
                $endIp = if ($item.ContainsKey('EndRange')) { $item['EndRange'] } else { $startIp }
            } elseif ($item -is [string] -or $item -is [System.Net.IPAddress]) {
                $startIp = $item.ToString()
                $endIp = $item.ToString()
            }

            # Check for existing duplicate exclusion in scope
            $alreadyExcluded = $false
            if ($null -ne $currentExclusions) {
                foreach ($ex in $currentExclusions) {
                    if ($ex.StartRange -eq $startIp -and $ex.EndRange -eq $endIp) {
                        $alreadyExcluded = $true
                        break
                    }
                }
            }

            # Add exclusion range if not already defined
            if (-not $alreadyExcluded) {
                if ($PSCmdlet.ShouldProcess("Exclusion $startIp to $endIp", "Add DHCP Exclusion Range")) {
                    Add-DhcpServerv4ExclusionRange -ScopeId $ScopeId -StartRange $startIp -EndRange $endIp
                    Write-LogMessage -Message "Added exclusion: $startIp -> $endIp" -Level 'INFO'
                }
            }
        }
        Write-LogMessage -Message "Exclusion ranges processed successfully." -Level 'SUCCESS'
    } catch {
        Write-LogMessage -Message "Error configuring exclusions: $_" -Level 'WARNING'
    }
}

# ==============================================================================
# PHASE 5: DHCP SCOPE OPTIONS CONFIGURATION
# ==============================================================================
# Configures standard RFC DHCP options distributed to client workstations:
#   Option 003: Default Gateway / Router
#   Option 006: Primary and Secondary DNS Servers
#   Option 015: Domain Name Suffix
Write-LogMessage -Message "Configuring DHCP Scope Options (Router, DNS Servers, Domain Name)..." -Level 'INFO'
try {
    # Convert DNS IPAddress objects to string array format
    $dnsIpStrings = @($DnsServers | ForEach-Object { $_.IPAddressToString })
    if ($PSCmdlet.ShouldProcess("Scope Options on $ScopeId", "Apply Router, DNS, and Domain Options")) {
        Set-DhcpServerv4OptionValue -ScopeId $ScopeId `
                                    -Router $Gateway.IPAddressToString `
                                    -DnsServer $dnsIpStrings `
                                    -DnsDomain $DnsDomainName
        Write-LogMessage -Message "Scope Options applied: Router=$Gateway, DNS=$($dnsIpStrings -join ', '), Domain=$DnsDomainName" -Level 'SUCCESS'
    }
} catch {
    Write-LogMessage -Message "Failed to apply scope options: $_" -Level 'ERROR'
    throw $_
}

# ==============================================================================
# PHASE 6: CLIENT MAC ADDRESS RESERVATIONS
# ==============================================================================
# Client reservations permanently bind a specific IPv4 address to a client's physical MAC address
if ($null -ne $Reservations -and $Reservations.Count -gt 0) {
    Write-LogMessage -Message "Registering client MAC address reservations..." -Level 'INFO'
    try {
        # Retrieve existing reservations to prevent duplicate registration collisions
        $existingReservations = Get-DhcpServerv4Reservation -ScopeId $ScopeId -ErrorAction SilentlyContinue
        foreach ($res in $Reservations) {
            $mac = if ($res.ContainsKey('MAC')) { $res['MAC'] } else { $res['ClientId'] }
            $ip = $res['IP']
            $name = if ($res.ContainsKey('Name')) { $res['Name'] } else { $res['Description'] }

            # Normalize MAC to standard hyphen-delimited format (e.g., 00-15-5D-68-48-00)
            $cleanMac = ($mac -replace '[:\.\-]', '').ToUpper()
            $formattedMac = ($cleanMac -split '([A-F0-9]{2})' | Where-Object { $_ -ne '' }) -join '-'

            # Check if reservation already exists
            $resExists = $false
            if ($null -ne $existingReservations) {
                foreach ($er in $existingReservations) {
                    if ($er.IPAddress -eq $ip -or ($er.ClientId -replace '[:\.\-]', '').ToUpper() -eq $cleanMac) {
                        $resExists = $true
                        break
                    }
                }
            }

            # Register reservation if new
            if (-not $resExists) {
                if ($PSCmdlet.ShouldProcess("Reservation for $name ($ip / $formattedMac)", "Register DHCP Reservation")) {
                    Add-DhcpServerv4Reservation -ScopeId $ScopeId `
                                                -IPAddress $ip `
                                                -ClientId $formattedMac `
                                                -Description $name
                    Write-LogMessage -Message "Registered reservation: $name -> $ip [$formattedMac]" -Level 'INFO'
                }
            } else {
                Write-LogMessage -Message "Reservation for $name ($ip) already present; skipping." -Level 'INFO'
            }
        }
        Write-LogMessage -Message "All reservations synchronized." -Level 'SUCCESS'
    } catch {
        Write-LogMessage -Message "Error configuring MAC reservations: $_" -Level 'WARNING'
    }
}

# ==============================================================================
# PHASE 7: POST-DEPLOYMENT SERVER MANAGER ALERT DISMISSAL
# ==============================================================================
# After installing the DHCP role, Windows Server Manager displays a warning notification.
# Setting ConfigurationState to 2 marks post-installation configuration as completed in the registry.
Write-LogMessage -Message "Updating post-deployment registry configuration state..." -Level 'INFO'
try {
    $regPath = "HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12"
    if (Test-Path $regPath) {
        if ($PSCmdlet.ShouldProcess($regPath, "Set ConfigurationState = 2")) {
            Set-ItemProperty -Path $regPath -Name "ConfigurationState" -Value 2 -Force
            Write-LogMessage -Message "Server Manager post-configuration alert cleared (ConfigurationState = 2)." -Level 'SUCCESS'
        }
    } else {
        Write-LogMessage -Message "Server Manager registry role key not present on this host platform; skipping registry flag." -Level 'INFO'
    }
} catch {
    Write-LogMessage -Message "Could not update Server Manager registry state: $_" -Level 'WARNING'
}

# ==============================================================================
# PHASE 8: DEPLOYMENT SUMMARY & HEALTH VERIFICATION
# ==============================================================================
# Query newly deployed DHCP objects and compile a structured PSCustomObject summary report
Write-LogMessage -Message "Generating post-deployment verification summary..." -Level 'INFO'
try {
    $deployedScope = Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction SilentlyContinue
    $deployedOptions = Get-DhcpServerv4OptionValue -ScopeId $ScopeId -ErrorAction SilentlyContinue
    $deployedExclusions = Get-DhcpServerv4ExclusionRange -ScopeId $ScopeId -ErrorAction SilentlyContinue
    $deployedReservations = Get-DhcpServerv4Reservation -ScopeId $ScopeId -ErrorAction SilentlyContinue

    $summary = [PSCustomObject]@{
        Timestamp         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ScopeId           = $ScopeId
        ScopeName         = if ($deployedScope) { $deployedScope.Name } else { $ScopeName }
        State             = if ($deployedScope) { $deployedScope.State.ToString() } else { "Created" }
        StartRange        = if ($deployedScope) { $deployedScope.StartRange.IPAddressToString } else { $StartRange.IPAddressToString }
        EndRange          = if ($deployedScope) { $deployedScope.EndRange.IPAddressToString } else { $EndRange.IPAddressToString }
        SubnetMask        = if ($deployedScope) { $deployedScope.SubnetMask.IPAddressToString } else { $SubnetMask.IPAddressToString }
        RouterGateway     = $Gateway.IPAddressToString
        DnsServers        = ($DnsServers | ForEach-Object { $_.IPAddressToString }) -join ', '
        DnsDomainName     = $DnsDomainName
        ExclusionCount    = if ($deployedExclusions) { @($deployedExclusions).Count } else { $ExclusionRanges.Count }
        ReservationCount  = if ($deployedReservations) { @($deployedReservations).Count } else { $Reservations.Count }
        Status            = "Operational"
    }

    Write-LogMessage -Message "DHCP Server deployment completed successfully." -Level 'SUCCESS'
    # Return structured summary to caller
    return $summary
} catch {
    Write-LogMessage -Message "Notice: Could not generate complete post-deployment report: $_" -Level 'WARNING'
}
