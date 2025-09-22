#7. グループからユーザーを削除
function Remove-AdUserFromGroup {
    <#
    .SYNOPSIS
        グループからユーザーを削除
    .EXAMPLE
        Remove-AdUserFromGroup -SamAccountName user1 -GroupName "IT-Admins"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName,

        [Parameter(Mandatory)]
        [string]$GroupName
    )

    try {
        Remove-ADGroupMember -Identity $GroupName -Members $SamAccountName -Confirm:$false
        Write-Verbose "Removed $SamAccountName from $GroupName"
    } catch {
        Write-Warning "Failed to remove $SamAccountName: $_"
    }
}