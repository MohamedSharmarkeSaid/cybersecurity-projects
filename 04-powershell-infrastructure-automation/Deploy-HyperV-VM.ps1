<#
.SYNOPSIS
    Provisions enterprise Generation 2 Hyper-V virtual machines with UEFI firmware and a multi-disk SCSI database storage array.

.DESCRIPTION
    Deploy-HyperV-VM implements Infrastructure-as-Code (IaC) virtualization deployment for Windows Server Hyper-V.
    The script provisions Generation 2 virtual machines featuring:
      - UEFI firmware initialization with configurable Secure Boot templates (MicrosoftWindows / MicrosoftUEFICertificateAuthority).
      - Compute resource allocation (vCPU count, startup memory, and Dynamic Memory thresholds).
      - Dynamic VHDX operating system disk attachment and virtual switch network binding.
      - Optical DVD drive mounting with boot-order prioritization for automated unattended OS installation.
      - Automated creation and attachment of a high-performance 6-disk SCSI storage tier optimized for SQL Server
        workloads (Program, SystemDB, UserData, UserLog, tempdbData, tempdbLog), pre-configured for 64KB NTFS cluster allocation.

.PARAMETER VMName
    The unique hostname and VM identifier in Hyper-V (e.g., 'SQL-PROD-01').

.PARAMETER MemoryStartupBytes
    The initial startup RAM allocated to the VM. Defaults to 4GB.

.PARAMETER EnableDynamicMemory
    Enables Hyper-V Dynamic Memory ballooning. Defaults to $true.

.PARAMETER MemoryMinimumBytes
    The minimum RAM allocated when Dynamic Memory is active. Defaults to 2GB.

.PARAMETER MemoryMaximumBytes
    The maximum RAM allowed during high contention. Defaults to 16GB.

.PARAMETER ProcessorCount
    Number of virtual processors (vCPUs) assigned to the VM. Defaults to 4.

.PARAMETER SwitchName
    Name of the Hyper-V Virtual Switch to bind the primary network adapter. Defaults to 'Production-vSwitch'.

.PARAMETER VMStoragePath
    Root directory for VM configuration files and metadata. Defaults to 'C:\Hyper-V\Virtual Machines'.

.PARAMETER VHDStoragePath
    Root directory for virtual hard disks (.vhdx). Defaults to 'C:\Hyper-V\Virtual Hard Disks'.

.PARAMETER OsDiskSizeBytes
    Capacity of the operating system VHDX drive. Defaults to 60GB.

.PARAMETER IsoPath
    Path to an installation ISO image mounted to the virtual DVD drive. Optional.

.PARAMETER ProvisionDatabaseArray
    Switch indicating whether to create and attach the dedicated 6-disk SCSI database storage tier.

.PARAMETER DatabaseDiskSizes
    Hashtable defining the disk sizes for the database storage array:
      - Program: SQL binaries & engine tools (default: 40GB)
      - SystemDB: master, model, msdb (default: 30GB)
      - UserData: user database data files (.mdf) (default: 100GB)
      - UserLog: user database transaction logs (.ldf) (default: 50GB)
      - tempdbData: tempdb data files (default: 40GB)
      - tempdbLog: tempdb transaction log (default: 20GB)

.PARAMETER EnableSecureBoot
    Enables UEFI Secure Boot. Defaults to $true.

.PARAMETER SecureBootTemplate
    Secure Boot template name (e.g., 'MicrosoftWindows' or 'MicrosoftUEFICertificateAuthority' for Linux). Defaults to 'MicrosoftWindows'.

.PARAMETER StartVM
    Automatically powers on the virtual machine upon successful provisioning.

.EXAMPLE
    .\Deploy-HyperV-VM.ps1 -VMName "PROD-DC01" -MemoryStartupBytes 4GB -ProcessorCount 2 `
        -SwitchName "ExternalSwitch" -IsoPath "D:\ISOs\WindowsServer2022.iso"

    Provisions a standard Generation 2 Domain Controller VM with 4GB RAM, 2 vCPUs, and an attached OS ISO.

.EXAMPLE
    .\Deploy-HyperV-VM.ps1 -VMName "PROD-SQL-01" -MemoryStartupBytes 8GB -ProcessorCount 8 `
        -SwitchName "Production-vSwitch" -ProvisionDatabaseArray -StartVM

    Provisions an enterprise Generation 2 database server with an OS disk plus a 6-disk SCSI storage tier
    (Program, SystemDB, UserData, UserLog, tempdbData, tempdbLog) and boots the machine.

.OUTPUTS
    [PSCustomObject] Summary report containing VM configuration, compute metrics, virtual disk paths, and SCSI mappings.

.NOTES
    Author: Mohamed Said
    Portfolio: Cybersecurity & SOC Infrastructure Automation (Module 04)
    Reference: Active Directory / SQL Server 2014 Failover Cluster Architecture
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    # Parameter: VMName
    # Specifies the unique hostname and Hyper-V virtual machine identifier (e.g., 'SQL-PROD-01' or 'DC03')
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the Hyper-V Virtual Machine.")]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    # Parameter: MemoryStartupBytes
    # Defines the initial RAM allocated to the VM during startup / boot (default: 4 GB)
    [Parameter(Mandatory = $false, HelpMessage = "Startup memory in bytes.")]
    [int64]$MemoryStartupBytes = 4GB,

    # Parameter: EnableDynamicMemory
    # Controls whether Hyper-V Dynamic Memory ballooning is enabled to adjust RAM dynamically under load
    [Parameter(Mandatory = $false, HelpMessage = "Enable Dynamic Memory.")]
    [bool]$EnableDynamicMemory = $true,

    # Parameter: MemoryMinimumBytes
    # Minimum RAM threshold that Hyper-V can reclaim down to when host memory is constrained (default: 2 GB)
    [Parameter(Mandatory = $false, HelpMessage = "Minimum dynamic memory in bytes.")]
    [int64]$MemoryMinimumBytes = 2GB,

    # Parameter: MemoryMaximumBytes
    # Maximum RAM ceiling the virtual machine is allowed to consume under heavy workload (default: 16 GB)
    [Parameter(Mandatory = $false, HelpMessage = "Maximum dynamic memory in bytes.")]
    [int64]$MemoryMaximumBytes = 16GB,

    # Parameter: ProcessorCount
    # Number of virtual CPU cores (vCPUs) assigned to the guest operating system (default: 4 cores)
    [Parameter(Mandatory = $false, HelpMessage = "Number of virtual processors.")]
    [ValidateRange(1, 64)]
    [int]$ProcessorCount = 4,

    # Parameter: SwitchName
    # Name of the virtual switch (vSwitch) to which the VM network interface card (vNIC) connects
    [Parameter(Mandatory = $false, HelpMessage = "Virtual Switch name.")]
    [ValidateNotNullOrEmpty()]
    [string]$SwitchName = "Production-vSwitch",

    # Parameter: VMStoragePath
    # Host root directory where VM XML/VMCX metadata and configuration files are stored
    [Parameter(Mandatory = $false, HelpMessage = "Path for VM configuration files.")]
    [ValidateNotNullOrEmpty()]
    [string]$VMStoragePath = "C:\Hyper-V\Virtual Machines",

    # Parameter: VHDStoragePath
    # Host directory where virtual hard disk files (.vhdx) are created and saved
    [Parameter(Mandatory = $false, HelpMessage = "Path for VHDX virtual hard disk files.")]
    [ValidateNotNullOrEmpty()]
    [string]$VHDStoragePath = "C:\Hyper-V\Virtual Hard Disks",

    # Parameter: OsDiskSizeBytes
    # Capacity allocated for the primary operating system VHDX disk (default: 60 GB)
    [Parameter(Mandatory = $false, HelpMessage = "Operating system disk capacity in bytes.")]
    [int64]$OsDiskSizeBytes = 60GB,

    # Parameter: IsoPath
    # Optional file path to a guest OS installation ISO image to mount on the virtual DVD drive
    [Parameter(Mandatory = $false, HelpMessage = "Path to guest OS installation ISO image.")]
    [string]$IsoPath,

    # Parameter: ProvisionDatabaseArray
    # Switch flag to automatically create and attach a dedicated 6-disk SCSI storage tier for SQL Server
    [Parameter(Mandatory = $false, HelpMessage = "Provision 6-disk SCSI database storage array.")]
    [switch]$ProvisionDatabaseArray,

    # Parameter: DatabaseDiskSizes
    # Hashtable defining individual disk capacities for enterprise database separation
    # Segregates binaries, system DBs, user tables (.mdf), transaction logs (.ldf), and tempdb
    [Parameter(Mandatory = $false, HelpMessage = "Size specifications for SQL database disks.")]
    [hashtable]$DatabaseDiskSizes = @{
        'Program'    = 40GB
        'SystemDB'   = 30GB
        'UserData'   = 100GB
        'UserLog'    = 50GB
        'tempdbData' = 40GB
        'tempdbLog'  = 20GB
    },

    # Parameter: EnableSecureBoot
    # Enables UEFI Secure Boot to prevent unsigned or unauthorized bootloaders from executing
    [Parameter(Mandatory = $false, HelpMessage = "Enable UEFI Secure Boot.")]
    [bool]$EnableSecureBoot = $true,

    # Parameter: SecureBootTemplate
    # Specifies the UEFI Secure Boot certificate authority template ('MicrosoftWindows' for Windows, 'MicrosoftUEFICertificateAuthority' for Linux)
    [Parameter(Mandatory = $false, HelpMessage = "UEFI Secure Boot template.")]
    [ValidateSet('MicrosoftWindows', 'MicrosoftUEFICertificateAuthority', 'OpenSourceShieldedVM')]
    [string]$SecureBootTemplate = 'MicrosoftWindows',

    # Parameter: StartVM
    # Switch flag to immediately boot the virtual machine once provisioning and disk attachment complete
    [Parameter(Mandatory = $false, HelpMessage = "Power on virtual machine after deployment.")]
    [switch]$StartVM
)

# Set strict mode and stop on first terminating error for script reliability
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Function: Write-LogMessage
# Formats console output with an ISO timestamp, severity tag, and color coding
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
# PRE-FLIGHT VALIDATION
# ==============================================================================
Write-LogMessage -Message "Initiating pre-flight verification for Hyper-V host deployment..." -Level 'INFO'

# Step 1: Ensure script runs with elevated administrator rights to interact with Hyper-V WMI/VMBus
if (-not (Test-AdministratorPrivileges)) {
    throw "Access Denied: Hyper-V management requires elevated Administrator privileges."
}

# Step 2: Verify that the Microsoft Hyper-V PowerShell module is installed on the host
$hyperVModule = Get-Module -ListAvailable -Name Hyper-V
if ($null -eq $hyperVModule) {
    throw "Prerequisite Missing: Hyper-V PowerShell module is not available. Please install RSAT-Hyper-V-Tools."
}
# Import Hyper-V cmdlets into the current session
Import-Module Hyper-V -ErrorAction SilentlyContinue

# Step 3: Compute target folder paths for VM configuration files and virtual hard disks (VHDX)
$vmTargetDir = Join-Path -Path $VMStoragePath -ChildPath $VMName
$vhdTargetDir = Join-Path -Path $VHDStoragePath -ChildPath $VMName

# Step 4: Create target directories on the filesystem if they do not already exist
foreach ($dir in @($VMStoragePath, $VHDStoragePath, $vmTargetDir, $vhdTargetDir)) {
    if (-not (Test-Path $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, "Create Directory")) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-LogMessage -Message "Created storage directory: $dir" -Level 'INFO'
        }
    }
}

# Step 5: Verify that the specified Virtual Switch exists on the host
$vswitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if ($null -eq $vswitch) {
    Write-LogMessage -Message "Virtual Switch '$SwitchName' was not located. Available switches: $((Get-VMSwitch | Select-Object -ExpandProperty Name) -join ', ')" -Level 'WARNING'
}

# Step 6: Prevent duplicate VM provisioning by verifying no existing VM shares the same name
$existingVm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if ($null -ne $existingVm) {
    throw "Conflict: A Virtual Machine named '$VMName' already exists on this host."
}

# ==============================================================================
# PHASE 1: PROVISION GENERATION 2 VIRTUAL MACHINE
# ==============================================================================
# Generation 2 VMs use UEFI firmware, SCSI controllers, and synthetic network adapters (no legacy IDE emulation)
$osVhdPath = Join-Path -Path $vhdTargetDir -ChildPath "$($VMName)_OS.vhdx"
Write-LogMessage -Message "Creating Generation 2 VM '$VMName' with $($MemoryStartupBytes / 1GB)GB RAM and OS disk ($($OsDiskSizeBytes / 1GB)GB)..." -Level 'INFO'

if ($PSCmdlet.ShouldProcess($VMName, "Create Generation 2 Virtual Machine")) {
    # Build parameters hashtable (splatting) for New-VM
    $vmParams = @{
        Name               = $VMName
        Generation         = 2                       # Enforces Generation 2 (UEFI architecture)
        MemoryStartupBytes = $MemoryStartupBytes     # Assigns initial boot memory
        NewVHDPath         = $osVhdPath              # Target path for newly created OS disk
        NewVHDSizeBytes    = $OsDiskSizeBytes         # Capacity of primary OS disk
        Path               = $VMStoragePath          # Storage location for VM metadata files
    }

    # Bind to virtual switch if present
    if ($null -ne $vswitch) {
        $vmParams['SwitchName'] = $SwitchName
    }

    # Execute VM creation cmdlet
    $vm = New-VM @vmParams
    Write-LogMessage -Message "Generation 2 VM object '$VMName' provisioned successfully." -Level 'SUCCESS'
}

# ==============================================================================
# PHASE 2: COMPUTE & MEMORY OPTIMIZATION
# ==============================================================================
Write-LogMessage -Message "Configuring compute topology: $ProcessorCount vCPUs, Dynamic Memory..." -Level 'INFO'
if ($PSCmdlet.ShouldProcess($VMName, "Configure vCPU and Dynamic Memory")) {
    # Assign virtual CPU cores to the VM
    Set-VM -Name $VMName -ProcessorCount $ProcessorCount

    # Configure memory model: Dynamic Memory ballooning allows host to reclaim unused RAM
    if ($EnableDynamicMemory) {
        Set-VMMemory -Name $VMName `
                     -DynamicMemoryEnabled $true `
                     -MinimumBytes $MemoryMinimumBytes `
                     -StartupBytes $MemoryStartupBytes `
                     -MaximumBytes $MemoryMaximumBytes
        Write-LogMessage -Message "Dynamic Memory enabled: Min=$($MemoryMinimumBytes/1GB)GB, Max=$($MemoryMaximumBytes/1GB)GB" -Level 'SUCCESS'
    } else {
        # Static memory allocation
        Set-VMMemory -Name $VMName -DynamicMemoryEnabled $false
    }
}

# ==============================================================================
# PHASE 3: UEFI FIRMWARE & SECURE BOOT CONFIGURATION
# ==============================================================================
# Hyper-V Gen 2 uses Microsoft Virtual UEFI Firmware. Set-VMFirmware manages Secure Boot and boot order.
Write-LogMessage -Message "Configuring UEFI firmware and Secure Boot..." -Level 'INFO'
if ($PSCmdlet.ShouldProcess($VMName, "Configure UEFI Firmware")) {
    if ($EnableSecureBoot) {
        # Enforce UEFI Secure Boot using the specified template (default: MicrosoftWindows Certificate Authority)
        Set-VMFirmware -Name $VMName -EnableSecureBoot On -SecureBootTemplate $SecureBootTemplate
        Write-LogMessage -Message "Secure Boot enabled using template: $SecureBootTemplate" -Level 'SUCCESS'
    } else {
        # Disable Secure Boot if running legacy kernels or unsigned payloads
        Set-VMFirmware -Name $VMName -EnableSecureBoot Off
        Write-LogMessage -Message "Secure Boot disabled." -Level 'WARNING'
    }
}

# ==============================================================================
# PHASE 4: VIRTUAL DVD DRIVE & BOOT ORDER PRIORITIZATION
# ==============================================================================
if (-not [string]::IsNullOrEmpty($IsoPath)) {
    Write-LogMessage -Message "Attaching installation ISO media: $IsoPath" -Level 'INFO'
    if (Test-Path $IsoPath) {
        if ($PSCmdlet.ShouldProcess($VMName, "Attach DVD Drive with ISO")) {
            # Add virtual DVD drive to SCSI controller and attach the ISO image
            $dvd = Add-VMDvdDrive -VMName $VMName -Path $IsoPath -Passthru
            # Prioritize the DVD drive as the first UEFI boot entry for OS installation
            Set-VMFirmware -Name $VMName -FirstBootDevice $dvd
            Write-LogMessage -Message "DVD drive attached with ISO and set as primary boot device in UEFI." -Level 'SUCCESS'
        }
    } else {
        Write-LogMessage -Message "Specified ISO file does not exist at '$IsoPath'. Skipping DVD attachment." -Level 'WARNING'
    }
}

# ==============================================================================
# PHASE 5: PROVISION DEDICATED DATABASE SCSI STORAGE TIER
# ==============================================================================
# Initialize list to track all attached disks for deployment reporting
$attachedDisks = [System.Collections.Generic.List[PSCustomObject]]::new()
$attachedDisks.Add([PSCustomObject]@{
    DiskName   = "OS_System"
    Path       = $osVhdPath
    SizeBytes  = $OsDiskSizeBytes
    Controller = "SCSI (Default)"
    LUN        = 0
    ClusterKB  = "Default (4KB)"
})

if ($ProvisionDatabaseArray) {
    Write-LogMessage -Message "Provisioning 6-disk SCSI database storage array optimized for SQL Server..." -Level 'INFO'

    # Verify that SCSI controller 0 is present (Gen 2 VMs include SCSI controller 0 by default)
    $scsiController = Get-VMScsiController -VMName $VMName -ControllerNumber 0 -ErrorAction SilentlyContinue
    if ($null -eq $scsiController) {
        Write-LogMessage -Message "Adding secondary SCSI Controller..." -Level 'INFO'
        $scsiController = Add-VMScsiController -VMName $VMName -Passthru
    }

    # Define the 6 dedicated database disk volumes:
    # 1. Program: SQL binaries & tools
    # 2. SystemDB: master, model, msdb
    # 3. UserData: User database tables and indexes (.mdf)
    # 4. UserLog: Transaction log records (.ldf) - isolated on separate LUN to eliminate I/O contention
    # 5. tempdbData: Temporary working tables (.mdf)
    # 6. tempdbLog: Tempdb transaction log (.ldf)
    $diskOrder = @('Program', 'SystemDB', 'UserData', 'UserLog', 'tempdbData', 'tempdbLog')
    $lunIndex = 1

    # Iterate through each disk role and create dynamic VHDX disks
    foreach ($diskKey in $diskOrder) {
        # Determine capacity from hashtable or fall back to default
        $diskSize = if ($DatabaseDiskSizes.ContainsKey($diskKey)) { $DatabaseDiskSizes[$diskKey] } else { 30GB }
        $diskPath = Join-Path -Path $vhdTargetDir -ChildPath "$($VMName)_$($diskKey).vhdx"

        if ($PSCmdlet.ShouldProcess($diskPath, "Create VHDX and attach to SCSI Controller 0 (LUN $lunIndex)")) {
            Write-LogMessage -Message "Creating VHDX: $diskKey ($($diskSize / 1GB)GB) -> $diskPath" -Level 'INFO'
            # Create dynamically expanding virtual hard disk
            New-VHD -Path $diskPath -SizeBytes $diskSize -Dynamic | Out-Null
            # Attach virtual disk to SCSI Controller 0 at specific LUN index
            Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation $lunIndex -Path $diskPath

            # SQL workloads recommend 64KB cluster allocation for data/log files; OS/binaries use default 4KB
            $clusterAllocation = if ($diskKey -eq 'Program') { "4KB (NTFS Default)" } else { "64KB (SQL Workload Recommended)" }
            $attachedDisks.Add([PSCustomObject]@{
                DiskName   = $diskKey
                Path       = $diskPath
                SizeBytes  = $diskSize
                Controller = "SCSI 0"
                LUN        = $lunIndex
                ClusterKB  = $clusterAllocation
            })
            # Increment LUN address for next drive
            $lunIndex++
        }
    }
    Write-LogMessage -Message "Database multi-disk SCSI tier configured successfully." -Level 'SUCCESS'
}

# ==============================================================================
# PHASE 6: GUEST STORAGE INITIALIZATION SCRIPT GENERATOR
# ==============================================================================
# Generates a companion PowerShell helper script inside the VM folder.
# When run inside the guest OS, it formats raw disks with GPT and sets 64KB cluster allocation for SQL Server.
$guestScriptContent = @"
# In-Guest Automated Disk Initialization and Formatting
# Enforces GPT partition style and 64KB allocation unit size for SQL Server database volumes

`$diskMappings = @{
    'Program'    = @{ SizeGB = 40;  Letter = 'P'; Label = 'SQL_Program';   ClusterSize = 4096 }
    'SystemDB'   = @{ SizeGB = 30;  Letter = 'S'; Label = 'SQL_SystemDB';  ClusterSize = 65536 }
    'UserData'   = @{ SizeGB = 100; Letter = 'U'; Label = 'SQL_UserData';  ClusterSize = 65536 }
    'UserLog'    = @{ SizeGB = 50;  Letter = 'L'; Label = 'SQL_UserLog';   ClusterSize = 65536 }
    'tempdbData' = @{ SizeGB = 40;  Letter = 'T'; Label = 'SQL_TempDB';    ClusterSize = 65536 }
    'tempdbLog'  = @{ SizeGB = 20;  Letter = 'E'; Label = 'SQL_TempLog';   ClusterSize = 65536 }
}

# Scan raw disks, initialize GPT partition style, create partition, and format with 64KB cluster size
Get-Disk | Where-Object { `$_.PartitionStyle -eq 'RAW' } | ForEach-Object {
    `$disk = `$_
    Write-Host "Initializing Disk `$(`$disk.Number) (`$([math]::Round(`$disk.Size / 1GB)) GB)..." -ForegroundColor Cyan
    Initialize-Disk -Number `$disk.Number -PartitionStyle GPT
    `$partition = New-Partition -DiskNumber `$disk.Number -UseMaximumSize -AssignDriveLetter
    Format-Volume -Partition `$partition -FileSystem NTFS -AllocationUnitSize 65536 -Confirm:`$false
}
"@

$guestScriptPath = Join-Path -Path $vhdTargetDir -ChildPath "Initialize-GuestDatabaseDisks.ps1"
try {
    # Save the in-guest disk initialization script to the VM folder
    Set-Content -Path $guestScriptPath -Value $guestScriptContent -Encoding UTF8
    Write-LogMessage -Message "In-guest initialization helper generated: $guestScriptPath" -Level 'INFO'
} catch {
    Write-LogMessage -Message "Notice: Could not write guest disk script: $_" -Level 'WARNING'
}

# ==============================================================================
# PHASE 7: POWER MANAGEMENT
# ==============================================================================
if ($StartVM) {
    Write-LogMessage -Message "Powering on Virtual Machine '$VMName'..." -Level 'INFO'
    if ($PSCmdlet.ShouldProcess($VMName, "Start-VM")) {
        # Power on the virtual machine via Hyper-V cmdlet
        Start-VM -Name $VMName
        Write-LogMessage -Message "Virtual Machine '$VMName' is running." -Level 'SUCCESS'
    }
}

# ==============================================================================
# PHASE 8: DEPLOYMENT REPORT
# ==============================================================================
# Build structured output object capturing complete deployment state
$vmSummary = [PSCustomObject]@{
    VMName            = $VMName
    Generation        = 2
    State             = (Get-VM -Name $VMName -ErrorAction SilentlyContinue).State.ToString()
    ProcessorCount    = $ProcessorCount
    MemoryStartupGB   = [math]::Round($MemoryStartupBytes / 1GB, 2)
    DynamicMemory     = $EnableDynamicMemory
    SecureBoot        = $EnableSecureBoot
    SecureBootProfile = $SecureBootTemplate
    VirtualSwitch     = $SwitchName
    OsVhdPath         = $osVhdPath
    DiskCount         = $attachedDisks.Count
    Disks             = $attachedDisks
    Timestamp         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

Write-LogMessage -Message "Hyper-V Virtual Machine provisioning completed." -Level 'SUCCESS'
# Return summary object to caller
return $vmSummary
