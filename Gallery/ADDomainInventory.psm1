<#
.SYNOPSIS
 Active Directory & Domain Member PC Inventory Module
.DESCRIPTION
 Collects comprehensive domain and endpoint information for assessment and reporting.
#>

# ==============================
# 共通ユーティリティ
# ==============================
function Write-Diag {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO","WARN","ERROR")][string]$Level = "INFO"
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts [$Level] $Message"
}

# ==============================
# AD / ドメイン系
# ==============================
function Get-ADForestInfo {
    [CmdletBinding()]
    param()
    Get-ADForest
}

function Get-ADDomainInfo {
    [CmdletBinding()]
    param()
    Get-ADDomain
}

function Get-ADDomainControllers {
    [CmdletBinding()]
    param()
    Get-ADDomainController -Filter *
}

function Get-ADUsersInventory {
    [CmdletBinding()]
    param()
    Get-ADUser -Filter * -Properties DisplayName, Enabled, LastLogonDate, PasswordLastSet, MemberOf
}

function Get-ADGroupsInventory {
    [CmdletBinding()]
    param()
    Get-ADGroup -Filter * -Properties GroupScope, GroupCategory, Members
}

function Get-ADComputersInventory {
    [CmdletBinding()]
    param()
    Get-ADComputer -Filter * -Properties OperatingSystem, OperatingSystemVersion, LastLogonDate
}

function Get-GroupPolicyInventory {
    [CmdletBinding()]
    param()
    Get-GPO -All
}

function Get-ADPasswordPolicy {
    [CmdletBinding()]
    param()
    Get-ADDefaultDomainPasswordPolicy
}

function Get-ADTrusts {
    [CmdletBinding()]
    param()
    Get-ADTrust -Filter *
}

function Get-ADReplicationInfo {
    [CmdletBinding()]
    param()
    Get-ADReplicationPartnerMetadata -Target * | Select-Object Server, LastReplicationSuccess, LastReplicationResult
}

# ==============================
# ドメインコントローラ単位の収集
# ==============================
function Get-DCInventory {
    [CmdletBinding()]
    param(
        [string[]]$DCNames,
        [switch]$IncludeGPO,
        [switch]$IncludeSysVol,
        [switch]$IncludeDNS,
        [switch]$IncludeServiceStatus
    )

    foreach ($dc in $DCNames) {
        Write-Diag "Collecting info from $dc"
        $result = [ordered]@{
            DCName    = $dc
            OS        = (Get-CimInstance Win32_OperatingSystem -ComputerName $dc).Caption
            Roles     = (Get-WindowsFeature -ComputerName $dc | Where-Object Installed).Name
        }

        if ($IncludeGPO) { $result.GPOs = Get-GPO -All }
        if ($IncludeSysVol) { $result.SysVol = Get-ChildItem "\\$dc\SYSVOL" -Recurse -ErrorAction SilentlyContinue }
        if ($IncludeDNS) { $result.DNSZones = Get-DnsServerZone -ComputerName $dc -ErrorAction SilentlyContinue }
        if ($IncludeServiceStatus) { $result.Services = Get-Service -ComputerName $dc }

        [pscustomobject]$result
    }
}

# ==============================
# メンバPC系
# ==============================
function Get-InstalledApps {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Credential()]$Credential = $null
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        $keys = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        $apps = foreach ($k in $keys) {
            Get-ItemProperty $k -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName } |
                Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
        }
        return $apps
    }
}

function Get-InstalledHotFixes {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Credential()]$Credential = $null
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        Get-HotFix | Select-Object HotFixID, Description, InstalledOn
    }
}

function Get-LocalUserAndGroups {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Credential()]$Credential = $null
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        @{
            LocalUsers  = Get-LocalUser | Select-Object Name, Enabled, LastLogon
            LocalGroups = Get-LocalGroup | Select-Object Name
        }
    }
}

function Get-LocalAdmins {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Credential()]$Credential = $null
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        Get-LocalGroupMember -Group "Administrators" |
            Select-Object Name, ObjectClass, PrincipalSource
    }
}

function Get-ComputerInfoInventory {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Credential()]$Credential = $null
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        @{
            OS      = (Get-CimInstance Win32_OperatingSystem).Caption
            CPU     = (Get-CimInstance Win32_Processor).Name
            Memory  = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
            Disks   = Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace
        }
    }
}

function Get-RunningServices {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Credential()]$Credential = $null
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        Get-Service | Select-Object Name, Status, DisplayName
    }
}

function Get-StartupPrograms {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Credential()]$Credential = $null
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User
    }
}

function Get-NetworkConfig {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Credential()]$Credential = $null
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, DNSServer, IPv4DefaultGateway
    }
}

function Get-ComputerCertificates {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Credential()]$Credential = $null
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        Get-ChildItem Cert:\LocalMachine\My | Select-Object Subject, Issuer, NotAfter
    }
}

# ==============================
# メンバPC単位の収集
# ==============================
function Get-MemberPCInventory {
    [CmdletBinding()]
    param(
        [string[]]$PCNames,
        [switch]$IncludeApps,
        [switch]$IncludeHotFix,
        [switch]$IncludeLocalAdmins,
        [switch]$IncludeLocalUsers,
        [switch]$IncludeServices,
        [switch]$IncludeStartup,
        [switch]$IncludeNetwork,
        [switch]$IncludeCertificates
    )

    foreach ($pc in $PCNames) {
        Write-Diag "Collecting inventory from $pc"
        $result = [ordered]@{
            PCName = $pc
            OSInfo = Get-ComputerInfoInventory -ComputerName $pc
        }

        if ($IncludeApps) { $result.Apps = Get-InstalledApps -ComputerName $pc }
        if ($IncludeHotFix) { $result.HotFixes = Get-InstalledHotFixes -ComputerName $pc }
        if ($IncludeLocalAdmins) { $result.LocalAdmins = Get-LocalAdmins -ComputerName $pc }
        if ($IncludeLocalUsers) { $result.LocalUsersAndGroups = Get-LocalUserAndGroups -ComputerName $pc }
        if ($IncludeServices) { $result.Services = Get-RunningServices -ComputerName $pc }
        if ($IncludeStartup) { $result.Startup = Get-StartupPrograms -ComputerName $pc }
        if ($IncludeNetwork) { $result.Network = Get-NetworkConfig -ComputerName $pc }
        if ($IncludeCertificates) { $result.Certificates = Get-ComputerCertificates -ComputerName $pc }

        [pscustomobject]$result
    }
}
