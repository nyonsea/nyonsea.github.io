# Pester v5 形式
# このテストは AADomainInventory.psm1 内の全関数を対象とします

param (
    [string]$ModulePath = "..\ADDomainInventory.psm1",
    [pscredential]$Credential = $null
)

Import-Module $ModulePath -Force

Describe "ADDomainInventory Module Tests" {

    Context "ドメイン情報" {
        It "Get-ADDomainInfo should return domain details" {
            $result = Get-ADDomainInfo -Credential $Credential
            $result | Should -Not -BeNullOrEmpty
            $result.DomainName | Should -Not -BeNullOrEmpty
        }

        It "Get-ADForestInfo should return forest details" {
            $result = Get-ADForestInfo -Credential $Credential
            $result | Should -Not -BeNullOrEmpty
            $result.ForestName | Should -Not -BeNullOrEmpty
        }

        It "Get-ADSiteInfo should return site details" {
            $result = Get-ADSiteInfo -Credential $Credential
            $result | Should -BeOfType [System.Collections.IEnumerable]
        }
    }

    Context "ドメインコントローラ" {
        It "Get-ADDomainControllers should list DCs" {
            $result = Get-ADDomainControllers -Credential $Credential
            $result | Should -Not -BeNullOrEmpty
            ($result | Get-Member -Name "HostName") | Should -Not -BeNullOrEmpty
        }
    }

    Context "ユーザーとグループ" {
        It "Get-ADUserInventory should return users" {
            $result = Get-ADUserInventory -Credential $Credential -ResultSize 10
            $result | Should -BeOfType [System.Collections.IEnumerable]
        }

        It "Get-ADGroupInventory should return groups" {
            $result = Get-ADGroupInventory -Credential $Credential
            $result | Should -BeOfType [System.Collections.IEnumerable]
        }
    }

    Context "コンピュータ" {
        It "Get-ADComputerInventory should return computers" {
            $result = Get-ADComputerInventory -Credential $Credential -ResultSize 10
            $result | Should -BeOfType [System.Collections.IEnumerable]
        }

        It "Get-LocalUserAndGroups should return local users/groups for remote computer" {
            $comp = (Get-ADComputerInventory -Credential $Credential -ResultSize 1).Name
            $result = Get-LocalUserAndGroups -ComputerName $comp -Credential $Credential
            $result | Should -Not -BeNullOrEmpty
            ($result | Get-Member -Name "LocalUsers") | Should -Not -BeNullOrEmpty
        }

        It "Get-InstalledSoftware should return software list for remote computer" {
            $comp = (Get-ADComputerInventory -Credential $Credential -ResultSize 1).Name
            $result = Get-InstalledSoftware -ComputerName $comp -Credential $Credential
            $result | Should -BeOfType [System.Collections.IEnumerable]
        }

        It "Get-OSAndHardwareInfo should return OS/Hardware info" {
            $comp = (Get-ADComputerInventory -Credential $Credential -ResultSize 1).Name
            $result = Get-OSAndHardwareInfo -ComputerName $comp -Credential $Credential
            $result | Should -Not -BeNullOrEmpty
            $result.OSVersion | Should -Not -BeNullOrEmpty
        }

        It "Get-UpdateStatus should return Windows Update info" {
            $comp = (Get-ADComputerInventory -Credential $Credential -ResultSize 1).Name
            $result = Get-UpdateStatus -ComputerName $comp -Credential $Credential
            $result | Should -BeOfType [System.Collections.IEnumerable]
        }
    }
}
