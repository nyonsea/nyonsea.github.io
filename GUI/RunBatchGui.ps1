Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# スクリプト実行フォルダを取得
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- フォーム作成 ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "バッチファイル実行ツール"
$form.Size = New-Object System.Drawing.Size(500,260)
$form.StartPosition = "CenterScreen"

# ラベル: バッチファイル
$labelBatch = New-Object System.Windows.Forms.Label
$labelBatch.Text = "バッチファイル:"
$labelBatch.Location = New-Object System.Drawing.Point(10,20)
$labelBatch.AutoSize = $true
$form.Controls.Add($labelBatch)

# バッチ選択コンボ
$comboBatch = New-Object System.Windows.Forms.ComboBox
$comboBatch.Location = New-Object System.Drawing.Point(120,18)
$comboBatch.Width = 330
$comboBatch.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($comboBatch)

# ラベル: 引数
$labelArg = New-Object System.Windows.Forms.Label
$labelArg.Text = "引数:"
$labelArg.Location = New-Object System.Drawing.Point(10,60)
$labelArg.AutoSize = $true
$form.Controls.Add($labelArg)

# 引数選択コンボ
$comboArg = New-Object System.Windows.Forms.ComboBox
$comboArg.Location = New-Object System.Drawing.Point(120,58)
$comboArg.Width = 330
$comboArg.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($comboArg)

# 実引数表示用ラベル
$labelValue = New-Object System.Windows.Forms.Label
$labelValue.Text = "選択された引数の内容がここに表示されます"
$labelValue.Location = New-Object System.Drawing.Point(120,95)
$labelValue.AutoSize = $true
$form.Controls.Add($labelValue)

# 実行ボタン
$buttonRun = New-Object System.Windows.Forms.Button
$buttonRun.Text = "管理者権限で実行"
$buttonRun.Location = New-Object System.Drawing.Point(120,130)
$form.Controls.Add($buttonRun)

# キャンセルボタン
$buttonCancel = New-Object System.Windows.Forms.Button
$buttonCancel.Text = "キャンセル"
$buttonCancel.Location = New-Object System.Drawing.Point(300,130)
$buttonCancel.Add_Click({ $form.Close() })
$form.Controls.Add($buttonCancel)

# --- サイズ調整関数 ---
function Resize-ControlsAndForm {
    param(
        [System.Windows.Forms.Form]$form,
        [System.Windows.Forms.Control[]]$controls
    )

    $g = $form.CreateGraphics()
    $maxWidth = $form.ClientSize.Width

    foreach ($ctrl in $controls) {
        $size = $g.MeasureString($ctrl.Text, $ctrl.Font)

        if ($ctrl -is [System.Windows.Forms.Button]) {
            # ボタンはサイズを更新
            $ctrl.Width  = [math]::Ceiling($size.Width) + 20
            $ctrl.Height = [math]::Ceiling($size.Height) + 10
        }

        if ($ctrl.Right + 20 -gt $maxWidth) {
            $maxWidth = $ctrl.Right + 20
        }
    }
    $g.Dispose()

    # フォームの幅を更新
    if ($form.ClientSize.Width -lt $maxWidth) {
        $form.ClientSize = New-Object System.Drawing.Size($maxWidth, $form.ClientSize.Height)
    }
}

# --- INI読み込み関数 ---
function Read-IniFile {
    param([string]$path)

    $section = ""
    $data = @{}
    foreach ($line in Get-Content $path) {
        $trim = $line.Trim()
        if ($trim -match "^\[(.+)\]$") {
            $section = $matches[1]
            if (-not $data.ContainsKey($section)) {
                $data[$section] = @()
            }
        }
        elseif ($trim -ne "" -and $section -ne "") {
            $data[$section] += $trim
        }
    }
    return $data
}

# --- バッチファイル一覧を取得 ---
$batchFiles = Get-ChildItem -Path $ScriptDir -Filter *.bat
foreach ($file in $batchFiles) {
    $comboBatch.Items.Add($file.Name) | Out-Null
}

# iniの値を保持する辞書
$argMap = @{}

# バッチ選択時
$comboBatch.Add_SelectedIndexChanged({
    $comboArg.Items.Clear()
    $labelValue.Text = ""
    $argMap.Clear()

    $selectedBat = $comboBatch.SelectedItem
    if ($selectedBat) {
        $iniFile = [System.IO.Path]::ChangeExtension((Join-Path $ScriptDir $selectedBat), ".ini")
        if (Test-Path $iniFile) {
            $iniData = Read-IniFile $iniFile
            if ($iniData.ContainsKey("Arguments") -and $iniData.ContainsKey("value")) {
                $args = $iniData["Arguments"]
                $vals = $iniData["value"]
                for ($i=0; $i -lt [math]::Min($args.Count,$vals.Count); $i++) {
                    $comboArg.Items.Add($args[$i]) | Out-Null
                    $argMap[$args[$i]] = $vals[$i]
                }
                if ($comboArg.Items.Count -gt 0) {
                    $comboArg.SelectedIndex = 0
                }
            }
        }
    }
    Resize-ControlsAndForm -form $form -controls @($buttonRun,$buttonCancel,$labelValue)
})

# 引数選択時
$comboArg.Add_SelectedIndexChanged({
    $selectedArg = $comboArg.SelectedItem
    if ($selectedArg -and $argMap.ContainsKey($selectedArg)) {
        $labelValue.Text = $argMap[$selectedArg]
    } else {
        $labelValue.Text = ""
    }
    # ラベル更新後にフォーム幅も再調整
    Resize-ControlsAndForm -form $form -controls @($buttonRun,$buttonCancel,$labelValue)
})

# 実行ボタン
$buttonRun.Add_Click({
    $selectedBat = $comboBatch.SelectedItem
    $selectedArg = $comboArg.SelectedItem
    if (-not $selectedBat) {
        [System.Windows.Forms.MessageBox]::Show("バッチファイルを選択してください。")
        return
    }

    $argValue = ""
    if ($selectedArg -and $argMap.ContainsKey($selectedArg)) {
        $argValue = $argMap[$selectedArg]
    }

    $batPath = Join-Path $ScriptDir $selectedBat
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c `"$batPath`" $argValue"
    $psi.Verb = "runas"   # 管理者権限で実行
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("管理者権限の実行がキャンセルされました。")
    }
})

# 初期サイズ調整
Resize-ControlsAndForm -form $form -controls @($buttonRun,$buttonCancel,$labelValue)

# --- フォーム表示 ---
$form.Topmost = $true
[void]$form.ShowDialog()
