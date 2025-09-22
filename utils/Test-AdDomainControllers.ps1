#10. ADドメインコントローラの稼働確認
function Test-AdDomainControllers {
    <#
    .SYNOPSIS
        ドメインコントローラの疎通確認
    .EXAMPLE
        Test-AdDomainControllers
    #>
    [CmdletBinding()]
    param()

    Get-ADDomainController -Filter * | ForEach-Object {
        Test-Connection -ComputerName $_.HostName -Count 2 -Quiet |
            ForEach-Object {
                [PSCustomObject]@{
                    DCName  = $_.HostName
                    Reachable = $_
                }
            }
    }
}