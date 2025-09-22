#8. ADコンピュータアカウントの無効化
function Disable-AdComputer {
    <#
    .SYNOPSIS
        コンピュータアカウントを無効化
    .EXAMPLE
        Disable-AdComputer -ComputerName PC01
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    Disable-ADAccount -Identity $ComputerName
}