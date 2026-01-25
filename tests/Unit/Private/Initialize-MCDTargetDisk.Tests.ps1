BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Initialize-MCDTargetDisk' {
    It 'Throws when DiskPolicy.AllowDestructiveActions is disabled' {
        InModuleScope $script:moduleName {
            { Initialize-MCDTargetDisk -DiskNumber 0 -DiskPolicy ([pscustomobject]@{ AllowDestructiveActions = $false }) } | Should -Throw
        }
    }

    It 'Clears and partitions the disk when allowed' {
        InModuleScope $script:moduleName {
            Mock Get-Disk -MockWith { [pscustomobject]@{ Number = 0 } }
            Mock Clear-Disk
            Mock Initialize-Disk
            Mock New-Partition
            Mock Format-Volume

            $script:call = 0
            Mock Get-MCDAvailableDriveLetter -MockWith {
                $script:call++
                if ($script:call -eq 1) { return 'S' }
                return 'W'
            }

            $result = Initialize-MCDTargetDisk -DiskNumber 0 -DiskPolicy ([pscustomobject]@{ AllowDestructiveActions = $true }) -Confirm:$false

            $result.DiskNumber | Should -Be 0
            $result.SystemDriveLetter | Should -Be 'S'
            $result.WindowsDriveLetter | Should -Be 'W'

            Assert-MockCalled Clear-Disk -Times 1
            Assert-MockCalled Initialize-Disk -Times 1
            Assert-MockCalled New-Partition -Times 3
            Assert-MockCalled Format-Volume -Times 2
        }
    }
}
