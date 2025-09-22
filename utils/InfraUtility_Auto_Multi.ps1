<#
2. 特徴と運用ポイント

サーバーごとにログ出力
$BaseLogDir にサーバーごとのログファイルを作成
失敗箇所や容量不足などをサーバー別に追跡可能

順次・並列タスクの柔軟化
現在は foreach で順次実行
Invoke-Command -AsJob を使えば並列化も可能

エラーキャッチで安定運用
サーバーが停止中でも他サーバーは処理継続
個別の try/catch により詳細ログ記録

簡単にカテゴリ追加可能
AD、DNS、バックアップ、クラウド連携などもサーバーごとに Invoke-Command で統合可能
#>

# =========================================
# InfraUtility マルチサーバー自動化テンプレート
# =========================================

Import-Module "C:\Modules\InfraUtility.psm1"

# 管理対象サーバーリスト
$Servers = @(
    "SRV01.contoso.local",
    "SRV02.contoso.local",
    "SRV03.contoso.local"
)

# ログディレクトリ
$BaseLogDir = "C:\InfraLogs"
if (-not (Test-Path $BaseLogDir)) { New-Item -ItemType Directory -Path $BaseLogDir }

# サーバーごとのログ作成
function Write-ServerLog {
    param($Server,$Message)
    $LogFile = Join-Path $BaseLogDir ("InfraLog_" + $Server + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "$TimeStamp - $Message"
    Write-Host "$Server: $Entry"
    Add-Content -Path $LogFile -Value $Entry
}

# =========================================
# メイン処理（サーバーごとにループ）
# =========================================

foreach ($Server in $Servers) {

    Write-ServerLog -Server $Server -Message "=== 管理タスク開始 ==="

    # =========================================
    # 1. サーバー接続確認
    # =========================================
    try {
        if (Test-HostPing -HostName $Server) {
            Write-ServerLog -Server $Server -Message "Ping OK"
        } else {
            Write-ServerLog -Server $Server -Message "Ping NG"
            continue  # 接続不可なら次のサーバーへ
        }
    } catch {
        Write-ServerLog -Server $Server -Message "Ping失敗: $_"
        continue
    }

    # =========================================
    # 2. サービス監視タスク（順次実行）
    # =========================================
    $ServicesToCheck = @("wuauserv","Spooler","WinRM")
    foreach ($svc in $ServicesToCheck) {
        try {
            $status = Invoke-Command -ComputerName $Server -ScriptBlock { param($s) Get-Service -Name $s } -ArgumentList $svc
            Write-ServerLog -Server $Server -Message "サービス $svc 状態: $($status.Status)"
        } catch {
            Write-ServerLog -Server $Server -Message "サービス取得失敗 ($svc): $_"
        }
    }

    # =========================================
    # 3. Windows Update保留確認
    # =========================================
    try {
        $pending = Invoke-Command -ComputerName $Server -ScriptBlock { Get-PendingUpdates }
        Write-ServerLog -Server $Server -Message "保留更新件数: $($pending.Count)"
    } catch {
        Write-ServerLog -Server $Server -Message "更新確認失敗: $_"
    }

    # =========================================
    # 4. ディスク容量確認
    # =========================================
    try {
        $diskInfo = Invoke-Command -ComputerName $Server -ScriptBlock { Get-DiskUsage }
        foreach ($d in $diskInfo) {
            Write-ServerLog -Server $Server -Message "ドライブ $($d.DeviceID) サイズ: $($d.'Size(GB)')GB 空き: $($d.'Free(GB)')GB"
        }
    } catch {
        Write-ServerLog -Server $Server -Message "ディスク情報取得失敗: $_"
    }

    # =========================================
    # 5. イベントログエラー取得
    # =========================================
    try {
        $errors = Invoke-Command -ComputerName $Server -ScriptBlock { Get-ErrorEvents -LogName "System" -MaxEvents 50 }
        foreach ($e in $errors) {
            Write-ServerLog -Server $Server -Message "エラー: $($e.TimeCreated) $($e.Message)"
        }
    } catch {
        Write-ServerLog -Server $Server -Message "イベントログ取得失敗: $_"
    }

    # =========================================
    # 6. ファイルサーバー権限チェック
    # =========================================
    try {
        $acl = Invoke-Command -ComputerName $Server -ScriptBlock { Get-NTFSPermissions -Path "E:\Projects" }
        foreach ($a in $acl) {
            Write-ServerLog -Server $Server -Message "NTFS権限: $($a.IdentityReference) - $($a.FileSystemRights)"
        }
    } catch {
        Write-ServerLog -Server $Server -Message "NTFS権限取得失敗: $_"
    }

    Write-ServerLog -Server $Server -Message "=== 管理タスク終了 ===`n"
}

Write-Host "全サーバーの管理タスク完了"
