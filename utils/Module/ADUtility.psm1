#requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Active Directory 管理ユーティリティモジュール
.DESCRIPTION
    ADのユーザー/グループ/コンピュータ/ドメイン管理に役立つ関数を集約
    Import-Module で利用可能

    使い方

上記を ADUtility.psm1 として保存
C:\Modules\ADUtility\ADUtility.psm1

モジュールを読み込む
Import-Module C:\Modules\ADUtility\ADUtility.psm1 -Force

利用例
Get-AdGroupMembers -GroupName "Domain Admins"
Test-AdDomainControllers

#>

#region Functions

function New-AdUserBulk {
    <#
    .SYNOPSIS
        CSVを基にADユーザーを一括作成
    .EXAMPLE
        New-AdUserBulk -CsvPath .\users.csv
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath
    )

    Import-Csv -Path $CsvPath | ForEach-Object {
        try {
            New-ADUser -Name $_.Name -SamAccountName $_.SamAccountName `
                       -UserPrincipalName $_.UserPrincipalName `
                       -AccountPassword (ConvertTo-SecureString $_.Password -AsPlainText -Force) `
                       -Enabled $true
            Write-Verbose "User [$($_.SamAccountName)] created"
        } catch {
            Write-Warning "Failed to create user [$($_.SamAccountName)]: $_"
        }
    }
}

function Set-AdUserStatus {
    <#
    .SYNOPSIS
        ADユーザーを有効化または無効化する
    .EXAMPLE
        Set-AdUserStatus -SamAccountName user1 -Enabled:$false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName,

        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    $user = Get-ADUser -Identity $SamAccountName -ErrorAction Stop
    if ($Enabled) {
        Enable-ADAccount -Identity $user
    } else {
        Disable-ADAccount -Identity $user
    }
}

function Get-AdUserPasswordExpiry {
    <#
    .SYNOPSIS
        ユーザーのパスワード有効期限を確認
    .EXAMPLE
        Get-AdUserPasswordExpiry -SamAccountName user1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName
    )

    $user = Get-ADUser -Identity $SamAccountName -Properties "msDS-UserPasswordExpiryTimeComputed"
    $expiry = [datetime]::FromFileTime($user."msDS-UserPasswordExpiryTimeComputed")
    [PSCustomObject]@{
        User   = $SamAccountName
        Expiry = $expiry
    }
}

function Get-AdUsersInOU {
    <#
    .SYNOPSIS
        指定OU配下のユーザーを取得
    .EXAMPLE
        Get-AdUsersInOU -OU "OU=Sales,DC=example,DC=com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OU
    )

    Get-ADUser -Filter * -SearchBase $OU
}

function Get-AdGroupMembers {
    <#
    .SYNOPSIS
        グループメンバー一覧を取得
    .EXAMPLE
        Get-AdGroupMembers -GroupName "Domain Admins"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName
    )

    Get-ADGroupMember -Identity $GroupName | 
        Select-Object Name, SamAccountName, ObjectClass
}

function Add-AdUserToGroup {
    <#
    .SYNOPSIS
        指定ユーザーをグループに追加
    .EXAMPLE
        Add-AdUserToGroup -SamAccountName user1 -GroupName "IT-Admins"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName,

        [Parameter(Mandatory)]
        [string]$GroupName
    )

    try {
        Add-ADGroupMember -Identity $GroupName -Members $SamAccountName
        Write-Verbose "Added $SamAccountName to $GroupName"
    } catch {
        Write-Warning "Failed to add $SamAccountName: $_"
    }
}

function Remove-AdUserFromGroup {
    <#
    .SYNOPSIS
        グループからユーザーを削除
    .EXAMPLE
        Remove-AdUserFromGroup -SamAccountName user1 -GroupName "IT-Admins"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName,

        [Parameter(Mandatory)]
        [string]$GroupName
    )

    try {
        Remove-ADGroupMember -Identity $GroupName -Members $SamAccountName -Confirm:$false
        Write-Verbose "Removed $SamAccountName from $GroupName"
    } catch {
        Write-Warning "Failed to remove $SamAccountName : $_"
    }
}

function Disable-AdComputer {
    <#
    .SYNOPSIS
        コンピュータアカウントを無効化
    .EXAMPLE
        Disable-AdComputer -ComputerName PC01
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    Disable-ADAccount -Identity $ComputerName
}

function Get-AdFsmoRoles {
    <#
    .SYNOPSIS
        FSMO役割の所有者を確認
    .EXAMPLE
        Get-AdFsmoRoles
    #>
    [CmdletBinding()]
    param()

    netdom query fsmo
}

function Test-AdDomainControllers {
    <#
    .SYNOPSIS
        ドメインコントローラの疎通確認
    .EXAMPLE
        Test-AdDomainControllers
    #>
    [CmdletBinding()]
    param()

    Get-ADDomainController -Filter * | ForEach-Object {
        $reachable = Test-Connection -ComputerName $_.HostName -Count 2 -Quiet
        [PSCustomObject]@{
            DCName    = $_.HostName
            Reachable = $reachable
        }
    }
}

#endregion Functions

#requires -Modules ActiveDirectory

#region AD Management Part2

function Search-AdUser {
    <#
    .SYNOPSIS
        名前やSamAccountNameをキーにADユーザーを検索
    .EXAMPLE
        Search-AdUser -Keyword "taro"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Keyword
    )
    Get-ADUser -Filter "Name -like '*$Keyword*' -or SamAccountName -like '*$Keyword*'" `
               -Properties DisplayName, Mail | 
        Select-Object SamAccountName, DisplayName, Mail
}

function Unlock-AdUser {
    <#
    .SYNOPSIS
        ロックアウトされたユーザーを解除
    .EXAMPLE
        Unlock-AdUser -SamAccountName user1
    #>
    [CmdletBinding()]
    param([string]$SamAccountName)

    Unlock-ADAccount -Identity $SamAccountName
}

function Reset-AdUserPassword {
    <#
    .SYNOPSIS
        ユーザーパスワードをリセット
    .EXAMPLE
        Reset-AdUserPassword -SamAccountName user1 -NewPassword "P@ssw0rd!"
    #>
    [CmdletBinding()]
    param(
        [string]$SamAccountName,
        [string]$NewPassword
    )

    Set-ADAccountPassword -Identity $SamAccountName -Reset `
        -NewPassword (ConvertTo-SecureString $NewPassword -AsPlainText -Force)
}

function Get-AdUserLastLogon {
    <#
    .SYNOPSIS
        ユーザーの最終ログオン時間を取得
    #>
    [CmdletBinding()]
    param([string]$SamAccountName)

    $user = Get-ADUser -Identity $SamAccountName -Properties LastLogonDate
    [PSCustomObject]@{
        User     = $user.SamAccountName
        LastLogon= $user.LastLogonDate
    }
}

function Get-AdDisabledUsers {
    <#
    .SYNOPSIS
        無効化されているユーザーを一覧
    #>
    [CmdletBinding()]
    param()

    Get-ADUser -Filter { Enabled -eq $false } -Properties Enabled | 
        Select-Object SamAccountName, Name
}

function Get-AdInactiveUsers {
    <#
    .SYNOPSIS
        一定期間ログオンしていないユーザーを抽出
    .EXAMPLE
        Get-AdInactiveUsers -Days 90
    #>
    [CmdletBinding()]
    param([int]$Days=90)

    $threshold = (Get-Date).AddDays(-$Days)
    Search-ADAccount -UsersOnly -AccountInactive -TimeSpan (New-TimeSpan -Days $Days) |
        Select-Object Name, SamAccountName, LastLogonDate
}

function Get-AdLockedOutUsers {
    <#
    .SYNOPSIS
        ロックアウト中のユーザー一覧
    #>
    [CmdletBinding()]
    param()
    Search-ADAccount -LockedOut | 
        Select-Object Name, SamAccountName, LockedOut
}

function Move-AdUserToOU {
    <#
    .SYNOPSIS
        ユーザーを別のOUに移動
    .EXAMPLE
        Move-AdUserToOU -SamAccountName user1 -TargetOU "OU=Sales,DC=example,DC=com"
    #>
    [CmdletBinding()]
    param(
        [string]$SamAccountName,
        [string]$TargetOU
    )
    $user = Get-ADUser -Identity $SamAccountName
    Move-ADObject -Identity $user.DistinguishedName -TargetPath $TargetOU
}

function Copy-AdUser {
    <#
    .SYNOPSIS
        既存ユーザーをテンプレートとして複製
    .EXAMPLE
        Copy-AdUser -TemplateUser template1 -NewSamAccountName user2 -NewUPN "user2@example.com"
    #>
    [CmdletBinding()]
    param(
        [string]$TemplateUser,
        [string]$NewSamAccountName,
        [string]$NewUPN,
        [string]$Password = "P@ssw0rd!"
    )

    $template = Get-ADUser -Identity $TemplateUser -Properties *
    New-ADUser -SamAccountName $NewSamAccountName -UserPrincipalName $NewUPN `
        -DisplayName $template.DisplayName -GivenName $template.GivenName `
        -Surname $template.Surname -Path $template.DistinguishedName `
        -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) -Enabled $true
}

function Get-AdGroupsForUser {
    <#
    .SYNOPSIS
        指定ユーザーが所属するグループを取得
    #>
    [CmdletBinding()]
    param([string]$SamAccountName)

    Get-ADUser -Identity $SamAccountName -Properties MemberOf |
        Select-Object -ExpandProperty MemberOf
}

function Get-AdComputersInOU {
    <#
    .SYNOPSIS
        OU配下のコンピュータ一覧を取得
    #>
    [CmdletBinding()]
    param([string]$OU)

    Get-ADComputer -Filter * -SearchBase $OU |
        Select-Object Name, DNSHostName, Enabled
}

function Get-AdDisabledComputers {
    <#
    .SYNOPSIS
        無効化されているコンピュータ一覧
    #>
    [CmdletBinding()]
    param()

    Get-ADComputer -Filter { Enabled -eq $false } | 
        Select-Object Name, DNSHostName
}

function Get-AdInactiveComputers {
    <#
    .SYNOPSIS
        一定期間ログオンしていないコンピュータを一覧
    .EXAMPLE
        Get-AdInactiveComputers -Days 90
    #>
    [CmdletBinding()]
    param([int]$Days=90)

    $threshold = (Get-Date).AddDays(-$Days)
    Search-ADAccount -ComputersOnly -AccountInactive -TimeSpan (New-TimeSpan -Days $Days) |
        Select-Object Name, LastLogonDate
}

function Test-AdReplication {
    <#
    .SYNOPSIS
        ADレプリケーションの状態を確認
    #>
    [CmdletBinding()]
    param()

    repadmin /replsummary
}

#endregion AD Management Part2

# ===============================
# DNS / DHCP Utility Functions
# ===============================

<#
.SYNOPSIS
DNSゾーンの一覧を取得します
#>
function Get-DnsZones {
    param(
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Get-DnsServerZone -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DNSゾーンを作成します
#>
function New-DnsZone {
    param(
        [string]$ZoneName,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Add-DnsServerPrimaryZone -Name $ZoneName -ReplicationScope "Domain" -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DNSレコードを登録します
#>
function Add-DnsRecord {
    param(
        [string]$ZoneName,
        [string]$HostName,
        [string]$IPAddress,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Add-DnsServerResourceRecordA -Name $HostName -ZoneName $ZoneName -IPv4Address $IPAddress -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DNSレコードを削除します
#>
function Remove-DnsRecord {
    param(
        [string]$ZoneName,
        [string]$HostName,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Remove-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType "A" -Force -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DNSキャッシュをクリアします
#>
function Clear-DnsCache {
    param(
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Clear-DnsServerCache -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
フォワーダーを追加します
#>
function Add-DnsForwarder {
    param(
        [string]$IPAddress,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Add-DnsServerForwarder -IPAddress $IPAddress -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
フォワーダーを削除します
#>
function Remove-DnsForwarder {
    param(
        [string]$IPAddress,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Remove-DnsServerForwarder -IPAddress $IPAddress -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DHCPスコープ一覧を取得します
#>
function Get-DhcpScopes {
    param(
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Get-DhcpServerv4Scope -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DHCPスコープを新規作成します
#>
function New-DhcpScope {
    param(
        [string]$Name,
        [string]$StartRange,
        [string]$EndRange,
        [string]$SubnetMask,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Add-DhcpServerv4Scope -Name $Name -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DHCPスコープを削除します
#>
function Remove-DhcpScope {
    param(
        [string]$ScopeId,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Remove-DhcpServerv4Scope -ScopeId $ScopeId -Force -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DHCP予約を追加します
#>
function Add-DhcpReservation {
    param(
        [string]$ScopeId,
        [string]$IPAddress,
        [string]$MacAddress,
        [string]$Description = "",
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Add-DhcpServerv4Reservation -ScopeId $ScopeId -IPAddress $IPAddress -ClientId $MacAddress -Description $Description -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DHCP予約を削除します
#>
function Remove-DhcpReservation {
    param(
        [string]$ScopeId,
        [string]$IPAddress,
        [string]$MacAddress,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Remove-DhcpServerv4Reservation -ScopeId $ScopeId -IPAddress $IPAddress -ClientId $MacAddress -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
スコープの利用状況を確認します
#>
function Get-DhcpScopeStatistics {
    param(
        [string]$ScopeId,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Get-DhcpServerv4ScopeStatistics -ScopeId $ScopeId -ComputerName $ComputerName -ErrorAction Stop
}

<#
.SYNOPSIS
DHCPリース一覧を取得します
#>
function Get-DhcpLeases {
    param(
        [string]$ScopeId,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    Get-DhcpServerv4Lease -ScopeId $ScopeId -ComputerName $ComputerName -ErrorAction Stop
}

# ===============================
# Security Utility Functions (GPO / Certificate / Audit)
# ===============================

# -------------------------------
# GPO 関連
# -------------------------------

<#
.SYNOPSIS
すべてのGPOを取得します
#>
function Get-AllGPOs {
    Get-GPO -All -ErrorAction Stop
}

<#
.SYNOPSIS
新しいGPOを作成します
#>
function New-GPOPolicy {
    param(
        [string]$Name
    )
    New-GPO -Name $Name -ErrorAction Stop
}

<#
.SYNOPSIS
GPOをリンクします
#>
function Link-GPOToOU {
    param(
        [string]$GPOName,
        [string]$OU
    )
    New-GPLink -Name $GPOName -Target $OU -ErrorAction Stop
}

<#
.SYNOPSIS
GPOのバックアップを作成します
#>
function Backup-GPOPolicy {
    param(
        [string]$Name,
        [string]$Path
    )
    Backup-GPO -Name $Name -Path $Path -ErrorAction Stop
}

<#
.SYNOPSIS
GPOをバックアップから復元します
#>
function Restore-GPOPolicy {
    param(
        [string]$Path,
        [string]$TargetName
    )
    Restore-GPO -Path $Path -TargetName $TargetName -ErrorAction Stop
}

# -------------------------------
# 証明書 関連
# -------------------------------

<#
.SYNOPSIS
ローカルマシン証明書ストアの一覧を取得します
#>
function Get-LocalCertificates {
    Get-ChildItem Cert:\LocalMachine\My | Select-Object Subject,Issuer,Thumbprint,NotAfter
}

<#
.SYNOPSIS
証明書をインポートします
#>
function Import-CertificateFile {
    param(
        [string]$FilePath,
        [string]$Store = "My"
    )
    Import-Certificate -FilePath $FilePath -CertStoreLocation "Cert:\LocalMachine\$Store" -ErrorAction Stop
}

<#
.SYNOPSIS
証明書をエクスポートします
#>
function Export-CertificateFile {
    param(
        [string]$Thumbprint,
        [string]$Path
    )
    $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object Thumbprint -eq $Thumbprint
    if ($null -eq $cert) { throw "証明書が見つかりません: $Thumbprint" }
    Export-Certificate -Cert $cert -FilePath $Path -ErrorAction Stop
}

<#
.SYNOPSIS
証明書の有効期限をチェックします
#>
function Test-CertificateExpiry {
    param(
        [int]$Days = 30
    )
    Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.NotAfter -lt (Get-Date).AddDays($Days) } |
        Select-Object Subject,NotAfter
}

<#
.SYNOPSIS
証明書を削除します
#>
function Remove-CertificateByThumbprint {
    param(
        [string]$Thumbprint
    )
    $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object Thumbprint -eq $Thumbprint
    if ($cert) { Remove-Item -Path $cert.PSPath -Force }
}

# -------------------------------
# 監査 / セキュリティログ 関連
# -------------------------------

<#
.SYNOPSIS
セキュリティログの最新イベントを取得します
#>
function Get-SecurityLogEvents {
    param(
        [int]$MaxEvents = 50
    )
    Get-WinEvent -LogName Security -MaxEvents $MaxEvents
}

<#
.SYNOPSIS
監査ポリシーを取得します
#>
function Get-AuditPolicy {
    AuditPol.exe /get /category:* | Out-String
}

<#
.SYNOPSIS
監査ポリシーを設定します
#>
function Set-AuditPolicy {
    param(
        [string]$Subcategory,
        [string]$Setting # Success, Failure, All, None
    )
    AuditPol.exe /set /subcategory:"$Subcategory" /success:$Setting /failure:$Setting
}

<#
.SYNOPSIS
アカウントロックアウトイベントを確認します
#>
function Get-AccountLockouts {
    Get-WinEvent -LogName Security | Where-Object {
        $_.Id -eq 4740
    } | Select-Object TimeCreated, @{n="User";e={$_.Properties[0].Value}}, @{n="Caller";e={$_.Properties[1].Value}}
}

<#
.SYNOPSIS
管理者グループメンバー変更イベントを確認します
#>
function Get-AdminGroupChanges {
    Get-WinEvent -LogName Security | Where-Object {
        $_.Id -in 4728,4729,4732,4733
    } | Select-Object TimeCreated, Id, @{n="User";e={$_.Properties[0].Value}}
}

# ===============================
# OS / Server Maintenance Utility Functions
# ===============================

# -------------------------------
# システム情報 / 基本操作
# -------------------------------

<#
.SYNOPSIS
サーバーの基本情報を取得します
#>
function Get-ServerInfo {
    Get-ComputerInfo | Select-Object CsName, WindowsProductName, WindowsVersion, OsArchitecture, CsManufacturer, CsModel
}

<#
.SYNOPSIS
サーバー稼働時間を確認します
#>
function Get-Uptime {
    (Get-Date) - (gcim Win32_OperatingSystem).LastBootUpTime
}

<#
.SYNOPSIS
現在のログオンユーザー一覧を取得します
#>
function Get-LoggedOnUsers {
    quser | ForEach-Object {
        ($_ -split '\s{2,}')[0..2] -join ','
    }
}

# -------------------------------
# サービス管理
# -------------------------------

<#
.SYNOPSIS
サービスの状態を取得します
#>
function Get-ServiceStatus {
    param(
        [string]$ServiceName = "*"
    )
    Get-Service -Name $ServiceName | Select-Object Name,DisplayName,Status
}

<#
.SYNOPSIS
サービスを開始します
#>
function Start-ServiceByName {
    param(
        [string]$ServiceName
    )
    Start-Service -Name $ServiceName -ErrorAction Stop
}

<#
.SYNOPSIS
サービスを停止します
#>
function Stop-ServiceByName {
    param(
        [string]$ServiceName
    )
    Stop-Service -Name $ServiceName -Force -ErrorAction Stop
}

# -------------------------------
# 更新管理
# -------------------------------

<#
.SYNOPSIS
インストール済み更新プログラムを取得します
#>
function Get-InstalledUpdates {
    Get-HotFix | Select-Object HotFixID,InstalledOn,Description
}

<#
.SYNOPSIS
Windows Update を確認します（PSWindowsUpdate モジュール必須）
#>
function Get-PendingUpdates {
    if (-not (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue)) {
        throw "PSWindowsUpdate モジュールが必要です。"
    }
    Get-WindowsUpdate
}

<#
.SYNOPSIS
Windows Update を適用します（PSWindowsUpdate モジュール必須）
#>
function Install-PendingUpdates {
    if (-not (Get-Command Install-WindowsUpdate -ErrorAction SilentlyContinue)) {
        throw "PSWindowsUpdate モジュールが必要です。"
    }
    Install-WindowsUpdate -AcceptAll -AutoReboot
}

# -------------------------------
# リソース監視
# -------------------------------

<#
.SYNOPSIS
CPU使用率を取得します
#>
function Get-CPUUsage {
    Get-Counter '\Processor(_Total)\% Processor Time' | Select-Object -ExpandProperty CounterSamples | Select-Object CookedValue
}

<#
.SYNOPSIS
メモリ使用量を取得します
#>
function Get-MemoryUsage {
    Get-Counter '\Memory\Available MBytes' | Select-Object -ExpandProperty CounterSamples | Select-Object CookedValue
}

<#
.SYNOPSIS
ディスク使用状況を取得します
#>
function Get-DiskUsage {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | 
        Select-Object DeviceID, @{n="Size(GB)";e={[math]::Round($_.Size/1GB,2)}}, @{n="Free(GB)";e={[math]::Round($_.FreeSpace/1GB,2)}}
}

# -------------------------------
# 再起動 / シャットダウン
# -------------------------------

<#
.SYNOPSIS
サーバーを再起動します
#>
function Restart-Server {
    param(
        [int]$Delay = 10
    )
    Restart-Computer -Force -Delay $Delay
}

<#
.SYNOPSIS
サーバーをシャットダウンします
#>
function Stop-Server {
    param(
        [int]$Delay = 10
    )
    Stop-Computer -Force -Delay $Delay
}

# ===============================
# Network Diagnostic / Configuration Utility Functions
# ===============================

# -------------------------------
# ネットワーク診断
# -------------------------------

<#
.SYNOPSIS
指定ホストへのPing疎通を確認します
#>
function Test-HostPing {
    param(
        [string]$HostName
    )
    Test-Connection -ComputerName $HostName -Count 4 -ErrorAction SilentlyContinue
}

<#
.SYNOPSIS
指定ポートへのTCP接続を確認します
#>
function Test-TcpPort {
    param(
        [string]$HostName,
        [int]$Port
    )
    Test-NetConnection -ComputerName $HostName -Port $Port
}

<#
.SYNOPSIS
DNS名前解決を確認します
#>
function Resolve-HostName {
    param(
        [string]$HostName
    )
    Resolve-DnsName -Name $HostName -ErrorAction Stop
}

<#
.SYNOPSIS
NICのリンク状態を確認します
#>
function Get-NicStatus {
    Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed
}

<#
.SYNOPSIS
ルーティングテーブルを表示します
#>
function Get-RoutingTable {
    Get-NetRoute | Select-Object DestinationPrefix,NextHop,InterfaceAlias,RouteMetric
}

# -------------------------------
# ネットワーク構成
# -------------------------------

<#
.SYNOPSIS
NICに固定IPを設定します
#>
function Set-StaticIPAddress {
    param(
        [string]$InterfaceAlias,
        [string]$IPAddress,
        [string]$PrefixLength,
        [string]$Gateway
    )
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction Stop
}

<#
.SYNOPSIS
NICをDHCPモードに変更します
#>
function Set-DhcpIPAddress {
    param(
        [string]$InterfaceAlias
    )
    Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Enabled -ErrorAction Stop
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses
}

<#
.SYNOPSIS
DNSサーバーを設定します
#>
function Set-DnsServerAddress {
    param(
        [string]$InterfaceAlias,
        [string[]]$DNSServers
    )
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers
}

<#
.SYNOPSIS
現在のDNSサーバーを確認します
#>
function Get-DnsServerAddress {
    Get-DnsClientServerAddress | Select-Object InterfaceAlias,ServerAddresses
}

<#
.SYNOPSIS
NICを有効化します
#>
function Enable-NetworkAdapter {
    param(
        [string]$InterfaceAlias
    )
    Enable-NetAdapter -Name $InterfaceAlias -Confirm:$false
}

<#
.SYNOPSIS
NICを無効化します
#>
function Disable-NetworkAdapter {
    param(
        [string]$InterfaceAlias
    )
    Disable-NetAdapter -Name $InterfaceAlias -Confirm:$false
}

<#
.SYNOPSIS
ARPテーブルを確認します
#>
function Get-ArpTable {
    arp -a
}

<#
.SYNOPSIS
現在のセッションの外部IPを確認します
#>
function Get-PublicIPAddress {
    try {
        Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -UseBasicParsing | Select-Object -ExpandProperty ip
    }
    catch {
        Write-Warning "外部IPアドレスを取得できませんでした。"
    }
}

<#
.SYNOPSIS
ファイアウォールルール一覧を取得します
#>
function Get-FirewallRules {
    Get-NetFirewallRule | Select-Object DisplayName, Direction, Action, Enabled, Profile
}

<#
.SYNOPSIS
新しいファイアウォールルールを追加します
#>
function Add-FirewallRule {
    param(
        [string]$Name,
        [string]$Direction = "Inbound",
        [string]$Protocol = "TCP",
        [int]$Port,
        [string]$Action = "Allow"
    )
    New-NetFirewallRule -DisplayName $Name -Direction $Direction -Protocol $Protocol -LocalPort $Port -Action $Action -Enabled True
}

# ===============================
# Backup / Log Management Utility Functions
# ===============================

# -------------------------------
# バックアップ関連
# -------------------------------

<#
.SYNOPSIS
指定フォルダをバックアップ先へコピーします
#>
function Backup-Folder {
    param(
        [string]$Source,
        [string]$Destination
    )
    robocopy $Source $Destination /MIR /R:2 /W:2 /NFL /NDL
}

<#
.SYNOPSIS
指定ファイルをZIPアーカイブします
#>
function Backup-ToZip {
    param(
        [string]$SourcePath,
        [string]$DestinationZip
    )
    Compress-Archive -Path $SourcePath -DestinationPath $DestinationZip -Force
}

<#
.SYNOPSIS
ZIPファイルを展開します
#>
function Restore-FromZip {
    param(
        [string]$ZipPath,
        [string]$DestinationPath
    )
    Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force
}

<#
.SYNOPSIS
ユーザープロファイルをバックアップします
#>
function Backup-UserProfile {
    param(
        [string]$UserName,
        [string]$Destination
    )
    $profilePath = "C:\Users\$UserName"
    robocopy $profilePath $Destination /E /R:2 /W:2
}

<#
.SYNOPSIS
システム状態バックアップを実行します（Windows Server）
#>
function Backup-SystemState {
    wbadmin start systemstatebackup -backupTarget:E: -quiet
}

# -------------------------------
# ログ管理関連
# -------------------------------

<#
.SYNOPSIS
指定ログを取得します
#>
function Get-EventLogEntries {
    param(
        [string]$LogName = "System",
        [int]$MaxEvents = 100
    )
    Get-EventLog -LogName $LogName -Newest $MaxEvents
}

<#
.SYNOPSIS
指定ログをEVTX形式で保存します
#>
function Export-EventLogFile {
    param(
        [string]$LogName,
        [string]$Destination
    )
    wevtutil epl $LogName $Destination
}

<#
.SYNOPSIS
イベントログをクリアします
#>
function Clear-EventLogFile {
    param(
        [string]$LogName
    )
    wevtutil cl $LogName
}

<#
.SYNOPSIS
イベントログからエラーのみを抽出します
#>
function Get-ErrorEvents {
    param(
        [string]$LogName = "System",
        [int]$MaxEvents = 100
    )
    Get-WinEvent -LogName $LogName -MaxEvents $MaxEvents | Where-Object { $_.LevelDisplayName -eq "Error" }
}

<#
.SYNOPSIS
セキュリティログからログオン失敗を取得します
#>
function Get-FailedLogons {
    Get-WinEvent -LogName Security | Where-Object { $_.Id -eq 4625 } |
        Select-Object TimeCreated, @{n="User";e={$_.Properties[5].Value}}, @{n="SourceIP";e={$_.Properties[18].Value}}
}

# -------------------------------
# ログ解析 / 運用支援
# -------------------------------

<#
.SYNOPSIS
イベントログを日付でフィルタします
#>
function Get-LogByDate {
    param(
        [string]$LogName = "System",
        [datetime]$Since
    )
    Get-WinEvent -LogName $LogName | Where-Object { $_.TimeCreated -ge $Since }
}

<#
.SYNOPSIS
特定のキーワードを含むログを検索します
#>
function Search-EventLog {
    param(
        [string]$LogName = "Application",
        [string]$Keyword
    )
    Get-WinEvent -LogName $LogName | Where-Object { $_.Message -like "*$Keyword*" }
}

<#
.SYNOPSIS
イベントログの統計（エラー/警告/情報の件数）を出力します
#>
function Get-LogStatistics {
    param(
        [string]$LogName = "System",
        [int]$MaxEvents = 1000
    )
    Get-WinEvent -LogName $LogName -MaxEvents $MaxEvents |
        Group-Object LevelDisplayName | Select-Object Name,Count
}

<#
.SYNOPSIS
最新のクリティカルイベントを確認します
#>
function Get-LatestCriticalEvent {
    Get-WinEvent -LogName System -MaxEvents 50 | Where-Object { $_.LevelDisplayName -eq "Critical" } | Select-Object -First 1
}

<#
.SYNOPSIS
指定サービスに関連するイベントを抽出します
#>
function Get-ServiceEvents {
    param(
        [string]$ServiceName,
        [int]$MaxEvents = 200
    )
    Get-WinEvent -LogName System -MaxEvents $MaxEvents | Where-Object { $_.Message -like "*$ServiceName*" }
}

# ------------------------------
# File Server Management Utilities
# ------------------------------

# 1. 共有フォルダ作成
function New-FileShare {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Description = ""
    )
    # SMB共有を作成
    New-SmbShare -Name $Name -Path $Path -Description $Description -FullAccess "Administrators"
}

# 2. 共有フォルダ削除
function Remove-FileShare {
    param([string]$Name)
    Remove-SmbShare -Name $Name -Force
}

# 3. 共有一覧表示
function Get-FileShares {
    Get-SmbShare | Where-Object {$_.Name -notin "ADMIN$","IPC$","C$"}
}

# 4. NTFS権限追加
function Add-NTFSPermission {
    param(
        [string]$Path,
        [string]$Identity,
        [string]$Rights = "Modify"
    )
    $acl = Get-Acl $Path
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity,$Rights,"ContainerInherit,ObjectInherit","None","Allow")
    $acl.AddAccessRule($rule)
    Set-Acl $Path $acl
}

# 5. NTFS権限削除
function Remove-NTFSPermission {
    param(
        [string]$Path,
        [string]$Identity
    )
    $acl = Get-Acl $Path
    $acl.Access | Where-Object {$_.IdentityReference -eq $Identity} | ForEach-Object {
        $acl.RemoveAccessRule($_)
    }
    Set-Acl $Path $acl
}

# 6. NTFS権限確認
function Get-NTFSPermissions {
    param([string]$Path)
    (Get-Acl $Path).Access
}

# 7. 共有アクセス権限追加
function Grant-SharePermission {
    param(
        [string]$ShareName,
        [string]$Account,
        [string]$AccessRight = "Full"
    )
    Grant-SmbShareAccess -Name $ShareName -AccountName $Account -AccessRight $AccessRight -Force
}

# 8. 共有アクセス権限削除
function Revoke-SharePermission {
    param(
        [string]$ShareName,
        [string]$Account
    )
    Revoke-SmbShareAccess -Name $ShareName -AccountName $Account -Force
}

# 9. クォータ作成
function New-FolderQuota {
    param(
        [string]$Path,
        [int]$SizeMB
    )
    New-FsrmQuota -Path $Path -Size ($SizeMB * 1MB) -SoftLimit $false
}

# 10. クォータ削除
function Remove-FolderQuota {
    param([string]$Path)
    Remove-FsrmQuota -Path $Path -Confirm:$false
}

# 11. クォータ一覧
function Get-FolderQuotas {
    Get-FsrmQuota
}

# 12. 重複ファイル検出（MD5）
function Get-DuplicateFiles {
    param([string]$Path)
    Get-ChildItem -Path $Path -Recurse -File |
        Get-FileHash -Algorithm MD5 |
        Group-Object -Property Hash | Where-Object {$_.Count -gt 1}
}

# 13. ファイルアクセス監査有効化
function Enable-FileAudit {
    param([string]$Path)
    $acl = Get-Acl $Path
    $audit = New-Object System.Security.AccessControl.FileSystemAuditRule("Everyone","ReadData","None","None","Success")
    $acl.AddAuditRule($audit)
    Set-Acl $Path $acl
}

# 14. 共有アクセスログ確認
function Get-FileShareAccessLogs {
    Get-WinEvent -LogName "Microsoft-Windows-SMBServer/Audit" -MaxEvents 50 |
        Select-Object TimeCreated,Id,Message
}

# 15. 大容量ファイル検出
function Get-LargeFiles {
    param(
        [string]$Path,
        [int]$SizeMB = 100
    )
    Get-ChildItem -Path $Path -Recurse -File | Where-Object {($_.Length/1MB) -ge $SizeMB} |
        Select-Object FullName,@{Name="SizeMB";Expression={[math]::Round($_.Length/1MB,2)}}
}

