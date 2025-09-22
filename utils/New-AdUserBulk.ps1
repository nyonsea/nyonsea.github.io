#1. ADユーザーを一括作成
function New-AdUserBulk {
    <#
    .SYNOPSIS
        CSVを基にADユーザーを一括作成
    .EXAMPLE
        New-AdUserBulk -CsvPath .\users.csv
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath
    )

    Import-Csv -Path $CsvPath | ForEach-Object {
        try {
            New-ADUser -Name $_.Name -SamAccountName $_.SamAccountName `
                       -UserPrincipalName $_.UserPrincipalName `
                       -AccountPassword (ConvertTo-SecureString $_.Password -AsPlainText -Force) `
                       -Enabled $true
            Write-Verbose "User [$($_.SamAccountName)] created"
        } catch {
            Write-Warning "Failed to create user [$($_.SamAccountName)]: $_"
        }
    }
}