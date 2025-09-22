<#
2. フル運用版の特徴

並列実行
Start-Job でサーバーごとに並列処理
大規模環境でも高速化可能

サーバー別 + 全体ログ
$BaseLogDir にサーバー別ログ
$SummaryLogFile に全サーバー結果を集約

メール通知
実行完了時にまとめて送信
エラーや重要イベントも確認可能

柔軟なタスク拡張
AD操作、DNS/DHCP更新、バックアップ、クラウド管理なども追加可能

安定運用
try/catch でジョブ内の例外も捕捉
Ping NG のサーバーはスキップして処理継続
#>
# =========================================
# InfraUtility フル運用版 (並列＋メール通知)
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
    param($Server,$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "$TimeStamp - $Server - $Message"
    Write-Host $Entry
    $ServerLog = Join-Path $BaseLogDir ("InfraLog_" + $Server + ".log")
    Add-Content -Path $ServerLog -Value $Entry
    Add-Content -Path $SummaryLogFile -Value $Entry
}

# --------------------------
# タスク関数（サーバーごと）
# --------------------------
function Invoke-ServerTasks {
    param($Server)

    Write-Log -Server $Server -Message "=== タスク開始 ==="

    try {
        if (-not (Test-HostPing -HostName $Server)) {
            Write-Log -Server $Server -Message "Ping NG"
            return
        }
        Write-Log -Server $Server -Message "Ping OK"
    } catch {
        Write-Log -Server $Server -Message "Ping失敗: $_"
        return
    }

    # サービス監視
    $ServicesToCheck = @("wuauserv","Spooler","WinRM")
    foreach ($svc in $ServicesToCheck) {
        try {
            $status = Invoke-Command -ComputerName $Server -ScriptBlock { param($s) Get-Service -Name $s } -ArgumentList $svc
            Write-Log -Server $Server -Message "サービス $svc 状態: $($status.Status)"
        } catch {
            Write-Log -Server $Server -Message "サービス取得失敗 ($svc): $_"
        }
    }

    # Windows Update保留確認
    try {
        $pending = Invoke-Command -ComputerName $Server -ScriptBlock { Get-PendingUpdates }
        Write-Log -Server $Server -Message "保留更新件数: $($pending.Count)"
    } catch {
        Write-Log -Server $Server -Message "更新確認失敗: $_"
    }

    # ディスク容量
    try {
        $diskInfo = Invoke-Command -ComputerName $Server -ScriptBlock { Get-DiskUsage }
        foreach ($d in $diskInfo) {
            Write-Log -Server $Server -Message "ドライブ $($d.DeviceID) サイズ: $($d.'Size(GB)')GB 空き: $($d.'Free(GB)')GB"
        }
    } catch {
        Write-Log -Server $Server -Message "ディスク情報取得失敗: $_"
    }

    # イベントログエラー取得
    try {
        $errors = Invoke-Command -ComputerName $Server -ScriptBlock { Get-ErrorEvents -LogName "System" -MaxEvents 50 }
        foreach ($e in $errors) {
            Write-Log -Server $Server -Message "エラー: $($e.TimeCreated) $($e.Message)"
        }
    } catch {
        Write-Log -Server $Server -Message "イベントログ取得失敗: $_"
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

# ジョブ完了待ち
Write-Host "全サーバータスクを並列開始..."
$jobs | Wait-Job
Write-Host "全サーバータスク完了"

# --------------------------
# メール通知設定
# --------------------------
$SmtpServer = "smtp.contoso.local"
$From = "infra-monitor@contoso.local"
$To = "admin@contoso.local"
$Subject = "InfraUtility 自動化スクリプト実行結果"
$Body = Get-Content -Path $SummaryLogFile | Out-String

try {
    Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SmtpServer -BodyAsHtml
    Write-Host "メール通知送信完了"
} catch {
    Write-Host "メール送信失敗: $_"
}
