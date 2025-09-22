#2. ADユーザーの有効/無効化
function Set-AdUserStatus {
    <#
    .SYNOPSIS
        ADユーザーを有効化または無効化する
    .EXAMPLE
        Set-AdUserStatus -SamAccountName user1 -Enabled:$false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName,

        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    $user = Get-ADUser -Identity $SamAccountName -ErrorAction Stop
    if ($Enabled) {
        Enable-ADAccount -Identity $user
    } else {
        Disable-ADAccount -Identity $user
    }
}