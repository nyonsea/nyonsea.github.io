# run_mitmproxy.ps1
# mitmproxyをIdPフィルタスクリプト付きで起動するPowerShellスクリプト

# ============================================================
# 設定セクション（環境に合わせて変更）
# ============================================================
$ListenHost  = "0.0.0.0"
$ListenPort  = 8080
$WebPort     = 8081
$ScriptPath  = ".\export_idp_har.py"   # Pythonアドオンスクリプトのパス
$WorkDir     = "C:\mitmproxy-work"     # 作業ディレクトリ

# ============================================================
# 事前チェック
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " mitmproxy 起動スクリプト" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 作業ディレクトリ移動
if (!(Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Path $WorkDir | Out-Null
    Write-Host "[INFO] 作業ディレクトリを作成しました: $WorkDir" -ForegroundColor Yellow
}
Set-Location $WorkDir

# mitmwebコマンドの存在確認
if (!(Get-Command mitmweb -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] mitmwebが見つかりません。" -ForegroundColor Red
    Write-Host "        https://mitmproxy.org/downloads/ からインストールしてください。" -ForegroundColor Red
    exit 1
}

# スクリプトファイルの存在確認
if (!(Test-Path $ScriptPath)) {
    Write-Host "[ERROR] スクリプトが見つかりません: $ScriptPath" -ForegroundColor Red
    exit 1
}

# ============================================================
# PCのIPアドレスを自動取得して表示
# ============================================================
$LocalIP = (
    Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.InterfaceAlias -like "*Wi-Fi*" -or
        $_.InterfaceAlias -like "*Wireless*"
    } |
    Select-Object -First 1 -ExpandProperty IPAddress
)

if (!$LocalIP) {
    # Wi-Fiが見つからない場合はイーサネットも候補に
    $LocalIP = (
        Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.PrefixOrigin -eq "Dhcp" } |
        Select-Object -First 1 -ExpandProperty IPAddress
    )
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " iPhoneのプロキシ設定に以下を入力してください" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "  サーバ : $LocalIP" -ForegroundColor Yellow
Write-Host "  ポート : $ListenPort" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "[INFO] mitmweb管理画面 → http://localhost:$WebPort" -ForegroundColor Cyan
Write-Host "[INFO] 終了するには Ctrl+C を押してください（HARが自動保存されます）" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# mitmweb 起動
# ============================================================
$Args = @(
    "--listen-host", $ListenHost,
    "--listen-port", $ListenPort,
    "--web-port",    $WebPort,
    "-s",            $ScriptPath
)

Write-Host "[START] mitmwebを起動します..." -ForegroundColor Green
Write-Host "        コマンド: mitmweb $($Args -join ' ')" -ForegroundColor DarkGray
Write-Host ""

try {
    & mitmweb @Args
}
finally {
    # Ctrl+C後に必ずここが実行される
    Write-Host ""
    Write-Host "[INFO] mitmwebを終了しました。" -ForegroundColor Cyan
    Write-Host "[INFO] HARファイルを確認してください:" -ForegroundColor Cyan
    Get-ChildItem -Path $WorkDir -Filter "jleague_idp_*.har" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 3 |
        ForEach-Object {
            Write-Host "  → $($_.FullName)  ($([math]::Round($_.Length/1KB,1)) KB)" -ForegroundColor Yellow
        }
}
