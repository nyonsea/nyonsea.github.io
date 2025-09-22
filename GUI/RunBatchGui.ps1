Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# �X�N���v�g���s�t�H���_���擾
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- �t�H�[���쐬 ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "�o�b�`�t�@�C�����s�c�[��"
$form.Size = New-Object System.Drawing.Size(500,260)
$form.StartPosition = "CenterScreen"

# ���x��: �o�b�`�t�@�C��
$labelBatch = New-Object System.Windows.Forms.Label
$labelBatch.Text = "�o�b�`�t�@�C��:"
$labelBatch.Location = New-Object System.Drawing.Point(10,20)
$labelBatch.AutoSize = $true
$form.Controls.Add($labelBatch)

# �o�b�`�I���R���{
$comboBatch = New-Object System.Windows.Forms.ComboBox
$comboBatch.Location = New-Object System.Drawing.Point(120,18)
$comboBatch.Width = 330
$comboBatch.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($comboBatch)

# ���x��: ����
$labelArg = New-Object System.Windows.Forms.Label
$labelArg.Text = "����:"
$labelArg.Location = New-Object System.Drawing.Point(10,60)
$labelArg.AutoSize = $true
$form.Controls.Add($labelArg)

# �����I���R���{
$comboArg = New-Object System.Windows.Forms.ComboBox
$comboArg.Location = New-Object System.Drawing.Point(120,58)
$comboArg.Width = 330
$comboArg.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($comboArg)

# �������\���p���x��
$labelValue = New-Object System.Windows.Forms.Label
$labelValue.Text = "�I�����ꂽ�����̓��e�������ɕ\������܂�"
$labelValue.Location = New-Object System.Drawing.Point(120,95)
$labelValue.AutoSize = $true
$form.Controls.Add($labelValue)

# ���s�{�^��
$buttonRun = New-Object System.Windows.Forms.Button
$buttonRun.Text = "�Ǘ��Ҍ����Ŏ��s"
$buttonRun.Location = New-Object System.Drawing.Point(120,130)
$form.Controls.Add($buttonRun)

# �L�����Z���{�^��
$buttonCancel = New-Object System.Windows.Forms.Button
$buttonCancel.Text = "�L�����Z��"
$buttonCancel.Location = New-Object System.Drawing.Point(300,130)
$buttonCancel.Add_Click({ $form.Close() })
$form.Controls.Add($buttonCancel)

# --- �T�C�Y�����֐� ---
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
            # �{�^���̓T�C�Y���X�V
            $ctrl.Width  = [math]::Ceiling($size.Width) + 20
            $ctrl.Height = [math]::Ceiling($size.Height) + 10
        }

        if ($ctrl.Right + 20 -gt $maxWidth) {
            $maxWidth = $ctrl.Right + 20
        }
    }
    $g.Dispose()

    # �t�H�[���̕����X�V
    if ($form.ClientSize.Width -lt $maxWidth) {
        $form.ClientSize = New-Object System.Drawing.Size($maxWidth, $form.ClientSize.Height)
    }
}

# --- INI�ǂݍ��݊֐� ---
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

# --- �o�b�`�t�@�C���ꗗ���擾 ---
$batchFiles = Get-ChildItem -Path $ScriptDir -Filter *.bat
foreach ($file in $batchFiles) {
    $comboBatch.Items.Add($file.Name) | Out-Null
}

# ini�̒l��ێ����鎫��
$argMap = @{}

# �o�b�`�I����
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

# �����I����
$comboArg.Add_SelectedIndexChanged({
    $selectedArg = $comboArg.SelectedItem
    if ($selectedArg -and $argMap.ContainsKey($selectedArg)) {
        $labelValue.Text = $argMap[$selectedArg]
    } else {
        $labelValue.Text = ""
    }
    # ���x���X�V��Ƀt�H�[�������Ē���
    Resize-ControlsAndForm -form $form -controls @($buttonRun,$buttonCancel,$labelValue)
})

# ���s�{�^��
$buttonRun.Add_Click({
    $selectedBat = $comboBatch.SelectedItem
    $selectedArg = $comboArg.SelectedItem
    if (-not $selectedBat) {
        [System.Windows.Forms.MessageBox]::Show("�o�b�`�t�@�C����I�����Ă��������B")
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
    $psi.Verb = "runas"   # �Ǘ��Ҍ����Ŏ��s
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("�Ǘ��Ҍ����̎��s���L�����Z������܂����B")
    }
})

# �����T�C�Y����
Resize-ControlsAndForm -form $form -controls @($buttonRun,$buttonCancel,$labelValue)

# --- �t�H�[���\�� ---
$form.Topmost = $true
[void]$form.ShowDialog()
