#9. FSMO 役割の所有者確認
function Get-AdFsmoRoles {
    <#
    .SYNOPSIS
        FSMO役割の所有者を確認
    .EXAMPLE
        Get-AdFsmoRoles
    #>
    [CmdletBinding()]
    param()

    netdom query fsmo
}