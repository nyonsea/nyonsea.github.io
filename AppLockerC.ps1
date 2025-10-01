#Requires -RunAsAdministrator

<#
.SYNOPSIS
    AppLockerのプロパティを設定するスクリプト（デフォルト規則自動生成版）
.DESCRIPTION
    実行可能ファイルとパッケージアプリのデフォルト規則を作成し、有効化します。
.NOTES
    管理者権限が必要です。
    SKYSEA Client Viewからの配布を想定しています。
    戻り値: 0=成功、1=失敗
#>

try {
    # AppLockerサービスの状態確認と起動
    $appIdService = Get-Service -Name AppIDSvc -ErrorAction Stop
    
    if ($appIdService.Status -ne 'Running') {
        Set-Service -Name AppIDSvc -StartupType Automatic
        Start-Service -Name AppIDSvc
    }
    
    # 既存のポリシーを取得
    $policy = Get-AppLockerPolicy -Local
    
    # 実行可能ファイル（Exe）のデフォルト規則を作成
    $exeRules = Get-AppLockerFileInformation -Directory C:\Windows\System32\*.exe | 
                New-AppLockerPolicy -RuleType Publisher, Path -User Everyone -Optimize -ErrorAction SilentlyContinue
    
    if ($null -eq $exeRules) {
        # デフォルト規則を手動で作成（最小限の許可）
        $exeRules = New-AppLockerPolicy -RuleType Path -User Everyone `
                    -FileInformation (Get-AppLockerFileInformation -Path "C:\Windows\*") `
                    -RuleNamePrefix "Windows" -ErrorAction Stop
    }
    
    # 実行可能ファイルの規則をマージして有効化
    $policy.RuleCollections | Where-Object {$_.RuleCollectionType -eq "Exe"} | ForEach-Object {
        $_.EnforcementMode = "Enabled"
    }
    
    # Exeの規則が空の場合、デフォルト規則を追加
    $exeCollection = $policy.RuleCollections | Where-Object {$_.RuleCollectionType -eq "Exe"}
    if ($exeCollection.Count -eq 0 -or $exeCollection[0].Count -eq 0) {
        $exeRulesCollection = $exeRules.RuleCollections | Where-Object {$_.RuleCollectionType -eq "Exe"}
        foreach ($rule in $exeRulesCollection) {
            $policy.RuleCollections.Add($rule)
        }
    }
    
    # パッケージアプリ（Appx）のデフォルト規則を作成
    $appxRules = Get-AppxPackage -AllUsers | 
                 Select-Object -First 1 | 
                 Get-AppLockerFileInformation | 
                 New-AppLockerPolicy -RuleType Publisher -User Everyone -ErrorAction SilentlyContinue
    
    # パッケージアプリの規則を有効化
    $policy.RuleCollections | Where-Object {$_.RuleCollectionType -eq "Appx"} | ForEach-Object {
        $_.EnforcementMode = "Enabled"
    }
    
    # Appxの規則が空の場合、デフォルト規則を追加
    if ($null -ne $appxRules) {
        $appxCollection = $policy.RuleCollections | Where-Object {$_.RuleCollectionType -eq "Appx"}
        if ($appxCollection.Count -eq 0 -or $appxCollection[0].Count -eq 0) {
            $appxRulesCollection = $appxRules.RuleCollections | Where-Object {$_.RuleCollectionType -eq "Appx"}
            foreach ($rule in $appxRulesCollection) {
                $policy.RuleCollections.Add($rule)
            }
        }
    }
    
    # Windowsインストーラーの規則を無効化
    $policy.RuleCollections | Where-Object {$_.RuleCollectionType -eq "Msi"} | ForEach-Object {
        $_.EnforcementMode = "NotConfigured"
    }
    
    # スクリプトの規則を無効化
    $policy.RuleCollections | Where-Object {$_.RuleCollectionType -eq "Script"} | ForEach-Object {
        $_.EnforcementMode = "NotConfigured"
    }
    
    # ポリシーを適用
    Set-AppLockerPolicy -PolicyObject $policy
    
    # 成功
    exit 0
    
} catch {
    # 失敗
    exit 1
}