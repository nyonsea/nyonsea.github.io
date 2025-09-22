# ===============================
# InfraUtility.psm1 - Complete Infrastructure Utility Module
# ===============================

# =========================================
# Active Directory Management
# =========================================

function Get-ADUserList { Get-ADUser -Filter * }
function Get-ADGroupList { Get-ADGroup -Filter * }
function Add-ADUserToGroup { param($User,$Group); Add-ADGroupMember -Identity $Group -Members $User }
function Remove-ADUserFromGroup { param($User,$Group); Remove-ADGroupMember -Identity $Group -Members $User }

# AD管理 Part2
function Get-ADUserByOU { param($OU); Get-ADUser -SearchBase $OU -Filter * }
function Move-ADUser { param($User,$TargetOU); Move-ADObject -Identity $User -TargetPath $TargetOU }
function Enable-ADUser { param($User); Enable-ADAccount -Identity $User }
function Disable-ADUser { param($User); Disable-ADAccount -Identity $User }
function Set-ADUserPassword { param($User,$Password); Set-ADAccountPassword -Identity $User -Reset -NewPassword (ConvertTo-SecureString $Password -AsPlainText -Force) }
function Unlock-ADUser { param($User); Unlock-ADAccount -Identity $User }
function Get-ADComputerList { Get-ADComputer -Filter * }
function Move-ADComputer { param($Computer,$TargetOU); Move-ADObject -Identity $Computer -TargetPath $TargetOU }
function Get-ADGroupMembers { param($Group); Get-ADGroupMember -Identity $Group }
function Remove-ADGroupMembers { param($Group,$Members); Remove-ADGroupMember -Identity $Group -Members $Members -Confirm:$false }
function Add-ADGroupMembers { param($Group,$Members); Add-ADGroupMember -Identity $Group -Members $Members }

# =========================================
# DNS / DHCP Management
# =========================================

function Get-DnsRecord { param($Zone,$Name); Get-DnsServerResourceRecord -ZoneName $Zone -Name $Name }
function Add-DnsRecord { param($Zone,$Name,$IP); Add-DnsServerResourceRecordA -ZoneName $Zone -Name $Name -IPv4Address $IP }
function Remove-DnsRecord { param($Zone,$Name); Remove-DnsServerResourceRecord -ZoneName $Zone -Name $Name -Force }
function Get-DhcpScope { Get-DhcpServerv4Scope }
function Add-DhcpReservation { param($ScopeID,$IP,$Name,$Mac); Add-DhcpServerv4Reservation -ScopeId $ScopeID -IPAddress $IP -ClientId $Mac -Name $Name }
function Remove-DhcpReservation { param($ScopeID,$IP); Remove-DhcpServerv4Reservation -ScopeId $ScopeID -IPAddress $IP -Force }

# =========================================
# Security (GPO / Certificate / Audit)
# =========================================

function Get-GpoList { Get-GPO -All }
function Backup-Gpo { param($Name,$Path); Backup-GPO -Name $Name -Path $Path }
function Restore-Gpo { param($BackupPath); Restore-GPO -Path $BackupPath -TargetName (Get-ChildItem $BackupPath).Name }
function Get-CertificateList { Get-ChildItem -Path Cert:\LocalMachine\My }
function Import-Certificate { param($Path); Import-Certificate -FilePath $Path -CertStoreLocation Cert:\LocalMachine\My }
function Export-CertificateFile { param($Thumbprint,$Path); Export-Certificate -Cert (Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -eq $Thumbprint}) -FilePath $Path }
function Enable-FileAudit { param([string]$Path); $acl=Get-Acl $Path; $audit=New-Object System.Security.AccessControl.FileSystemAuditRule("Everyone","ReadData","None","None","Success"); $acl.AddAuditRule($audit); Set-Acl $Path $acl }

# =========================================
# OS / Server Maintenance
# =========================================

function Get-ServerInfo { Get-ComputerInfo | Select CsName, WindowsProductName, WindowsVersion, OsArchitecture, CsManufacturer, CsModel }
function Get-Uptime { (Get-Date) - (gcim Win32_OperatingSystem).LastBootUpTime }
function Get-LoggedOnUsers { quser | ForEach-Object { ($_ -split '\s{2,}')[0..2] -join ',' } }
function Get-ServiceStatus { param($ServiceName="*"); Get-Service -Name $ServiceName | Select Name,DisplayName,Status }
function Start-ServiceByName { param($ServiceName); Start-Service -Name $ServiceName -ErrorAction Stop }
function Stop-ServiceByName { param($ServiceName); Stop-Service -Name $ServiceName -Force -ErrorAction Stop }
function Get-InstalledUpdates { Get-HotFix | Select HotFixID,InstalledOn,Description }
function Get-PendingUpdates { if(-not (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue)){throw "PSWindowsUpdate モジュール必要"}; Get-WindowsUpdate }
function Install-PendingUpdates { if(-not (Get-Command Install-WindowsUpdate -ErrorAction SilentlyContinue)){throw "PSWindowsUpdate モジュール必要"}; Install-WindowsUpdate -AcceptAll -AutoReboot }
function Get-CPUUsage { Get-Counter '\Processor(_Total)\% Processor Time' | Select -ExpandProperty CounterSamples | Select CookedValue }
function Get-MemoryUsage { Get-Counter '\Memory\Available MBytes' | Select -ExpandProperty CounterSamples | Select CookedValue }
function Get-DiskUsage { Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select DeviceID,@{n="Size(GB)";e={[math]::Round($_.Size/1GB,2)}},@{n="Free(GB)";e={[math]::Round($_.FreeSpace/1GB,2)}} }
function Restart-Server { param($Delay=10); Restart-Computer -Force -Delay $Delay }
function Stop-Server { param($Delay=10); Stop-Computer -Force -Delay $Delay }

# =========================================
# Network Diagnostic / Configuration
# =========================================

function Test-HostPing { param($HostName); Test-Connection -ComputerName $HostName -Count 4 -ErrorAction SilentlyContinue }
function Test-TcpPort { param($HostName,$Port); Test-NetConnection -ComputerName $HostName -Port $Port }
function Resolve-HostName { param($HostName); Resolve-DnsName -Name $HostName -ErrorAction Stop }
function Get-NicStatus { Get-NetAdapter | Select Name,InterfaceDescription,Status,MacAddress,LinkSpeed }
function Get-RoutingTable { Get-NetRoute | Select DestinationPrefix,NextHop,InterfaceAlias,RouteMetric }
function Set-StaticIPAddress { param($InterfaceAlias,$IPAddress,$PrefixLength,$Gateway); New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction Stop }
function Set-DhcpIPAddress { param($InterfaceAlias); Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Enabled -ErrorAction Stop; Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses }
function Set-DnsServerAddress { param($InterfaceAlias,$DNSServers); Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers }
function Get-DnsServerAddress { Get-DnsClientServerAddress | Select InterfaceAlias,ServerAddresses }
function Enable-NetworkAdapter { param($InterfaceAlias); Enable-NetAdapter -Name $InterfaceAlias -Confirm:$false }
function Disable-NetworkAdapter { param($InterfaceAlias); Disable-NetAdapter -Name $InterfaceAlias -Confirm:$false }
function Get-ArpTable { arp -a }
function Get-PublicIPAddress { try{Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -UseBasicParsing | Select-Object -ExpandProperty ip}catch{Write-Warning "取得失敗"} }
function Get-FirewallRules { Get-NetFirewallRule | Select DisplayName,Direction,Action,Enabled,Profile }
function Add-FirewallRule { param($Name,$Direction="Inbound",$Protocol="TCP",$Port,$Action="Allow"); New-NetFirewallRule -DisplayName $Name -Direction $Direction -Protocol $Protocol -LocalPort $Port -Action $Action -Enabled True }

# =========================================
# Backup / Log Management
# =========================================

function Backup-Folder { param($Source,$Destination); robocopy $Source $Destination /MIR /R:2 /W:2 /NFL /NDL }
function Backup-ToZip { param($SourcePath,$DestinationZip); Compress-Archive -Path $SourcePath -DestinationPath $DestinationZip -Force }
function Restore-FromZip { param($ZipPath,$DestinationPath); Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force }
function Backup-UserProfile { param($UserName,$Destination); robocopy "C:\Users\$UserName" $Destination /E /R:2 /W:2 }
function Backup-SystemState { wbadmin start systemstatebackup -backupTarget:E: -quiet }
function Get-EventLogEntries { param($LogName="System",$MaxEvents=100); Get-EventLog -LogName $LogName -Newest $MaxEvents }
function Export-EventLogFile { param($LogName,$Destination); wevtutil epl $LogName $Destination }
function Clear-EventLogFile { param($LogName); wevtutil cl $LogName }
function Get-ErrorEvents { param($LogName="System",$MaxEvents=100); Get-WinEvent -LogName $LogName -MaxEvents $MaxEvents | Where-Object {$_.LevelDisplayName -eq "Error"} }
function Get-FailedLogons { Get-WinEvent -LogName Security | Where-Object {$_.Id -eq 4625} | Select-Object TimeCreated,@{n="User";e={$_.Properties[5].Value}},@{n="SourceIP";e={$_.Properties[18].Value}} }
function Get-LogByDate { param($LogName="System",$Since); Get-WinEvent -LogName $LogName | Where-Object { $_.TimeCreated -ge $Since } }
function Search-EventLog { param($LogName="Application",$Keyword); Get-WinEvent -LogName $LogName | Where-Object { $_.Message -like "*$Keyword*" } }
function Get-LogStatistics { param($LogName="System",$MaxEvents=1000); Get-WinEvent -LogName $LogName -MaxEvents $MaxEvents | Group-Object LevelDisplayName | Select Name,Count }
function Get-LatestCriticalEvent { Get-WinEvent -LogName System -MaxEvents 50 | Where-Object { $_.LevelDisplayName -eq "Critical" } | Select-Object -First 1 }
function Get-ServiceEvents { param($ServiceName,$MaxEvents=200); Get-WinEvent -LogName System -MaxEvents $MaxEvents | Where-Object { $_.Message -like "*$ServiceName*" } }

# =========================================
# File Server Management
# =========================================

function New-FileShare { param($Path,$Name,$Description=""); New-SmbShare -Name $Name -Path $Path -Description $Description -FullAccess "Administrators" }
function Remove-FileShare { param($Name); Remove-SmbShare -Name $Name -Force }
function Get-FileShares { Get-SmbShare | Where-Object {$_.Name -notin "ADMIN$","IPC$","C$"} }
function Add-NTFSPermission { param($Path,$Identity,$Rights="Modify"); $acl=Get-Acl $Path; $rule=New-Object System.Security.AccessControl.FileSystemAccessRule($Identity,$Rights,"ContainerInherit,ObjectInherit","None","Allow"); $acl.AddAccessRule($rule); Set-Acl $Path $acl }
function Remove-NTFSPermission { param($Path,$Identity); $acl=Get-Acl $Path; $acl.Access | Where-Object {$_.IdentityReference -eq $Identity} | ForEach-Object {$acl.RemoveAccessRule($_)}; Set-Acl $Path $acl }
function Get-NTFSPermissions { param($Path); (Get-Acl $Path).Access }
function Grant-SharePermission { param($ShareName,$Account,$AccessRight="Full"); Grant-SmbShareAccess -Name $ShareName -AccountName $Account -AccessRight $AccessRight -Force }
function Revoke-SharePermission { param($ShareName,$Account); Revoke-SmbShareAccess -Name $ShareName -AccountName $Account -Force }
function New-FolderQuota { param($Path,$SizeMB); New-FsrmQuota -Path $Path -Size ($SizeMB*1MB) -SoftLimit $false }
function Remove-FolderQuota { param($Path); Remove-FsrmQuota -Path $Path -Confirm:$false }
function Get-FolderQuotas { Get-FsrmQuota }
function Get-DuplicateFiles { param($Path); Get-ChildItem -Path $Path -Recurse -File | Get-FileHash -Algorithm MD5 | Group-Object Hash | Where-Object {$_.Count -gt 1} }
function Get-LargeFiles { param($Path,$SizeMB=100); Get-ChildItem -Path $Path -Recurse -File | Where-Object {($_.Length/1MB) -ge $SizeMB} | Select-Object FullName,@{n="SizeMB";e={[math]::Round($_.Length/1MB,2)}} }
function Get-FileShareAccessLogs { Get-WinEvent -LogName "Microsoft-Windows-SMBServer/Audit" -MaxEvents 50 | Select TimeCreated,Id,Message }

# =========================================
# Cloud Integration (Azure AD / OneDrive / SharePoint)
# =========================================

function Get-AzureADUsers { Connect-MgGraph -Scopes "User.Read.All"; Get-MgUser -All }
function New-AzureADUser { param($UserPrincipalName,$DisplayName,$Password); Connect-MgGraph -Scopes "User.ReadWrite.All"; New-MgUser -UserPrincipalName $UserPrincipalName -DisplayName $DisplayName -PasswordProfile @{ForceChangePasswordNextSignIn=$true;Password=$Password} -AccountEnabled:$true }
function Get-AzureADGroups { Connect-MgGraph -Scopes "Group.Read.All"; Get-MgGroup -All }
function Add-AzureADUserToGroup { param($UserId,$GroupId); Connect-MgGraph -Scopes "GroupMember.ReadWrite.All"; Add-MgGroupMember -GroupId $GroupId -DirectoryObjectId $UserId }
function Remove-AzureADUserFromGroup { param($UserId,$GroupId); Connect-MgGraph -Scopes "GroupMember.ReadWrite.All"; Remove-MgGroupMember -GroupId $GroupId -DirectoryObjectId $UserId }

function Get-OneDriveUsage { Connect-MgGraph -Scopes "Reports.Read.All"; Get-MgReportOffice365OneDriveUsageAccountDetail -Period D7 }
function Get-OneDriveSyncStatus { param($UserPrincipalName); Connect-MgGraph -Scopes "Reports.Read.All"; Get-MgReportOneDriveActivityUserDetail -Period D7 | Where-Object {$_.UserPrincipalName -eq $UserPrincipalName} }
function Get-OneDriveFolderPermissions { param($UserPrincipalName); Connect-PnPOnline -Url "https://<TenantName>-my.sharepoint.com/personal/$($UserPrincipalName.Replace('@','_').Replace('.','_'))" -Interactive; Get-PnPFolderItem -Folder "/" | ForEach-Object { Get-PnPProperty -ClientObject $_ -Property "ListItemAllFields" } }
function Grant-OneDriveFolderAccess { param($UserPrincipalName,$TargetUser,$Role="Edit"); Connect-PnPOnline -Url "https://<TenantName>-my.sharepoint.com/personal/$($UserPrincipalName.Replace('@','_').Replace('.','_'))" -Interactive; Add-PnPFolderPermission -Identity "/" -User $TargetUser -AddRole $Role }
function Revoke-OneDriveFolderAccess { param($UserPrincipalName,$TargetUser); Connect-PnPOnline -Url "https://<TenantName>-my.sharepoint.com/personal/$($UserPrincipalName.Replace('@','_').Replace('.','_'))" -Interactive; Remove-PnPFolderPermission -Identity "/" -User $TargetUser }

function Get-SharePointSites { Connect-PnPOnline -Url "https://<TenantName>.sharepoint.com" -Interactive; Get-PnPTenantSite }
function Get-SharePointLibraries { param($SiteUrl); Connect-PnPOnline -Url $SiteUrl -Interactive; Get-PnPList | Where-Object {$_.BaseTemplate -eq 101} }
function Get-SharePointSitePermissions { param($SiteUrl); Connect-PnPOnline -Url $SiteUrl -Interactive; Get-PnPRoleAssignment }
function Grant-SharePointSiteAccess { param($SiteUrl,$User,$Role="Edit"); Connect-PnPOnline -Url $SiteUrl -Interactive; Add-PnPUserToGroup -LoginName $User -Identity $Role }
function Revoke-SharePointSiteAccess { param($SiteUrl,$User); Connect-PnPOnline -Url $SiteUrl -Interactive; Remove-PnPUserFromGroup -LoginName $User }

# =========================================
# Export Functions
# =========================================

Export-ModuleMember -Function `
    Get-ADUserList, Get-ADGroupList, Add-ADUserToGroup, Remove-ADUserFromGroup, `
    Get-ADUserByOU, Move-ADUser, Enable-ADUser, Disable-ADUser, Set-ADUserPassword, Unlock-ADUser, Get-ADComputerList, Move-ADComputer, Get-ADGroupMembers, Remove-ADGroupMembers, Add-ADGroupMembers, `
    Get-DnsRecord, Add-DnsRecord, Remove-DnsRecord, Get-DhcpScope, Add-DhcpReservation, Remove-DhcpReservation, `
    Get-GpoList, Backup-Gpo, Restore-Gpo, Get-CertificateList, Import-Certificate, Export-CertificateFile, Enable-FileAudit, `
    Get-ServerInfo, Get-Uptime, Get-LoggedOnUsers, Get-ServiceStatus, Start-ServiceByName, Stop-ServiceByName, Get-InstalledUpdates, Get-PendingUpdates, Install-PendingUpdates, Get-CPUUsage, Get-MemoryUsage, Get-DiskUsage, Restart-Server, Stop-Server, `
    Test-HostPing, Test-TcpPort, Resolve-HostName, Get-NicStatus, Get-RoutingTable, Set-StaticIPAddress, Set-DhcpIPAddress, Set-DnsServerAddress, Get-DnsServerAddress, Enable-NetworkAdapter, Disable-NetworkAdapter, Get-ArpTable, Get-PublicIPAddress, Get-FirewallRules, Add-FirewallRule, `
    Backup-Folder, Backup-ToZip, Restore-FromZip, Backup-UserProfile, Backup-SystemState, Get-EventLogEntries, Export-EventLogFile, Clear-EventLogFile, Get-ErrorEvents, Get-FailedLogons, Get-LogByDate, Search-EventLog, Get-LogStatistics, Get-LatestCriticalEvent, Get-ServiceEvents, `
    New-FileShare, Remove-FileShare, Get-FileShares, Add-NTFSPermission, Remove-NTFSPermission, Get-NTFSPermissions, Grant-SharePermission, Revoke-SharePermission, New-FolderQuota, Remove-FolderQuota, Get-FolderQuotas, Get-DuplicateFiles, Get-LargeFiles, Get-FileShareAccessLogs, `
    Get-AzureADUsers, New-AzureADUser, Get-AzureADGroups, Add-AzureADUserToGroup, Remove-AzureADUserFromGroup, `
    Get-OneDriveUsage, Get-OneDriveSyncStatus, Get-OneDriveFolderPermissions, Grant-OneDriveFolderAccess, Revoke-OneDriveFolderAccess, `
    Get-SharePointSites, Get-SharePointLibraries, Get-SharePointSitePermissions, Grant-SharePointSiteAccess, Revoke-SharePointSiteAccess
