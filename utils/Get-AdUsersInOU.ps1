#4. OU配下のユーザー一覧
function Get-AdUsersInOU {
    <#
    .SYNOPSIS
        指定OU配下のユーザーを取得
    .EXAMPLE
        Get-AdUsersInOU -OU "OU=Sales,DC=example,DC=com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OU
    )

    Get-ADUser -Filter * -SearchBase $OU
}