BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Get-MCDTargetDiskCandidate' {
    It 'Returns disks excluding specified BusTypes' {
        InModuleScope $script:moduleName {
            Mock Get-Disk -MockWith {
                @(
                    [pscustomobject]@{ Number = 0; BusType = 'USB'; FriendlyName = 'USB'; PartitionStyle = 'RAW'; Size = 16GB }
                    [pscustomobject]@{ Number = 1; BusType = 'SATA'; FriendlyName = 'SSD'; PartitionStyle = 'RAW'; Size = 256GB }
                )
            }

            # In Windows PowerShell 5.1, a single PSCustomObject returned from the
            # pipeline is a scalar (no .Count). Wrap in @() for stable array behavior.
            $candidates = @(Get-MCDTargetDiskCandidate -ExcludeBusTypes @('USB'))
            $candidates.Count | Should -Be 1
            $candidates[0].DiskNumber | Should -Be 1
            $candidates[0].DisplayName | Should -Match 'Disk 1'
        }
    }
}
