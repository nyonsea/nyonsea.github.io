@{
    ModuleVersion = "1.0.0"
    GUID = "d9b2f4d7-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    Author = "YourName"
    CompanyName = "YourCompany"
    Description = "Domain Controller & Member PC Inventory Module"
    FunctionsToExport = @(
        "Get-DCInventory",
        "Get-MemberPCInventory",
        "Get-InstalledApps",
        "Get-HotFixes",
        "Get-LocalUserAndGroups",
        "Write-Diag"
    )
    # 他の .psd1 フィールド（RequiredModulesなど）を必要に応じて追加
    RequiredModules = @("ActiveDirectory","GroupPolicy")
}
