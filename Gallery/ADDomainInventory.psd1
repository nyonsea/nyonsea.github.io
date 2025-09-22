## 2. ModuleManifest の拡張フィールド例（`ADDomainInventory.psd1`）

@{
    RootModule        = 'ADDomainInventory.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd9b2f4d7-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Author            = 'H.Shinozaki'
    CompanyName       = 'H.Shinozaki'
    Copyright         = '(c) 2025 H.Shinozaki. All rights reserved.'
    Description       = 'Domain Controller & Member PC Inventory Module for Active Directory environments.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    RequiredModules   = @('ActiveDirectory','GroupPolicy')

    FunctionsToExport = @(
        'Get-DCInventory',
        'Get-MemberPCInventory',
        'Get-InstalledApps',
        'Get-HotFixes',
        'Get-LocalUserAndGroups',
        'Write-Diag'
    )
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = '*'

    PrivateData = @{
        PSData = @{
            Tags         = @('ActiveDirectory','Inventory','DomainController','MemberPC','Security')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/YourGitHub/ADDomainInventory'
            IconUri      = 'https://raw.githubusercontent.com/YourGitHub/ADDomainInventory/main/icon.png'
            ReleaseNotes = 'Initial release with DC & MemberPC inventory functions.'
        }
    }
}
