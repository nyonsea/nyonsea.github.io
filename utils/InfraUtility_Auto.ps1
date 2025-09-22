<#
2. 運用ポイント
スケジュールタスク登録
PowerShell を引数付きで実行：
powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\InfraUtility_Auto.ps1"

ログ確認
$LogDir にタイムスタンプ付きログが残るので、失敗箇所の特定が容易

カテゴリごとにブロック化
AD / DNS / バックアップ / サーバー / ネットワーク / ファイルサーバー / クラウド

将来的な追加や除外も容易
エラーキャッチ
try/catch でログに書き出し、スクリプトの中断を防止
#>

# =========================================
# InfraUtility 自動化テンプレート
# =========================================
# 前提: モジュール読み込み
Import-Module "C:\Modules\InfraUtility.psm1"

# ログ出力設定
$LogDir = "C:\InfraLogs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir }
$LogFile = Join-Path $LogDir ("InfraUtilityLog_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

# ログ関数
function Write-Log {
    param([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "$TimeStamp - $Message"
    Write-Host $Entry
    Add-Content -Path $LogFile -Value $Entry
}

Write-Log "=== InfraUtility 自動化スクリプト開始 ==="

# =========================================
# 1. AD管理例
# =========================================
Write-Log "ADユーザー一覧取得開始"
try {
    $users = Get-ADUserList
    Write-Log "取得ユーザー数: $($users.Count)"
} catch {
    Write-Log "AD取得失敗: $_"
}

# 特定グループへのユーザー追加（例）
try {
    Add-ADUserToGroup -User "taro.sato" -Group "ITStaff"
    Write-Log "taro.sato を ITStaff に追加"
} catch {
    Write-Log "グループ追加失敗: $_"
}

# =========================================
# 2. DNS / DHCP例
# =========================================
Write-Log "DNS Aレコード追加開始"
try {
    Add-DnsRecord -Zone "example.com" -Name "host-auto" -IP "192.168.1.200"
    Write-Log "DNS レコード host-auto.example.com 追加成功"
} catch {
    Write-Log "DNS追加失敗: $_"
}

# =========================================
# 3. バックアップ例
# =========================================
Write-Log "フォルダバックアップ開始"
try {
    Backup-Folder -Source "C:\Data" -Destination "E:\Backup\Data"
    Write-Log "バックアップ完了"
} catch {
    Write-Log "バックアップ失敗: $_"
}

# =========================================
# 4. サービス / サーバーメンテ
# =========================================
Write-Log "Windows Update 状態確認"
try {
    $pending = Get-PendingUpdates
    Write-Log "保留更新件数: $($pending.Count)"
} catch {
    Write-Log "WindowsUpdate確認失敗: $_"
}

# =========================================
# 5. ネットワーク診断
# =========================================
Write-Log "Google Ping確認"
try {
    if (Test-HostPing -HostName "google.com") {
        Write-Log "Ping OK"
    } else {
        Write-Log "Ping NG"
    }
} catch {
    Write-Log "Ping確認失敗: $_"
}

# =========================================
# 6. ファイルサーバー権限確認
# =========================================
Write-Log "ProjectsShare権限取得"
try {
    $acl = Get-NTFSPermissions -Path "E:\Projects"
    $acl | ForEach-Object { Write-Log "Permission: $($_.IdentityReference) - $($_.FileSystemRights)" }
} catch {
    Write-Log "権限取得失敗: $_"
}

# =========================================
# 7. クラウド連携例
# =========================================
Write-Log "AzureADユーザー数取得"
try {
    $aadUsers = Get-AzureADUsers
    Write-Log "Azure AD ユーザー数: $($aadUsers.Count)"
} catch {
    Write-Log "AzureAD取得失敗: $_"
}

# =========================================
# スクリプト終了
# =========================================
Write-Log "=== InfraUtility 自動化スクリプト終了 ==="
