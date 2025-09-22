function Get-Hello {
    param([string]$Name)
    "Hello, $Name"
}

function Get-Goodbye {
    param([string]$Name)
    "Goodbye, $Name"
}

function Get-DateInfo {
    "Today is: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}

# ���J����֐����w��i���̏ꍇ��2�����j
#Export-ModuleMember -Function Get-Hello, Get-DateInfo,Get-Goodbye
