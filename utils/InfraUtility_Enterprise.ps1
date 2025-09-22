# =========================================
# InfraUtility 商用運用版
# 並列実行＋リアルタイム進捗＋メール通知＋重要イベント抽出
# =========================================

Import-Module "C:\Modules\InfraUtility.psm1"

# --------------------------
# 管理対象サーバーリスト
# --------------------------
$Servers = @(
    "SRV01.contoso.local",
    "SRV02.contoso.local",
    "SRV03.contoso.local"
)

# --------------------------
# ログ設定
# --------------------------
$BaseLogDir = "C:\InfraLogs"
if (-not (Test-Path $BaseLogDir)) { New-Item -ItemType Directory -Path $BaseLogDir }

$SummaryLogFile = Join-Path $BaseLogDir ("InfraUtilitySummary_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

# ログ関数
function Write-Log {
    param([string]$Server, [string]$Message, [switch]$Important)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "$TimeStamp - $Server - $Message"
    Write-Host $Entry
    $ServerLog = Join-Path $BaseLogDir ("InfraLog_" + $Server + ".log")
    Add-Content -Path $ServerLog -Value $Entry
    Add-Content -Path $SummaryLogFile -Value $Entry
    if ($Important) { 
        $global:ImportantEvents += $Entry
    }
}

# --------------------------
# グローバル変数
# --------------------------
$global:ImportantEvents = @()

# --------------------------
# サーバー処理関数
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

    # 2. サービス監視
    $ServicesToCheck = @("wuauserv","Spooler","WinRM")
    foreach ($svc in $ServicesToCheck) {
        try {
            $status = Invoke-Command -ComputerName $Server -ScriptBlock { param($s) Get-Service -Name $s } -ArgumentList $svc
            if ($status.Status -ne "Running") {
                Write-Log -Server $Server -Message "サービス停止中: $svc" -Important
            } else {
                Write-Log -Server $Server -Message "サービス $svc OK"
            }
        } catch {
            Write-Log -Server $Server -Message "サービス取得失敗 ($svc): $_" -Important
        }
    }

    # 3. Windows Update保留確認
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

    # 4. ディスク容量監視（80%超で重要イベント）
    try {
        $diskInfo = Invoke-Command -ComputerName $Server -ScriptBlock { Get-DiskUsage }
        foreach ($d in $diskInfo) {
            $freePercent = [math]::Round(($d.'Free(GB)'/$d.'Size(GB)')*100,2)
            $msg = "ドライブ $($d.DeviceID) 空き: $($d.'Free(GB)')GB ($freePercent`%)"
            if ($freePercent -lt 20) {
                Write-Log -Server $Server -Message $msg -Important
            } else {
                Write-Log -Server $Server -Message $msg
            }
        }
    } catch {
        Write-Log -Server $Server -Message "ディスク情報取得失敗: $_" -Important
    }

    # 5. イベントログエラー取得（重要イベントのみ）
    try {
        $errors = Invoke-Command -ComputerName $Server -ScriptBlock { Get-ErrorEvents -LogName "System" -MaxEvents 50 }
        foreach ($e in $errors) {
            Write-Log -Server $Server -Message "エラー: $($e.TimeCreated) $($e.Message)" -Important
        }
    } catch {
        Write-Log -Server $Server -Message "イベントログ取得失敗: $_" -Important
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

# ジョブ進捗表示
while ($jobs.State -contains 'Running') {
    Write-Host "ジョブ進行中: " + ($jobs | Where-Object {$_.State -eq 'Running'} | Measure-Object).Count + " 件"
    Start-Sleep -Seconds 5
}

# ジョブ結果受け取り
$jobs | Receive-Job
$jobs | Remove-Job
Write-Host "全サーバータスク完了"

# --------------------------
# メール通知（重要イベントのみ）
# --------------------------
if ($global:ImportantEvents.Count -gt 0) {
    $SmtpServer = "smtp.contoso.local"
    $From = "infra-monitor@contoso.local"
    $To = "admin@contoso.local"
    $Subject = "InfraUtility 重要イベント通知"
    $Body = $global:ImportantEvents -join "<br>"

    try {
        Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer $SmtpServer
        Write-Host "重要イベントメール送信完了"
    } catch {
        Write-Host "メール送信失敗: $_"
    }
} else {
    Write-Host "重要イベントなし、メール送信不要"
}
