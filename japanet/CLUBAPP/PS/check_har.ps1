# check_har.ps1
# 生成されたHARファイルのIdP通信内容をPowerShellで確認するスクリプト

# ============================================================
# 設定
# ============================================================
$WorkDir     = "C:\mitmproxy-work"
# ★ 確認したいIdPドメイン（export_idp_har.pyのTARGET_DOMAINSと合わせること）
$TargetDomains = @(
    "auth.jleague.jp",
    "id.jleague.jp"
)

# ============================================================
# 最新のHARファイルを自動選択
# ============================================================
$HarFile = Get-ChildItem -Path $WorkDir -Filter "jleague_idp_*.har" |
           Sort-Object LastWriteTime -Descending |
           Select-Object -First 1

if (!$HarFile) {
    Write-Host "[ERROR] HARファイルが見つかりません: $WorkDir" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " HAR確認スクリプト" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[対象ファイル] $($HarFile.FullName)" -ForegroundColor Yellow
Write-Host "[ファイルサイズ] $([math]::Round($HarFile.Length/1KB,1)) KB" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# HARファイルをパース
# ============================================================
try {
    $HarContent = Get-Content -Path $HarFile.FullName -Raw -Encoding UTF8
    $Har = $HarContent | ConvertFrom-Json
} catch {
    Write-Host "[ERROR] HARファイルの読み込みに失敗しました: $_" -ForegroundColor Red
    exit 1
}

$Entries = $Har.log.entries
$TotalCount = $Entries.Count

Write-Host "[合計エントリ数] $TotalCount 件" -ForegroundColor Green
Write-Host ""

# ============================================================
# IdPドメインチェック（意図しないドメインが混入していないか確認）
# ============================================================
Write-Host "-------- キャプチャされたドメイン一覧 --------" -ForegroundColor Cyan

$DomainGroups = $Entries |
    ForEach-Object {
        $uri = [System.Uri]$_.request.url
        $uri.Host
    } |
    Group-Object |
    Sort-Object Count -Descending

$HasUnexpected = $false
foreach ($group in $DomainGroups) {
    $isTarget = $TargetDomains | Where-Object { $group.Name -like "*$_*" }
    if ($isTarget) {
        Write-Host "  ✅ $($group.Name)  ($($group.Count) 件)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  $($group.Name)  ($($group.Count) 件) ← IdP対象外のドメイン" -ForegroundColor Red
        $HasUnexpected = $true
    }
}

Write-Host ""

# ============================================================
# HTTPメソッド別サマリ
# ============================================================
Write-Host "-------- HTTPメソッド別サマリ --------" -ForegroundColor Cyan
$Entries |
    ForEach-Object { $_.request.method } |
    Group-Object |
    ForEach-Object {
        Write-Host "  $($_.Name) : $($_.Count) 件" -ForegroundColor White
    }

Write-Host ""

# ============================================================
# ステータスコード別サマリ
# ============================================================
Write-Host "-------- ステータスコード別サマリ --------" -ForegroundColor Cyan
$Entries |
    ForEach-Object { $_.response.status } |
    Group-Object |
    Sort-Object Name |
    ForEach-Object {
        $color = if ($_.Name -like "2*") { "Green" }
                 elseif ($_.Name -like "3*") { "Yellow" }
                 else { "Red" }
        Write-Host "  HTTP $($_.Name) : $($_.Count) 件" -ForegroundColor $color
    }

Write-Host ""

# ============================================================
# 全URLリスト（詳細）
# ============================================================
Write-Host "-------- キャプチャURLリスト（詳細） --------" -ForegroundColor Cyan
$i = 1
foreach ($entry in $Entries) {
    $method  = $entry.request.method
    $url     = $entry.request.url
    $status  = $entry.response.status
    $timeMs  = [math]::Round($entry.time, 1)

    $statusColor = if ($status -lt 300) { "Green" }
                   elseif ($status -lt 400) { "Yellow" }
                   else { "Red" }

    Write-Host ("  [{0:D2}] " -f $i) -NoNewline -ForegroundColor DarkGray
    Write-Host "$method " -NoNewline -ForegroundColor Cyan
    Write-Host "$url" -ForegroundColor White
    Write-Host ("       Status: ") -NoNewline -ForegroundColor DarkGray
    Write-Host "$status" -NoNewline -ForegroundColor $statusColor
    Write-Host "  Time: ${timeMs}ms" -ForegroundColor DarkGray
    $i++
}

Write-Host ""

# ============================================================
# 最終判定
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
if (!$HasUnexpected) {
    Write-Host " ✅ 判定: IdP通信のみが含まれています。Securifyへの提出が可能です。" -ForegroundColor Green
} else {
    Write-Host " ⚠️  判定: IdP対象外のドメインが含まれています。" -ForegroundColor Red
    Write-Host "    export_idp_har.py の TARGET_DOMAINS を見直してください。" -ForegroundColor Red
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[HARファイルパス（Securifyにインポート）]" -ForegroundColor Yellow
Write-Host "  $($HarFile.FullName)" -ForegroundColor White
