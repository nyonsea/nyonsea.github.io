Import-Module "$PSScriptRoot\..\ADDomainInventory.psm1"

# 出力フォルダ
$reportFolder = "C:\ADInventoryReport"
if (-not (Test-Path $reportFolder)) { New-Item -ItemType Directory -Path $reportFolder | Out-Null }

# ドメインコントローラ一覧取得
$dcNames = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

# メンバPC一覧をファイルまたはADから取得
# 例：特定 OU 内のコンピュータを取得
$pcNames = Get-ADComputer -Filter * -SearchBase "OU=Computers,DC=contoso,DC=com" | Select-Object -ExpandProperty Name

# 資格情報（現在のユーザがドメイン管理者の場合、Credentialは省略可）
$cred = Get-Credential

# DC 情報収集
$dcResult = Get-DCInventory -DCNames $dcNames -Credential $cred -IncludeGPO -IncludeSysVol -IncludeDNS -IncludeServiceStatus

# メンバPC 情報収集
$pcResult = Get-MemberPCInventory -PCNames $pcNames -Credential $cred -IncludeApps -IncludeHotFix -IncludeLocalAdmins

# 出力
$dcResult | ConvertTo-Json -Depth 6 | Out-File "$reportFolder\DCInventory.json" -Encoding UTF8
$pcResult | ConvertTo-Json -Depth 6 | Out-File "$reportFolder\MemberPCInventory.json" -Encoding UTF8

# また CSV 出力も
$dcCsv = $dcResult | ForEach-Object {
    [PSCustomObject]@{
        Computer = $_.Computer
        OS       = $_.Inventory.Basic.OS
        OSVersion = $_.Inventory.Basic.OSVersion
        LastBoot = $_.Inventory.Basic.LastBootUpTime
    }
}
$dcCsv | Export-Csv "$reportFolder\DC_Summary.csv" -NoTypeInformation -Encoding UTF8

$pcCsv = $pcResult | ForEach-Object {
    [PSCustomObject]@{
        Computer = $_.Computer
        OS = $_.OS.Caption
        LastBoot = $_.OS.LastBootUpTime
        LocalAdminCount = if ($_.LocalAdmins) { ($_.LocalAdmins).Count } else { 0 }
    }
}
$pcCsv | Export-Csv "$reportFolder\MemberPC_Summary.csv" -NoTypeInformation -Encoding UTF8

Write-Host "レポート出力完了: $reportFolder"
