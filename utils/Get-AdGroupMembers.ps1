#5. グループメンバー一覧
function Get-AdGroupMembers {
    <#
    .SYNOPSIS
        グループメンバー一覧を取得
    .EXAMPLE
        Get-AdGroupMembers -GroupName "Domain Admins"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName
    )

    Get-ADGroupMember -Identity $GroupName | Select-Object Name, SamAccountName, ObjectClass
}