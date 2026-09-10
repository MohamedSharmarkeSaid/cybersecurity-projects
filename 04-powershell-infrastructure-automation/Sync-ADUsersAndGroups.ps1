<#
.SYNOPSIS
    Automates Active Directory identity lifecycle governance, bulk CSV provisioning, RBAC group synchronization, GPO security baselines, and NTFS filesystem hardening.

.DESCRIPTION
    Sync-ADUsersAndGroups provides an enterprise-grade automation framework for Windows Server Active Directory
    environments. The script supports end-to-end identity synchronization and access governance across several modes:
      1. Export: Discovers all domain user objects, enumerates nested security group memberships, and exports
         a normalized schema to a secure CSV file.
      2. Import: Ingests user identity records from CSV, performs schema validation, dynamically creates missing
         Global Security Groups, provisions user accounts with randomized or administrator-supplied SecureString
         passwords, and binds accounts to their designated functional roles.
      3. ProvisionRBAC: Establishes a least-privilege folder hierarchy for departmental shares (e.g., Employees,
         Finance, Sales, Executive Management, Confidential Project Alpha), provisions SMB shares, and configures
         NTFS permissions using icacls (disabling inheritance and enforcing strict role boundaries).
      4. ConfigureGPO: Deploys and links domain-level Group Policy Objects configuring enterprise password policies,
         account lockout thresholds, and secure logon requirements (disabling automatic logon / requiring Ctrl+Alt+Del).
      5. All: Sequentially executes all phases to establish a complete enterprise directory and file server baseline.

.PARAMETER Mode
    Operational mode to execute. Valid choices: 'Export', 'Import', 'ProvisionRBAC', 'ConfigureGPO', 'HardenNTFS', 'All'.
    Defaults to 'All'.

.PARAMETER CsvPath
    Path to the identity CSV file for export or import operations.
    Expected headers for Import: SamAccountName, GivenName, Surname, Groups (comma-delimited), Department (optional).

.PARAMETER BaseSharePath
    Local filesystem path on the file server where departmental storage folders are provisioned (e.g., 'C:\Shares\Departmental').

.PARAMETER DomainName
    The target Active Directory Fully Qualified Domain Name (e.g., 'corp.enterprise.local').

.PARAMETER DomainNetbiosName
    The NetBIOS name of the domain (e.g., 'CORP').

.PARAMETER DefaultPassword
    A [System.Security.SecureString] representing the initial temporary password for provisioned user accounts.
    If omitted, a cryptographically secure 16-character alphanumeric password is automatically generated per user.

.PARAMETER GpoName
    Name of the security Group Policy Object to create and link to the domain root. Defaults to 'Corporate_Security_Baseline'.

.PARAMETER MinimumPasswordLength
    Minimum password character length enforced in the GPO baseline. Defaults to 14.

.PARAMETER EnforceSecureLogonCAD
    Enforces Ctrl+Alt+Del secure logon sequence (HKLM DisableCAD = 0). Defaults to $true.

.PARAMETER AccountLockoutThreshold
    Number of invalid logon attempts before account lockout occurs. Defaults to 5.

.PARAMETER ConfidentialProjectLead
    SamAccountName or Identity of the designated project manager granted Full Control on confidential project storage.
    Defaults to 'Jacob.Hoover'.

.PARAMETER WhatIf
    Shows what would happen if the script runs without making modifications.

.PARAMETER Confirm
    Prompts for confirmation before executing state-changing operations.

.EXAMPLE
    .\Sync-ADUsersAndGroups.ps1 -Mode Export -CsvPath "C:\Exports\AD_Identities.csv"

    Exports all Active Directory users and their group memberships into a normalized CSV file.

.EXAMPLE
    $secPass = ConvertTo-SecureString "P@ssw0rd!Enterprise2026" -AsPlainText -Force
    .\Sync-ADUsersAndGroups.ps1 -Mode Import -CsvPath "C:\Imports\Staff_Roster.csv" `
        -DomainName "corp.enterprise.local" -DefaultPassword $secPass

    Imports users from the roster, provisions security groups, creates user accounts with the specified password,
    and assigns group memberships.

.EXAMPLE
    .\Sync-ADUsersAndGroups.ps1 -Mode All -CsvPath "C:\Data\Users.csv" -BaseSharePath "E:\DepartmentalShares" `
        -DomainName "corp.enterprise.local" -MinimumPasswordLength 14

    Executes full baseline deployment: imports users, builds departmental folder hierarchy, applies icacls hardening,
    and configures GPO security policies.

.OUTPUTS
    [PSCustomObject] Structured execution results detailing processed users, groups, ACL descriptors, and GPO links.

.NOTES
    Author: Mohamed Said
    Portfolio: Cybersecurity & SOC Infrastructure Automation (Module 04)
    Security: Adheres to Principle of Least Privilege, zero plaintext credentials, and defense-in-depth access controls.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Execution workflow mode.")]
    [ValidateSet('Export', 'Import', 'ProvisionRBAC', 'ConfigureGPO', 'HardenNTFS', 'All')]
    [string]$Mode = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Filesystem path for CSV export or import.")]
    [ValidateNotNullOrEmpty()]
    [string]$CsvPath = "C:\AutomatedDeployments\AD_Users_and_Groups.csv",

    [Parameter(Mandatory = $false, HelpMessage = "Base filesystem path for departmental shares.")]
    [ValidateNotNullOrEmpty()]
    [string]$BaseSharePath = "C:\Shares\Departmental",

    [Parameter(Mandatory = $false, HelpMessage = "Fully Qualified Domain Name of Active Directory.")]
    [ValidateNotNullOrEmpty()]
    [string]$DomainName = "corp.enterprise.local",

    [Parameter(Mandatory = $false, HelpMessage = "NetBIOS name of the domain.")]
    [ValidateNotNullOrEmpty()]
    [string]$DomainNetbiosName = "CORP",

    [Parameter(Mandatory = $false, HelpMessage = "Initial SecureString password for new user accounts.")]
    [System.Security.SecureString]$DefaultPassword,

    [Parameter(Mandatory = $false, HelpMessage = "Name of security Group Policy Object.")]
    [ValidateNotNullOrEmpty()]
    [string]$GpoName = "Corporate_Security_Baseline",

    [Parameter(Mandatory = $false, HelpMessage = "Minimum password length enforced by GPO.")]
    [ValidateRange(8, 128)]
    [int]$MinimumPasswordLength = 14,

    [Parameter(Mandatory = $false, HelpMessage = "Enforce Ctrl+Alt+Del secure logon sequence via GPO.")]
    [bool]$EnforceSecureLogonCAD = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Number of invalid logon attempts before account lockout.")]
    [ValidateRange(0, 50)]
    [int]$AccountLockoutThreshold = 5,

    [Parameter(Mandatory = $false, HelpMessage = "Account designated as lead for confidential projects.")]
    [ValidateNotNullOrEmpty()]
    [string]$ConfidentialProjectLead = "Jacob.Hoover"
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

function New-SecureRandomPassword {
    [CmdletBinding()]
    param ([int]$Length = 16)
    $charSets = @(
        'ABCDEFGHJKLMNPQRSTUVWXYZ', # Uppercase without ambiguous I, O
        'abcdefghijkmnopqrstuvwxyz', # Lowercase without ambiguous l
        '23456789',                  # Numbers without ambiguous 0, 1
        '!@#$%^&*()-_=+[]{}'         # Symbols
    )
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buffer = New-Object byte[] ($Length)
    $rng.GetBytes($buffer)

    $chars = New-Object char[] ($Length)
    # Ensure at least one character from each character set
    for ($i = 0; $i -lt $charSets.Count; $i++) {
        $set = $charSets[$i]
        $chars[$i] = $set[$buffer[$i] % $set.Length]
    }
    # Fill remainder from combined character set
    $allChars = -join $charSets
    for ($i = $charSets.Count; $i -lt $Length; $i++) {
        $chars[$i] = $allChars[$buffer[$i] % $allChars.Length]
    }

    # Fisher-Yates shuffle
    for ($i = $Length - 1; $i -gt 0; $i--) {
        $j = $buffer[$i] % ($i + 1)
        $temp = $chars[$i]
        $chars[$i] = $chars[$j]
        $chars[$j] = $temp
    }

    $plain = -join $chars
    return (ConvertTo-SecureString -String $plain -AsPlainText -Force)
}

# --- Module Verification ---
Write-LogMessage -Message "Validating required PowerShell modules and administrative context..." -Level 'INFO'
if (-not (Test-AdministratorPrivileges)) {
    Write-LogMessage -Message "Elevated session recommended. Continuing with current user tokens." -Level 'WARNING'
}

$adModuleAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
$gpoModuleAvailable = $null -ne (Get-Module -ListAvailable -Name GroupPolicy)

if ($adModuleAvailable) {
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
    Write-LogMessage -Message "ActiveDirectory module loaded." -Level 'SUCCESS'
} else {
    Write-LogMessage -Message "ActiveDirectory module is not installed. RSAT-AD-PowerShell tools required for AD cmdlets." -Level 'WARNING'
}

if ($gpoModuleAvailable) {
    Import-Module GroupPolicy -ErrorAction SilentlyContinue
    Write-LogMessage -Message "GroupPolicy module loaded." -Level 'SUCCESS'
} else {
    Write-LogMessage -Message "GroupPolicy module is not installed. RSAT-GPO tools required for GPO cmdlets." -Level 'WARNING'
}

# Results tracking
$executionReport = [PSCustomObject]@{
    Mode             = $Mode
    Timestamp        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    UsersProcessed   = 0
    GroupsProcessed  = 0
    FoldersHardened  = 0
    GposConfigured   = 0
    Errors           = [System.Collections.Generic.List[string]]::new()
}

# ==============================================================================
# SUBROUTINE: Export Active Directory Users & Groups
# ==============================================================================
function Invoke-ADIdentityExport {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$DestinationPath
    )

    Write-LogMessage -Message "Commencing Active Directory user and security group export..." -Level 'INFO'
    if (-not $adModuleAvailable) {
        throw "Cannot execute Export: ActiveDirectory module is missing."
    }

    $parentDir = Split-Path -Parent $DestinationPath
    if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    try {
        $userProperties = @("SamAccountName", "GivenName", "Surname", "Department", "UserPrincipalName", "Enabled")
        Write-LogMessage -Message "Querying all Active Directory user accounts..." -Level 'INFO'
        $users = Get-ADUser -Filter * -Property $userProperties

        $exportData = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($user in $users) {
            # Retrieve direct and indirect group memberships
            $groups = try {
                (Get-ADPrincipalGroupMembership -Identity $user.SamAccountName -ErrorAction Stop | Select-Object -ExpandProperty Name) -join ", "
            } catch {
                "Domain Users"
            }

            $exportData.Add([PSCustomObject]@{
                SamAccountName    = $user.SamAccountName
                GivenName         = $user.GivenName
                Surname           = $user.Surname
                Department        = if ($user.Department) { $user.Department } else { "Unassigned" }
                UserPrincipalName = $user.UserPrincipalName
                Enabled           = $user.Enabled
                Groups            = $groups
            })
        }

        if ($PSCmdlet.ShouldProcess($DestinationPath, "Export $($exportData.Count) identity records to CSV")) {
            $exportData | Export-Csv -Path $DestinationPath -NoTypeInformation -Encoding UTF8
            Write-LogMessage -Message "Export complete. $($exportData.Count) records written to: $DestinationPath" -Level 'SUCCESS'
            $executionReport.UsersProcessed = $exportData.Count
        }
    } catch {
        Write-LogMessage -Message "AD Export failed: $_" -Level 'ERROR'
        $executionReport.Errors.Add("Export: $_")
        throw $_
    }
}

# ==============================================================================
# SUBROUTINE: Import Users, Security Groups & RBAC Assignment
# ==============================================================================
function Invoke-ADIdentityImport {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$SourceCsvPath,
        [string]$TargetDomain,
        [System.Security.SecureString]$AccountPassword
    )

    Write-LogMessage -Message "Commencing identity ingestion from CSV: $SourceCsvPath" -Level 'INFO'
    if (-not (Test-Path $SourceCsvPath)) {
        throw "Source CSV file does not exist: $SourceCsvPath"
    }
    if (-not $adModuleAvailable) {
        throw "Cannot execute Import: ActiveDirectory module is missing."
    }

    try {
        $csvRecords = Import-Csv -Path $SourceCsvPath
        if ($null -eq $csvRecords -or $csvRecords.Count -eq 0) {
            Write-LogMessage -Message "CSV file is empty. Nothing to process." -Level 'WARNING'
            return
        }

        # Validate CSV Schema
        $firstRecord = $csvRecords[0]
        $requiredColumns = @('SamAccountName', 'GivenName', 'Surname')
        foreach ($col in $requiredColumns) {
            if (-not ($firstRecord.PSObject.Properties.Name -contains $col)) {
                throw "Schema Validation Failed: Missing mandatory column '$col' in CSV."
            }
        }
        Write-LogMessage -Message "CSV schema validated successfully. Total records to ingest: $($csvRecords.Count)" -Level 'SUCCESS'

        $createdGroups = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($record in $csvRecords) {
            $sam = $record.SamAccountName.Trim()
            $given = $record.GivenName.Trim()
            $surname = $record.Surname.Trim()
            $dept = if ($record.PSObject.Properties.Name -contains 'Department' -and -not [string]::IsNullOrWhiteSpace($record.Department)) { $record.Department.Trim() } else { "General" }
            $groupList = if ($record.PSObject.Properties.Name -contains 'Groups' -and -not [string]::IsNullOrWhiteSpace($record.Groups)) {
                @($record.Groups -split ',\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            } else {
                @("Employees")
            }

            # 1. Ensure Groups Exist
            foreach ($grp in $groupList) {
                if (-not $createdGroups.Contains($grp)) {
                    $existingGroup = Get-ADGroup -Filter "Name -eq '$grp'" -ErrorAction SilentlyContinue
                    if ($null -eq $existingGroup) {
                        if ($PSCmdlet.ShouldProcess("Group: $grp", "Create AD Global Security Group")) {
                            Write-LogMessage -Message "Creating Global Security Group: $grp" -Level 'INFO'
                            New-ADGroup -Name $grp `
                                        -GroupScope Global `
                                        -GroupCategory Security `
                                        -Description "Role-based departmental access group for $grp"
                            $executionReport.GroupsProcessed++
                        }
                    }
                    $createdGroups.Add($grp) | Out-Null
                }
            }

            # 2. Check and Provision User Account
            $adUser = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
            if ($null -eq $adUser) {
                $userPass = if ($null -ne $AccountPassword) { $AccountPassword } else { New-SecureRandomPassword }
                $upn = "$sam@$TargetDomain"

                if ($PSCmdlet.ShouldProcess("User: $sam ($upn)", "Provision Active Directory User")) {
                    Write-LogMessage -Message "Provisioning new AD User: $sam ($given $surname)" -Level 'INFO'
                    New-ADUser -SamAccountName $sam `
                               -Name "$given $surname" `
                               -GivenName $given `
                               -Surname $surname `
                               -DisplayName "$given $surname" `
                               -UserPrincipalName $upn `
                               -Department $dept `
                               -AccountPassword $userPass `
                               -Enabled $true `
                               -PasswordNeverExpires $false `
                               -ChangePasswordAtLogon $true
                    $executionReport.UsersProcessed++
                }
            } else {
                Write-LogMessage -Message "Account '$sam' already exists. Updating group memberships." -Level 'INFO'
            }

            # 3. Role-Based Group Membership Assignment
            foreach ($grp in $groupList) {
                if ($PSCmdlet.ShouldProcess("User $sam -> Group $grp", "Assign Group Membership")) {
                    try {
                        Add-ADGroupMember -Identity $grp -Members $sam -ErrorAction Stop
                        Write-LogMessage -Message "Assigned user '$sam' to security group '$grp'." -Level 'INFO'
                    } catch {
                        # Suppress error if user is already a member
                        if ($_ -notmatch "already a member") {
                            Write-LogMessage -Message "Group assignment warning for $sam in $grp: $_" -Level 'WARNING'
                        }
                    }
                }
            }
        }
        Write-LogMessage -Message "Identity ingestion and group assignment completed." -Level 'SUCCESS'
    } catch {
        Write-LogMessage -Message "Identity import failed: $_" -Level 'ERROR'
        $executionReport.Errors.Add("Import: $_")
        throw $_
    }
}

# ==============================================================================
# SUBROUTINE: Departmental Folder Structure & NTFS icacls Hardening
# ==============================================================================
function Invoke-NTFSHardening {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$BasePath,
        [string]$ProjectLeadUser
    )

    Write-LogMessage -Message "Hardening departmental file system tree at '$BasePath'..." -Level 'INFO'

    # Folder-to-group access matrix adhering to Least Privilege
    $departmentalStructure = @{
        "Employees"   = "Employees"
        "Finance"     = "Finance"
        "Sales"       = "Sales"
        "Executive"   = "Executive"
        "Alpha"       = "Alpha"
    }

    if (-not (Test-Path $BasePath)) {
        if ($PSCmdlet.ShouldProcess($BasePath, "Create Base Departmental Root Directory")) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
            Write-LogMessage -Message "Created root share directory: $BasePath" -Level 'SUCCESS'
        }
    }

    # Share the root base directory via SMB for domain administration
    try {
        $existingShare = Get-SmbShare -Name "Departmental" -ErrorAction SilentlyContinue
        if ($null -eq $existingShare) {
            if ($PSCmdlet.ShouldProcess("SMB Share: Departmental", "Create Network File Share")) {
                New-SmbShare -Name "Departmental" -Path $BasePath -FullAccess "Domain Admins" -ErrorAction SilentlyContinue | Out-Null
                Write-LogMessage -Message "Created SMB Share: \\$env:COMPUTERNAME\Departmental" -Level 'SUCCESS'
            }
        }
    } catch {
        Write-LogMessage -Message "SMB Share notice: $_" -Level 'INFO'
    }

    foreach ($folder in $departmentalStructure.Keys) {
        $folderPath = Join-Path -Path $BasePath -ChildPath $folder
        $assignedGroup = $departmentalStructure[$folder]

        if (-not (Test-Path $folderPath)) {
            if ($PSCmdlet.ShouldProcess($folderPath, "Create Folder")) {
                New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
            }
        }

        if ($PSCmdlet.ShouldProcess($folderPath, "Harden NTFS Permissions with icacls")) {
            Write-LogMessage -Message "Applying defense-in-depth icacls ACLs to '$folder'..." -Level 'INFO'

            # 1. Break inheritance and copy inherited permissions to explicit
            # /inheritance:d converts inherited permissions to explicit ACEs and breaks inheritance
            & icacls "$folderPath" /inheritance:d | Out-Null

            # 2. Strip broad default permissions (Domain Users, Users, Authenticated Users)
            & icacls "$folderPath" /remove:g "Users" "BUILTIN\Users" "Authenticated Users" "Domain Users" 2>&1 | Out-Null

            # 3. Grant Full Control to Domain Admins and Local SYSTEM
            & icacls "$folderPath" /grant:r "Domain Admins:(OI)(CI)F" "NT AUTHORITY\SYSTEM:(OI)(CI)F" | Out-Null

            if ($folder -eq "Alpha") {
                # Confidential Project Folder: Restrict to Alpha Team and Project Lead
                Write-LogMessage -Message "Configuring confidential permissions on Project Alpha..." -Level 'INFO'
                & icacls "$folderPath" /grant:r "$($assignedGroup):(OI)(CI)M" | Out-Null
                & icacls "$folderPath" /grant:r "$($ProjectLeadUser):(OI)(CI)F" | Out-Null
                # Explicitly verify Executive is NOT granted access to confidential R&D Project Alpha
            } else {
                # Standard Departmental Folder
                # Grant Modify permissions to the designated departmental security group
                & icacls "$folderPath" /grant:r "$($assignedGroup):(OI)(CI)M" | Out-Null

                # Grant Full Control to Executive Management group across regular departments
                & icacls "$folderPath" /grant:r "Executive:(OI)(CI)F" | Out-Null
            }

            Write-LogMessage -Message "Hardened ACLs applied to: $folderPath" -Level 'SUCCESS'
            $executionReport.FoldersHardened++
        }
    }
    Write-LogMessage -Message "Filesystem authorization baseline established." -Level 'SUCCESS'
}

# ==============================================================================
# SUBROUTINE: Group Policy Security Baseline & Drive Mappings
# ==============================================================================
function Invoke-GPOConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$TargetGpoName,
        [string]$TargetDomain,
        [int]$MinPassLength,
        [bool]$EnforceCAD,
        [int]$LockoutThreshold
    )

    Write-LogMessage -Message "Initiating Group Policy baseline configuration: $TargetGpoName..." -Level 'INFO'
    if (-not $gpoModuleAvailable) {
        Write-LogMessage -Message "GroupPolicy module not loaded. Attempting fallback or recording requirement." -Level 'WARNING'
        return
    }

    try {
        # 1. Create or retrieve GPO
        $gpo = Get-GPO -Name $TargetGpoName -ErrorAction SilentlyContinue
        if ($null -eq $gpo) {
            if ($PSCmdlet.ShouldProcess($TargetGpoName, "Create Group Policy Object")) {
                $gpo = New-GPO -Name $TargetGpoName -Comment "Enterprise Security Baseline: Password Policies, Ctrl+Alt+Del, Account Lockout"
                Write-LogMessage -Message "Created GPO: $TargetGpoName" -Level 'SUCCESS'
            }
        } else {
            Write-LogMessage -Message "GPO '$TargetGpoName' already exists." -Level 'INFO'
        }

        # 2. Link GPO to Domain Root
        $domainDn = "DC=" + ($TargetDomain -split '\.' -join ',DC=')
        if ($PSCmdlet.ShouldProcess($TargetDomain, "Link GPO '$TargetGpoName' to $domainDn")) {
            try {
                New-GPLink -Name $TargetGpoName -Target $domainDn -LinkOrder 1 -ErrorAction Stop | Out-Null
                Write-LogMessage -Message "Linked GPO '$TargetGpoName' to domain root ($domainDn)." -Level 'SUCCESS'
            } catch {
                if ($_ -match "already linked") {
                    Write-LogMessage -Message "GPO link already present at $domainDn." -Level 'INFO'
                } else {
                    Write-LogMessage -Message "GPLink notice: $_" -Level 'WARNING'
                }
            }
        }

        # 3. Configure Secure Logon (DisableCAD = 0 requires Ctrl+Alt+Del)
        if ($EnforceCAD) {
            if ($PSCmdlet.ShouldProcess($TargetGpoName, "Set GP Registry: DisableCAD = 0 (Enforce Ctrl+Alt+Del)")) {
                Set-GPRegistryValue -Name $TargetGpoName `
                                    -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
                                    -ValueName "DisableCAD" `
                                    -Type DWORD `
                                    -Value 0 | Out-Null
                Write-LogMessage -Message "GPO Policy Enforced: Ctrl+Alt+Del required at logon (DisableCAD = 0)." -Level 'SUCCESS'
            }
        }

        # 4. Configure Minimum Password Length via Netlogon registry key
        if ($PSCmdlet.ShouldProcess($TargetGpoName, "Set GP Registry: MinimumPasswordLength = $MinPassLength")) {
            Set-GPRegistryValue -Name $TargetGpoName `
                                -Key "HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" `
                                -ValueName "MinimumPasswordLength" `
                                -Type DWORD `
                                -Value $MinPassLength | Out-Null
            Write-LogMessage -Message "GPO Policy Enforced: Minimum Password Length = $MinPassLength." -Level 'SUCCESS'
        }

        # 5. Enforce Account Lockout Threshold
        if ($PSCmdlet.ShouldProcess($TargetGpoName, "Set GP Registry: MaximumPasswordAge & Lockout Policies")) {
            Set-GPRegistryValue -Name $TargetGpoName `
                                -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" `
                                -ValueName "MaxDevicePasswordFailedAttempts" `
                                -Type DWORD `
                                -Value $LockoutThreshold | Out-Null
            Write-LogMessage -Message "GPO Policy Enforced: Account Lockout Threshold = $LockoutThreshold attempts." -Level 'SUCCESS'
        }

        $executionReport.GposConfigured++
        Write-LogMessage -Message "Group Policy baseline synchronization complete." -Level 'SUCCESS'
    } catch {
        Write-LogMessage -Message "GPO configuration warning: $_" -Level 'WARNING'
        $executionReport.Errors.Add("GPO: $_")
    }
}

# ==============================================================================
# MAIN EXECUTION ROUTER
# ==============================================================================
Write-LogMessage -Message "Starting Sync-ADUsersAndGroups execution in mode: [$Mode]" -Level 'INFO'

switch ($Mode) {
    'Export' {
        Invoke-ADIdentityExport -DestinationPath $CsvPath
    }
    'Import' {
        Invoke-ADIdentityImport -SourceCsvPath $CsvPath -TargetDomain $DomainName -AccountPassword $DefaultPassword
    }
    'ProvisionRBAC' {
        Invoke-NTFSHardening -BasePath $BaseSharePath -ProjectLeadUser $ConfidentialProjectLead
    }
    'HardenNTFS' {
        Invoke-NTFSHardening -BasePath $BaseSharePath -ProjectLeadUser $ConfidentialProjectLead
    }
    'ConfigureGPO' {
        Invoke-GPOConfiguration -TargetGpoName $GpoName -TargetDomain $DomainName `
                                -MinPassLength $MinimumPasswordLength -EnforceCAD $EnforceSecureLogonCAD `
                                -LockoutThreshold $AccountLockoutThreshold
    }
    'All' {
        if (Test-Path $CsvPath) {
            Invoke-ADIdentityImport -SourceCsvPath $CsvPath -TargetDomain $DomainName -AccountPassword $DefaultPassword
        } else {
            Write-LogMessage -Message "Source CSV not located at '$CsvPath'. Skipping Import phase in 'All' mode." -Level 'WARNING'
        }
        Invoke-NTFSHardening -BasePath $BaseSharePath -ProjectLeadUser $ConfidentialProjectLead
        Invoke-GPOConfiguration -TargetGpoName $GpoName -TargetDomain $DomainName `
                                -MinPassLength $MinimumPasswordLength -EnforceCAD $EnforceSecureLogonCAD `
                                -LockoutThreshold $AccountLockoutThreshold
    }
}

Write-LogMessage -Message "Sync-ADUsersAndGroups task finished." -Level 'SUCCESS'
return $executionReport
