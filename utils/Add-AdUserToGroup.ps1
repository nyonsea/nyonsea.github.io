#6. グループにユーザーを追加
function Add-AdUserToGroup {
    <#
    .SYNOPSIS
        指定ユーザーをグループに追加
    .EXAMPLE
        Add-AdUserToGroup -SamAccountName user1 -GroupName "IT-Admins"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName,

        [Parameter(Mandatory)]
        [string]$GroupName
    )

    try {
        Add-ADGroupMember -Identity $GroupName -Members $SamAccountName
        Write-Verbose "Added $SamAccountName to $GroupName"
    } catch {
        Write-Warning "Failed to add $SamAccountName: $_"
    }
}