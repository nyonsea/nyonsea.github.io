function Invoke-Check($name, [ScriptBlock]$check) {
    try {
        $result = & $check
        [PSCustomObject]@{ Name=$name; Status="OK"; Detail=$result }
    } catch {
        [PSCustomObject]@{ Name=$name; Status="NG"; Detail=$_.Exception.Message }
    }
}

Invoke-Check "DiskC" { Get-PSDrive C | Where-Object Used -gt 100GB }
Invoke-Check "WinRM" { Test-NetConnection -ComputerName server1 -Port 5985 }
