<#
マルチサーバー・マルチタスク
並列実行＋リアルタイム進捗表示
カテゴリ別タスク（AD/DNS/DHCP/バックアップ/サーバーメンテ/ネットワーク/ファイルサーバー/クラウド）
ログ管理（サーバー別 + 集約ログ + 古いログ自動削除）
重要イベント抽出＋メール通知
設定ファイル化で閾値や対象サーバーを柔軟に変更可能

完全自動化
タスクスケジューラで毎日実行可能
並列実行で大規模環境でも高速

柔軟な設定管理
JSONファイルで対象サーバー、閾値、通知設定を変更可能

重要イベント抽出＋通知
Ping NG、サービス停止、ディスク不足、イベントログエラーのみ通知

拡張性
新しいタスクを Invoke-ServerTasks 内に追加するだけ
設定ファイルでタスク有効/無効切替

ログ管理
サーバー別ログ + 集約ログ + 30日以上古いログ自動削除
#>

# =========================================
# InfraUtility 完全商用運用テンプレート
# =========================================

Import-Module ".\Modules\InfraUtility.psm1"

# --------------------------
# 設定ファイル読み込み（JSON形式）
# --------------------------
$ConfigFile = ".\Scripts\InfraConfig.json"
if (-not (Test-Path $ConfigFile)) { throw "設定ファイルが存在しません: $ConfigFile" }
$config = Get-Content $ConfigFile | ConvertFrom-Json

$Servers = $config.Servers
$LogDir = $config.LogDirectory
$Smtp = $config.Smtp
$DiskWarningPercent = $config.DiskWarningPercent

# ログディレクトリ作成
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir }

$SummaryLogFile = Join-Path $LogDir ("InfraUtilitySummary_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
$global:ImportantEvents = @()

# --------------------------
# ログ関数
# --------------------------
function Write-Log {
    param([string]$Server, [string]$Message, [switch]$Important)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "$TimeStamp - $Server - $Message"
    Write-Host $Entry
    $ServerLog = Join-Path $LogDir ("InfraLog_" + $Server + ".log")
    Add-Content -Path $ServerLog -Value $Entry
    Add-Content -Path $SummaryLogFile -Value $Entry
    if ($Important) { 
        $global:ImportantEvents += $Entry
    }
}

# --------------------------
# 古いログ自動削除
# --------------------------
Get-ChildItem -Path $LogDir -Filter "*.log" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force

# --------------------------
# サーバータスク関数
# --------------------------
function Invoke-ServerTasks {
    param($Server)

    Write-Log -Server $Server -Message "=== タスク開始 ==="

    # 1. Ping確認
    try {
        if (-not (Test-HostPing -HostName $Server)) {
            Write-Log -Server $Server -Message "Ping NG" -Important
            return
        }
        Write-Log -Server $Server -Message "Ping OK"
    } catch {
        Write-Log -Server $Server -Message "Ping失敗: $_" -Important
        return
    }

    # =========================================
    # AD管理
    # =========================================
    if ($config.Tasks.AD) {
        try {
            $users = Get-ADUserList
            Write-Log -Server $Server -Message "ADユーザー数: $($users.Count)"
        } catch {
            Write-Log -Server $Server -Message "AD取得失敗: $_" -Important
        }
    }

    # =========================================
    # DNS/DHCP管理
    # =========================================
    if ($config.Tasks.DNS) {
        try {
            $dnsRecords = Get-DnsRecords -Zone "example.com"
            Write-Log -Server $Server -Message "DNSレコード数: $($dnsRecords.Count)"
        } catch {
            Write-Log -Server $Server -Message "DNS取得失敗: $_" -Important
        }
    }

    # =========================================
    # バックアップ
    # =========================================
    if ($config.Tasks.Backup) {
        try {
            Backup-Folder -Source "C:\Data" -Destination "E:\Backup\Data"
            Write-Log -Server $Server -Message "バックアップ完了"
        } catch {
            Write-Log -Server $Server -Message "バックアップ失敗: $_" -Important
        }
    }

    # =========================================
    # サーバーメンテ / 更新確認
    # =========================================
    if ($config.Tasks.Maintenance) {
        try {
            $pending = Invoke-Command -ComputerName $Server -ScriptBlock { Get-PendingUpdates }
            if ($pending.Count -gt 0) {
                Write-Log -Server $Server -Message "保留更新件数: $($pending.Count)" -Important
            } else {
                Write-Log -Server $Server -Message "保留更新なし"
            }
        } catch {
            Write-Log -Server $Server -Message "更新確認失敗: $_" -Important
        }

        # ディスク容量
        try {
            $diskInfo = Invoke-Command -ComputerName $Server -ScriptBlock { Get-DiskUsage }
            foreach ($d in $diskInfo) {
                $freePercent = [math]::Round(($d.'Free(GB)'/$d.'Size(GB)')*100,2)
                $msg = "ドライブ $($d.DeviceID) 空き: $($d.'Free(GB)')GB ($freePercent`%)"
                if ($freePercent -lt $DiskWarningPercent) {
                    Write-Log -Server $Server -Message $msg -Important
                } else {
                    Write-Log -Server $Server -Message $msg
                }
            }
        } catch {
            Write-Log -Server $Server -Message "ディスク情報取得失敗: $_" -Important
        }
    }

    # =========================================
    # イベントログ取得
    # =========================================
    if ($config.Tasks.EventLog) {
        try {
            $errors = Invoke-Command -ComputerName $Server -ScriptBlock { Get-ErrorEvents -LogName "System" -MaxEvents 50 }
            foreach ($e in $errors) {
                Write-Log -Server $Server -Message "エラー: $($e.TimeCreated) $($e.Message)" -Important
            }
        } catch {
            Write-Log -Server $Server -Message "イベントログ取得失敗: $_" -Important
        }
    }

    # =========================================
    # ファイルサーバー権限
    # =========================================
    if ($config.Tasks.FileServer) {
        try {
            $acl = Invoke-Command -ComputerName $Server -ScriptBlock { Get-NTFSPermissions -Path "E:\Projects" }
            foreach ($a in $acl) {
                Write-Log -Server $Server -Message "NTFS権限: $($a.IdentityReference) - $($a.FileSystemRights)"
            }
        } catch {
            Write-Log -Server $Server -Message "NTFS権限取得失敗: $_" -Important
        }
    }

    # =========================================
    # クラウド連携
    # =========================================
    if ($config.Tasks.Cloud) {
        try {
            $aadUsers = Get-AzureADUsers
            Write-Log -Server $Server -Message "Azure AD ユーザー数: $($aadUsers.Count)"
        } catch {
            Write-Log -Server $Server -Message "AzureAD取得失敗: $_" -Important
        }
    }

    Write-Log -Server $Server -Message "=== タスク終了 ===`n"
}

# --------------------------
# 並列実行
# --------------------------
$jobs = @()
foreach ($srv in $Servers) {
    $jobs += Start-Job -ScriptBlock { param($s) Invoke-ServerTasks -Server $s } -ArgumentList $srv
}

while ($jobs.State -contains 'Running') {
    Write-Host "ジョブ進行中: " + ($jobs | Where-Object {$_.State -eq 'Running'} | Measure-Object).Count + " 件"
    Start-Sleep -Seconds 5
}

$jobs | Receive-Job
$jobs | Remove-Job
Write-Host "全サーバータスク完了"

# --------------------------
# メール通知（重要イベントのみ）
# --------------------------
if ($global:ImportantEvents.Count -gt 0) {
    $Body = $global:ImportantEvents -join "<br>"
    try {
        Send-MailMessage -From $Smtp.From -To $Smtp.To -Subject "InfraUtility 重要イベント通知" -Body $Body -BodyAsHtml -SmtpServer $Smtp.Server
        Write-Host "重要イベントメール送信完了"
    } catch {
        Write-Host "メール送信失敗: $_"
    }
} else {
    Write-Host "重要イベントなし、メール送信不要"
}
