Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

# �t�H�[���쐬
$form = New-Object System.Windows.Forms.Form
$form.Text = "���\�[�X���j�^�_�b�V���{�[�h"
$form.Size = New-Object System.Drawing.Size(800,500)

# Chart�쐬
$chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
$chart.Location = New-Object System.Drawing.Point(10,10)
$chart.Size = New-Object System.Drawing.Size(760,420)
$chartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea "MainArea"
$chart.ChartAreas.Add($chartArea)
$form.Controls.Add($chart)

# CPU�V���[�Y
$seriesCPU = New-Object System.Windows.Forms.DataVisualization.Charting.Series "CPU"
$seriesCPU.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
$seriesCPU.Color = [System.Drawing.Color]::Red
$chart.Series.Add($seriesCPU)

# �������V���[�Y
$seriesMem = New-Object System.Windows.Forms.DataVisualization.Charting.Series "Memory"
$seriesMem.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
$seriesMem.Color = [System.Drawing.Color]::Blue
$chart.Series.Add($seriesMem)

# �f�[�^�ێ��p
$cpuHistory = @()
$memHistory = @()
$maxPoints = 60  # 60�b���̗���

# �^�C�}�[�ݒ�
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    # CPU�g�p��
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $cpuHistory += $cpu
    if ($cpuHistory.Count -gt $maxPoints) { $cpuHistory = $cpuHistory[-$maxPoints..-1] }

    # �������g�p��
    $mem = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
    $memHistory += $mem
    if ($memHistory.Count -gt $maxPoints) { $memHistory = $memHistory[-$maxPoints..-1] }

    # �O���t�X�V
    $seriesCPU.Points.Clear()
    $seriesMem.Points.Clear()
    for ($i=0; $i -lt $cpuHistory.Count; $i++) {
        $seriesCPU.Points.AddXY($i, $cpuHistory[$i])
        $seriesMem.Points.AddXY($i, $memHistory[$i])
    }
})
$timer.Start()

$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
