# =========================================
# InfraUtility 管理画面 GUI版
# =========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --------------------------
# GUIフォーム作成
# --------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "InfraUtility 管理画面"
$form.Size = New-Object System.Drawing.Size(900,600)
$form.StartPosition = "CenterScreen"

# サーバーリスト表示用リストボックス
$lbServers = New-Object System.Windows.Forms.ListBox
$lbServers.Location = New-Object System.Drawing.Point(10,10)
$lbServers.Size = New-Object System.Drawing.Size(200,400)
$form.Controls.Add($lbServers)

# ログ表示用テキストボックス
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(220,10)
$txtLog.Size = New-Object System.Drawing.Size(650,400)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$form.Controls.Add($txtLog)

# タスク実行ボタン
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "選択サーバーのタスク実行"
$btnRun.Location = New-Object System.Drawing.Point(10,420)
$btnRun.Size = New-Object System.Drawing.Size(200,40)
$form.Controls.Add($btnRun)

# 全サーバー実行ボタン
$btnRunAll = New-Object System.Windows.Forms.Button
$btnRunAll.Text = "全サーバータスク実行"
$btnRunAll.Location = New-Object System.Drawing.Point(220,420)
$btnRunAll.Size = New-Object System.Drawing.Size(200,40)
$form.Controls.Add($btnRunAll)

# 重要イベント表示ボタン
$btnShowImportant = New-Object System.Windows.Forms.Button
$btnShowImportant.Text = "重要イベント表示"
$btnShowImportant.Location = New-Object System.Drawing.Point(430,420)
$btnShowImportant.Size = New-Object System.Drawing.Size(200,40)
$form.Controls.Add($btnShowImportant)

# --------------------------
# 初期サーバー読み込み
# --------------------------
$ConfigFile = "C:\Scripts\InfraConfig.json"
$config = Get-Content $ConfigFile | ConvertFrom-Json
$Servers = $config.Servers
$Servers | ForEach-Object { $lbServers.Items.Add($_) }

# --------------------------
# ログ追記関数
# --------------------------
function Append-Log {
    param($text)
    $txtLog.AppendText($text + "`r`n")
}

# --------------------------
# サーバータスク実行関数
# --------------------------
function Run-TasksForServer {
    param($Server)
    Append-Log "=== $Server タスク開始 ==="
    try {
        Invoke-ServerTasks -Server $Server
        Append-Log "=== $Server タスク完了 ===`n"
    } catch {
        Append-Log "タスク実行失敗: $_"
    }
}

function Run-TasksForAllServers {
    foreach ($srv in $Servers) {
        Run-TasksForServer -Server $srv
    }
}

# --------------------------
# ボタンイベント
# --------------------------
$btnRun.Add_Click({
    if ($lbServers.SelectedItem) {
        Run-TasksForServer -Server $lbServers.SelectedItem
    } else {
        Append-Log "サーバーを選択してください"
    }
})

$btnRunAll.Add_Click({
    Run-TasksForAllServers
})

$btnShowImportant.Add_Click({
    if ($global:ImportantEvents -and $global:ImportantEvents.Count -gt 0) {
        $txtLog.Clear()
        $global:ImportantEvents | ForEach-Object { Append-Log $_ }
    } else {
        Append-Log "重要イベントはありません"
    }
})

# --------------------------
# GUI表示
# --------------------------
$form.Topmost = $true
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
