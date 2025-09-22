#3. ADユーザーのパスワード期限チェック
function Get-AdUserPasswordExpiry {
    <#
    .SYNOPSIS
        ユーザーのパスワード有効期限を確認
    .EXAMPLE
        Get-AdUserPasswordExpiry -SamAccountName user1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName
    )

    $user = Get-ADUser -Identity $SamAccountName -Properties "msDS-UserPasswordExpiryTimeComputed"
    $expiry = [datetime]::FromFileTime($user."msDS-UserPasswordExpiryTimeComputed")
    [PSCustomObject]@{
        User   = $SamAccountName
        Expiry = $expiry
    }
}