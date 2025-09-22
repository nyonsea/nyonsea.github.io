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

# 公開する関数を指定（この場合は2つだけ）
#Export-ModuleMember -Function Get-Hello, Get-DateInfo,Get-Goodbye
