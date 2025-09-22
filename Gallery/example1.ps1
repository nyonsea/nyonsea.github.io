Import-Module ADDomainInventory

#============================================================
# ドメインコントローラの収集
#============================================================
$dcNames = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName
$dcResult = Get-DCInventory -DCNames $dcNames -IncludeGPO -IncludeSysVol -IncludeDNS -IncludeServiceStatus

#============================================================
# OU配下のメンバPCの収集
#============================================================
$pcNames = Get-ADComputer -Filter * -SearchBase "OU=Computers,DC=contoso,DC=com" | Select-Object -ExpandProperty Name
$pcResult = Get-MemberPCInventory -PCNames $pcNames -IncludeApps -IncludeHotFix -IncludeLocalAdmins

#============================================================
# 個別PC単位の補助関数呼び出し例
#============================================================
$computer = $pcNames[0]

# アプリ一覧
$apps = Get-InstalledApps -ComputerName $computer

# 適用済みHotFix
$hotfixes = Get-HotFixes -ComputerName $computer

# ローカル管理者グループのメンバー
$localAdmins = Get-LocalAdmins -ComputerName $computer

# サービス状態
$svcStatus = Get-ServiceStatus -ComputerName $computer

# ローカルユーザとグループ情報
$localUserGroups = Get-LocalUserAndGroups -ComputerName $computer

#============================================================
# 診断ログ出力例
#============================================================
Write-Diag -Message "DC収集結果: $($dcResult.Count) 件" -Level INFO
Write-Diag -Message "PC収集結果: $($pcResult.Count) 件" -Level INFO

#============================================================
# 出力
#============================================================
$dcResult           | ConvertTo-Json -Depth 6 | Out-File DCInventory.json -Encoding UTF8
$pcResult           | Export-Csv MemberPCInventory.csv -NoTypeInformation -Encoding UTF8
$apps               | Export-Csv InstalledApps.csv -NoTypeInformation -Encoding UTF8
$hotfixes           | Export-Csv HotFixes.csv -NoTypeInformation -Encoding UTF8
$localAdmins        | Export-Csv LocalAdmins.csv -NoTypeInformation -Encoding UTF8
$svcStatus          | Export-Csv ServiceStatus.csv -NoTypeInformation -Encoding UTF8
$localUserGroups    | Export-Csv LocalUserAndGroups.csv -NoTypeInformation -Encoding UTF8
