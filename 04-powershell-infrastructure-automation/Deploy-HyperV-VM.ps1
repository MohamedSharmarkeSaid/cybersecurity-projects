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
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the Hyper-V Virtual Machine.")]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [Parameter(Mandatory = $false, HelpMessage = "Startup memory in bytes.")]
    [int64]$MemoryStartupBytes = 4GB,

    [Parameter(Mandatory = $false, HelpMessage = "Enable Dynamic Memory.")]
    [bool]$EnableDynamicMemory = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Minimum dynamic memory in bytes.")]
    [int64]$MemoryMinimumBytes = 2GB,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum dynamic memory in bytes.")]
    [int64]$MemoryMaximumBytes = 16GB,

    [Parameter(Mandatory = $false, HelpMessage = "Number of virtual processors.")]
    [ValidateRange(1, 64)]
    [int]$ProcessorCount = 4,

    [Parameter(Mandatory = $false, HelpMessage = "Virtual Switch name.")]
    [ValidateNotNullOrEmpty()]
    [string]$SwitchName = "Production-vSwitch",

    [Parameter(Mandatory = $false, HelpMessage = "Path for VM configuration files.")]
    [ValidateNotNullOrEmpty()]
    [string]$VMStoragePath = "C:\Hyper-V\Virtual Machines",

    [Parameter(Mandatory = $false, HelpMessage = "Path for VHDX virtual hard disk files.")]
    [ValidateNotNullOrEmpty()]
    [string]$VHDStoragePath = "C:\Hyper-V\Virtual Hard Disks",

    [Parameter(Mandatory = $false, HelpMessage = "Operating system disk capacity in bytes.")]
    [int64]$OsDiskSizeBytes = 60GB,

    [Parameter(Mandatory = $false, HelpMessage = "Path to guest OS installation ISO image.")]
    [string]$IsoPath,

    [Parameter(Mandatory = $false, HelpMessage = "Provision 6-disk SCSI database storage array.")]
    [switch]$ProvisionDatabaseArray,

    [Parameter(Mandatory = $false, HelpMessage = "Size specifications for SQL database disks.")]
    [hashtable]$DatabaseDiskSizes = @{
        'Program'    = 40GB
        'SystemDB'   = 30GB
        'UserData'   = 100GB
        'UserLog'    = 50GB
        'tempdbData' = 40GB
        'tempdbLog'  = 20GB
    },

    [Parameter(Mandatory = $false, HelpMessage = "Enable UEFI Secure Boot.")]
    [bool]$EnableSecureBoot = $true,

    [Parameter(Mandatory = $false, HelpMessage = "UEFI Secure Boot template.")]
    [ValidateSet('MicrosoftWindows', 'MicrosoftUEFICertificateAuthority', 'OpenSourceShieldedVM')]
    [string]$SecureBootTemplate = 'MicrosoftWindows',

    [Parameter(Mandatory = $false, HelpMessage = "Power on virtual machine after deployment.")]
    [switch]$StartVM
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Test-AdministratorPrivileges {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Pre-flight Validation ---
Write-LogMessage -Message "Initiating pre-flight verification for Hyper-V host deployment..." -Level 'INFO'

if (-not (Test-AdministratorPrivileges)) {
    throw "Access Denied: Hyper-V management requires elevated Administrator privileges."
}

# Verify Hyper-V PowerShell module
$hyperVModule = Get-Module -ListAvailable -Name Hyper-V
if ($null -eq $hyperVModule) {
    throw "Prerequisite Missing: Hyper-V PowerShell module is not available. Please install RSAT-Hyper-V-Tools."
}
Import-Module Hyper-V -ErrorAction SilentlyContinue

# Verify Target Directories
$vmTargetDir = Join-Path -Path $VMStoragePath -ChildPath $VMName
$vhdTargetDir = Join-Path -Path $VHDStoragePath -ChildPath $VMName

foreach ($dir in @($VMStoragePath, $VHDStoragePath, $vmTargetDir, $vhdTargetDir)) {
    if (-not (Test-Path $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, "Create Directory")) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-LogMessage -Message "Created storage directory: $dir" -Level 'INFO'
        }
    }
}

# Verify Virtual Switch
$vswitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if ($null -eq $vswitch) {
    Write-LogMessage -Message "Virtual Switch '$SwitchName' was not located. Available switches: $((Get-VMSwitch | Select-Object -ExpandProperty Name) -join ', ')" -Level 'WARNING'
}

# Check if VM already exists
$existingVm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if ($null -ne $existingVm) {
    throw "Conflict: A Virtual Machine named '$VMName' already exists on this host."
}

# --- Phase 1: Provision Generation 2 Virtual Machine ---
$osVhdPath = Join-Path -Path $vhdTargetDir -ChildPath "$($VMName)_OS.vhdx"
Write-LogMessage -Message "Creating Generation 2 VM '$VMName' with $($MemoryStartupBytes / 1GB)GB RAM and OS disk ($($OsDiskSizeBytes / 1GB)GB)..." -Level 'INFO'

if ($PSCmdlet.ShouldProcess($VMName, "Create Generation 2 Virtual Machine")) {
    $vmParams = @{
        Name               = $VMName
        Generation         = 2
        MemoryStartupBytes = $MemoryStartupBytes
        NewVHDPath         = $osVhdPath
        NewVHDSizeBytes    = $OsDiskSizeBytes
        Path               = $VMStoragePath
    }

    if ($null -ne $vswitch) {
        $vmParams['SwitchName'] = $SwitchName
    }

    $vm = New-VM @vmParams
    Write-LogMessage -Message "Generation 2 VM object '$VMName' provisioned successfully." -Level 'SUCCESS'
}

# --- Phase 2: Compute & Memory Optimization ---
Write-LogMessage -Message "Configuring compute topology: $ProcessorCount vCPUs, Dynamic Memory..." -Level 'INFO'
if ($PSCmdlet.ShouldProcess($VMName, "Configure vCPU and Dynamic Memory")) {
    Set-VM -Name $VMName -ProcessorCount $ProcessorCount

    if ($EnableDynamicMemory) {
        Set-VMMemory -Name $VMName `
                     -DynamicMemoryEnabled $true `
                     -MinimumBytes $MemoryMinimumBytes `
                     -StartupBytes $MemoryStartupBytes `
                     -MaximumBytes $MemoryMaximumBytes
        Write-LogMessage -Message "Dynamic Memory enabled: Min=$($MemoryMinimumBytes/1GB)GB, Max=$($MemoryMaximumBytes/1GB)GB" -Level 'SUCCESS'
    } else {
        Set-VMMemory -Name $VMName -DynamicMemoryEnabled $false
    }
}

# --- Phase 3: UEFI Firmware & Secure Boot Configuration ---
Write-LogMessage -Message "Configuring UEFI firmware and Secure Boot..." -Level 'INFO'
if ($PSCmdlet.ShouldProcess($VMName, "Configure UEFI Firmware")) {
    if ($EnableSecureBoot) {
        Set-VMFirmware -Name $VMName -EnableSecureBoot On -SecureBootTemplate $SecureBootTemplate
        Write-LogMessage -Message "Secure Boot enabled using template: $SecureBootTemplate" -Level 'SUCCESS'
    } else {
        Set-VMFirmware -Name $VMName -EnableSecureBoot Off
        Write-LogMessage -Message "Secure Boot disabled." -Level 'WARNING'
    }
}

# --- Phase 4: Virtual DVD Drive & Boot Order ---
if (-not [string]::IsNullOrEmpty($IsoPath)) {
    Write-LogMessage -Message "Attaching installation ISO media: $IsoPath" -Level 'INFO'
    if (Test-Path $IsoPath) {
        if ($PSCmdlet.ShouldProcess($VMName, "Attach DVD Drive with ISO")) {
            $dvd = Add-VMDvdDrive -VMName $VMName -Path $IsoPath -Passthru
            # Set DVD drive as primary boot device for OS setup
            Set-VMFirmware -Name $VMName -FirstBootDevice $dvd
            Write-LogMessage -Message "DVD drive attached with ISO and set as primary boot device." -Level 'SUCCESS'
        }
    } else {
        Write-LogMessage -Message "Specified ISO file does not exist at '$IsoPath'. Skipping DVD attachment." -Level 'WARNING'
    }
}

# --- Phase 5: Provision Dedicated Database SCSI Storage Tier ---
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

    # Ensure SCSI controller exists (Gen 2 VMs have SCSI controller 0 by default)
    $scsiController = Get-VMScsiController -VMName $VMName -ControllerNumber 0 -ErrorAction SilentlyContinue
    if ($null -eq $scsiController) {
        Write-LogMessage -Message "Adding secondary SCSI Controller..." -Level 'INFO'
        $scsiController = Add-VMScsiController -VMName $VMName -Passthru
    }

    $diskOrder = @('Program', 'SystemDB', 'UserData', 'UserLog', 'tempdbData', 'tempdbLog')
    $lunIndex = 1

    foreach ($diskKey in $diskOrder) {
        $diskSize = if ($DatabaseDiskSizes.ContainsKey($diskKey)) { $DatabaseDiskSizes[$diskKey] } else { 30GB }
        $diskPath = Join-Path -Path $vhdTargetDir -ChildPath "$($VMName)_$($diskKey).vhdx"

        if ($PSCmdlet.ShouldProcess($diskPath, "Create VHDX and attach to SCSI Controller 0 (LUN $lunIndex)")) {
            Write-LogMessage -Message "Creating VHDX: $diskKey ($($diskSize / 1GB)GB) -> $diskPath" -Level 'INFO'
            New-VHD -Path $diskPath -SizeBytes $diskSize -Dynamic | Out-Null
            Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation $lunIndex -Path $diskPath

            $clusterAllocation = if ($diskKey -eq 'Program') { "4KB (NTFS Default)" } else { "64KB (SQL Workload Recommended)" }
            $attachedDisks.Add([PSCustomObject]@{
                DiskName   = $diskKey
                Path       = $diskPath
                SizeBytes  = $diskSize
                Controller = "SCSI 0"
                LUN        = $lunIndex
                ClusterKB  = $clusterAllocation
            })
            $lunIndex++
        }
    }
    Write-LogMessage -Message "Database multi-disk SCSI tier configured successfully." -Level 'SUCCESS'
}

# --- Phase 6: Guest Storage Initialization Script Generator ---
# Provide guest administrator script to format database disks with 64KB cluster size
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
    Set-Content -Path $guestScriptPath -Value $guestScriptContent -Encoding UTF8
    Write-LogMessage -Message "In-guest initialization helper generated: $guestScriptPath" -Level 'INFO'
} catch {
    Write-LogMessage -Message "Notice: Could not write guest disk script: $_" -Level 'WARNING'
}

# --- Phase 7: Power Management ---
if ($StartVM) {
    Write-LogMessage -Message "Powering on Virtual Machine '$VMName'..." -Level 'INFO'
    if ($PSCmdlet.ShouldProcess($VMName, "Start-VM")) {
        Start-VM -Name $VMName
        Write-LogMessage -Message "Virtual Machine '$VMName' is running." -Level 'SUCCESS'
    }
}

# --- Phase 8: Deployment Report ---
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
return $vmSummary
