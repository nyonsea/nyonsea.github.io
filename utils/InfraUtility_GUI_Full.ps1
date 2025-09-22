<#
モジュールパス・設定ファイルパス
InfraUtility.psm1 と InfraConfig.json のフルパスが正しいことを確認

PowerShell 実行ポリシー
GUI起動時に -ExecutionPolicy Bypass が必要な場合あり

並列数調整
RunspacePool の上限は [Environment]::ProcessorCount を基準に設定
サーバー数が多い場合、CPU負荷に注意

重要イベントの収集
Invoke-ServerTasks 内で $global:ImportantEvents に適切に追加すること

メール送信
SMTP設定が正しいこと、送信元アドレスが有効であること
#>

# =========================================
# InfraUtility 商用GUI版 完全版 (Runspace 並列)
# =========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# モジュール読み込み
Import-Module "C:\Modules\InfraUtility.psm1"

# 設定読み込み
$ConfigFile = "C:\Scripts\InfraConfig.json"
$config = Get-Content $ConfigFile | ConvertFrom-Json
$Servers = $config.Servers
$LogDir = $config.LogDirectory
$DiskWarningPercent = $config.DiskWarningPercent
$Smtp = $config.Smtp

# --------------------------
# GUIフォーム作成
# --------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "InfraUtility 管理画面 (完全版)"
$form.Size = New-Object System.Drawing.Size(1000,700)
$form.StartPosition = "CenterScreen"

# サーバーリスト
$lbServers = New-Object System.Windows.Forms.CheckedListBox
$lbServers.Location = New-Object System.Drawing.Point(10,10)
$lbServers.Size = New-Object System.Drawing.Size(220,500)
$Servers | ForEach-Object { $lbServers.Items.Add($_) }
$form.Controls.Add($lbServers)

# ログ表示用テキストボックス
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(240,10)
$txtLog.Size = New-Object System.Drawing.Size(730,500)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$form.Controls.Add($txtLog)

# 進捗バー
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,520)
$progressBar.Size = New-Object System.Drawing.Size(960,25)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

# ボタン群
$btnRunSelected = New-Object System.Windows.Forms.Button
$btnRunSelected.Text = "選択サーバー実行"
$btnRunSelected.Location = New-Object System.Drawing.Point(10,560)
$btnRunSelected.Size = New-Object System.Drawing.Size(220,40)
$form.Controls.Add($btnRunSelected)

$btnRunAll = New-Object System.Windows.Forms.Button
$btnRunAll.Text = "全サーバー実行"
$btnRunAll.Location = New-Object System.Drawing.Point(240,560)
$btnRunAll.Size = New-Object System.Drawing.Size(220,40)
$form.Controls.Add($btnRunAll)

$btnShowImportant = New-Object System.Windows.Forms.Button
$btnShowImportant.Text = "重要イベント表示"
$btnShowImportant.Location = New-Object System.Drawing.Point(470,560)
$btnShowImportant.Size = New-Object System.Drawing.Size(220,40)
$form.Controls.Add($btnShowImportant)

$btnSendMail = New-Object System.Windows.Forms.Button
$btnSendMail.Text = "重要イベントメール送信"
$btnSendMail.Location = New-Object System.Drawing.Point(700,560)
$btnSendMail.Size = New-Object System.Drawing.Size(220,40)
$form.Controls.Add($btnSendMail)

# --------------------------
# グローバル変数
# --------------------------
$global:ImportantEvents = @()

# --------------------------
# ログ関数
# --------------------------
function Append-Log { param($text) $txtLog.AppendText($text + "`r`n") }

# --------------------------
# Runspace 並列実行関数
# --------------------------
function Run-TasksParallelGUI {
    param([string[]]$TargetServers)

    $progressBar.Value = 0
    $completed = 0
    $total = $TargetServers.Count

    $tasks = @()
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
    $runspacePool.Open()

    foreach ($srv in $TargetServers) {
        $powershell = [powershell]::Create()
        $powershell.RunspacePool = $runspacePool
        $powershell.AddScript({
            param($s)
            Import-Module "C:\Modules\InfraUtility.psm1"
            # 重要イベントを返却
            $global:ImportantEvents = @()
            Invoke-ServerTasks -Server $s
            return $global:ImportantEvents
        }).AddArgument($srv)
        $task = $powershell.BeginInvoke()
        $tasks += [pscustomobject]@{ PS=$powershell; Task=$task; Server=$srv }
    }

    # 進捗監視
    while ($true) {
        $completed = ($tasks | Where-Object { $_.Task.IsCompleted }).Count
        $progressBar.Value = [math]::Round(($completed/$total)*100)
        [System.Windows.Forms.Application]::DoEvents()
        if ($completed -eq $total) { break }
        Start-Sleep -Milliseconds 200
    }

    # 結果取得
    foreach ($t in $tasks) {
        $events = $t.PS.EndInvoke($t.Task)
        if ($events) { $global:ImportantEvents += $events }
        $t.PS.Dispose()
        Append-Log "=== $($t.Server) タスク完了 ==="
    }

    $progressBar.Value = 100
    Append-Log "=== 全サーバータスク完了 ===`n"
}

# --------------------------
# GUIボタンイベント
# --------------------------
$btnRunSelected.Add_Click({
    $selected = $lbServers.CheckedItems
    if ($selected.Count -gt 0) {
        Run-TasksParallelGUI -TargetServers $selected
    } else { Append-Log "サーバーを選択してください" }
})

$btnRunAll.Add_Click({
    Run-TasksParallelGUI -TargetServers $Servers
})

$btnShowImportant.Add_Click({
    if ($global:ImportantEvents.Count -gt 0) {
        $txtLog.Clear()
        $global:ImportantEvents | ForEach-Object { Append-Log $_ }
    } else { Append-Log "重要イベントはありません" }
})

$btnSendMail.Add_Click({
    if ($global:ImportantEvents.Count -gt 0) {
        $Body = $global:ImportantEvents -join "<br>"
        try {
            Send-MailMessage -From $Smtp.From -To $Smtp.To -Subject "InfraUtility 重要イベント通知" -Body $Body -BodyAsHtml -SmtpServer $Smtp.Server
            Append-Log "重要イベントメール送信完了"
        } catch { Append-Log "メール送信失敗: $_" }
    } else { Append-Log "重要イベントなし、メール送信不要" }
})

# --------------------------
# GUI表示
# --------------------------
$form.Topmost = $true
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
