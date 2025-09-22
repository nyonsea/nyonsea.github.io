Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

# フォーム作成
$form = New-Object System.Windows.Forms.Form
$form.Text = "リソースモニタダッシュボード"
$form.Size = New-Object System.Drawing.Size(800,500)

# Chart作成
$chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
$chart.Location = New-Object System.Drawing.Point(10,10)
$chart.Size = New-Object System.Drawing.Size(760,420)
$chartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea "MainArea"
$chart.ChartAreas.Add($chartArea)
$form.Controls.Add($chart)

# CPUシリーズ
$seriesCPU = New-Object System.Windows.Forms.DataVisualization.Charting.Series "CPU"
$seriesCPU.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
$seriesCPU.Color = [System.Drawing.Color]::Red
$chart.Series.Add($seriesCPU)

# メモリシリーズ
$seriesMem = New-Object System.Windows.Forms.DataVisualization.Charting.Series "Memory"
$seriesMem.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
$seriesMem.Color = [System.Drawing.Color]::Blue
$chart.Series.Add($seriesMem)

# データ保持用
$cpuHistory = @()
$memHistory = @()
$maxPoints = 60  # 60秒分の履歴

# タイマー設定
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    # CPU使用率
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $cpuHistory += $cpu
    if ($cpuHistory.Count -gt $maxPoints) { $cpuHistory = $cpuHistory[-$maxPoints..-1] }

    # メモリ使用量
    $mem = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
    $memHistory += $mem
    if ($memHistory.Count -gt $maxPoints) { $memHistory = $memHistory[-$maxPoints..-1] }

    # グラフ更新
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
