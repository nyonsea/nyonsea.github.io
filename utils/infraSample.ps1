# ===============================
# InfraUtility Sample Usage
# ===============================
# 前提: モジュールを読み込む
Import-Module .\InfraUtility.psm1

# =========================================
# 1. Active Directory 管理サンプル
# =========================================

# 全ユーザーリストを取得
$allUsers = Get-ADUserList
$allUsers | Select Name, SamAccountName | Format-Table

# ユーザーをグループに追加
Add-ADUserToGroup -User "taro.sato" -Group "ITStaff"

# 特定OUのユーザーを取得
$ouUsers = Get-ADUserByOU -OU "OU=Sales,DC=example,DC=com"
$ouUsers | Select Name, SamAccountName | Format-Table

# ADユーザーのパスワードリセット
Set-ADUserPassword -User "taro.sato" -Password "NewPassw0rd!"

# =========================================
# 2. DNS / DHCP 管理サンプル
# =========================================

# DNSレコードを取得
Get-DnsRecord -Zone "example.com" -Name "host01"

# Aレコード追加
Add-DnsRecord -Zone "example.com" -Name "host02" -IP "192.168.1.102"

# DHCPスコープ一覧取得
Get-DhcpScope | Format-Table ScopeId, Name, State

# =========================================
# 3. セキュリティ / GPO / 証明書サンプル
# =========================================

# GPO一覧を表示
Get-GpoList | Select DisplayName, GpoStatus | Format-Table

# GPOバックアップ
Backup-Gpo -Name "Default Domain Policy" -Path "E:\GPOBackup"

# ローカルマシン証明書一覧
Get-CertificateList | Select Subject, Thumbprint

# ファイル監査設定
Enable-FileAudit -Path "C:\ImportantDocs"

# =========================================
# 4. OS / サーバーメンテナンスサンプル
# =========================================

# サーバー情報取得
Get-ServerInfo | Format-List

# サービス状態確認
Get-ServiceStatus -ServiceName "wuauserv"

# CPUとメモリ使用率
$cpu = Get-CPUUsage
$mem = Get-MemoryUsage
Write-Host "CPU Usage: $([math]::Round($cpu.CookedValue,2))%"
Write-Host "Available Memory: $([math]::Round($mem.CookedValue,2)) MB"

# インストール済み更新プログラム
Get-InstalledUpdates | Select HotFixID, InstalledOn | Format-Table -AutoSize

# =========================================
# 5. ネットワーク診断サンプル
# =========================================

# ホストにping
Test-HostPing -HostName "google.com"

# TCPポート疎通確認
Test-TcpPort -HostName "192.168.1.1" -Port 3389

# NIC状態確認
Get-NicStatus | Format-Table Name, Status, LinkSpeed

# 静的IP設定
Set-StaticIPAddress -InterfaceAlias "Ethernet0" -IPAddress "192.168.1.50" -PrefixLength 24 -Gateway "192.168.1.1"

# =========================================
# 6. バックアップ / ログ管理サンプル
# =========================================

# フォルダをミラーリングバックアップ
Backup-Folder -Source "C:\Data" -Destination "E:\Backup\Data"

# ZIPアーカイブ化
Backup-ToZip -SourcePath "C:\Data" -DestinationZip "E:\Backup\Data.zip"

# イベントログ取得
$errors = Get-ErrorEvents -LogName "System" -MaxEvents 50
$errors | Select TimeCreated, Message | Format-Table -AutoSize

# 特定サービス関連イベント
Get-ServiceEvents -ServiceName "wuauserv" -MaxEvents 50

# =========================================
# 7. ファイルサーバー管理サンプル
# =========================================

# 新しい共有作成
New-FileShare -Path "E:\Projects" -Name "ProjectsShare" -Description "Project Files"

# NTFSアクセス権付与
Add-NTFSPermission -Path "E:\Projects" -Identity "DOMAIN\ITStaff" -Rights "Modify"

# フォルダクォータ作成
New-FolderQuota -Path "E:\Projects" -SizeMB 10000

# 大きなファイル一覧
Get-LargeFiles -Path "E:\Projects" -SizeMB 500

# =========================================
# 8. クラウド連携サンプル
# =========================================

# Azure ADユーザー一覧
$aadUsers = Get-AzureADUsers
$aadUsers | Select DisplayName, UserPrincipalName | Format-Table

# Azure ADユーザーをグループ追加
Add-AzureADUserToGroup -UserId "user-id-guid" -GroupId "group-id-guid"

# OneDrive使用状況取得
Get-OneDriveUsage | Format-Table UserPrincipalName, StorageUsed, StorageQuota

# SharePointサイト一覧取得
Get-SharePointSites | Select Url, Owner | Format-Table

# SharePointライブラリ一覧
Get-SharePointLibraries -SiteUrl "https://contoso.sharepoint.com/sites/Projects"

# =========================================
# End of Sample Script
# =========================================
