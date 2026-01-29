BeforeAll {
    $ProjectRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $SourcePath = Join-Path -Path $ProjectRoot -ChildPath 'source'

    # Dot-source helper functions required by steps
    . (Join-Path -Path $SourcePath -ChildPath 'Private/Core/Logging/Write-MCDLog.ps1')
    . (Join-Path -Path $SourcePath -ChildPath 'Private/Core/Environment/Get-MCDExecutionContext.ps1')

    # Dot-source dependencies that steps call
    . (Join-Path -Path $SourcePath -ChildPath 'Private/WinPE/Bootstrap/Update-MCDFromPSGallery.ps1')
    . (Join-Path -Path $SourcePath -ChildPath 'Private/WinPE/Disk/Initialize-MCDTargetDisk.ps1')

    # Dot-source the step functions
    . (Join-Path -Path $SourcePath -ChildPath 'Private/Steps/Step-MCDValidateSelection.ps1')
    . (Join-Path -Path $SourcePath -ChildPath 'Private/Steps/Step-MCDPrepareDisk.ps1')
    . (Join-Path -Path $SourcePath -ChildPath 'Private/Steps/Step-MCDPrepareEnvironment.ps1')
    . (Join-Path -Path $SourcePath -ChildPath 'Private/Steps/Step-MCDCopyWinPELogs.ps1')
    . (Join-Path -Path $SourcePath -ChildPath 'Private/Steps/Step-MCDDeployWindows.ps1')
    . (Join-Path -Path $SourcePath -ChildPath 'Private/Steps/Step-MCDCompleteDeployment.ps1')

    # Mock external dependencies
    Mock -CommandName Start-Transcript -MockWith { }
    Mock -CommandName Stop-Transcript -MockWith { }
    Mock -CommandName Write-MCDLog -MockWith { }
    Mock -CommandName Update-MCDFromPSGallery -MockWith { $true }
    Mock -CommandName Initialize-MCDTargetDisk -MockWith {
        [PSCustomObject]@{
            DiskNumber         = 0
            PartitionStyle     = 'GPT'
            SystemDriveLetter  = 'S'
            WindowsDriveLetter = 'W'
        }
    }
    Mock -CommandName Get-ChildItem -MockWith { @() }
    Mock -CommandName Copy-Item -MockWith { }
    Mock -CommandName New-Item -MockWith { }
    Mock -CommandName Test-Path -MockWith { $true }

    # Set up global workflow context
    $global:MCDWorkflowIsWinPE = $false
    $global:MCDWorkflowCurrentStepIndex = 1
    $global:MCDWorkflowContext = @{
        Window      = $null
        CurrentStep = @{
            parameters = @{
                Selection = [pscustomobject]@{
                    OperatingSystem  = [pscustomobject]@{
                        DisplayName = 'Windows 11 Pro'
                        Id          = 'win11pro'
                    }
                    ComputerLanguage = 'en-US'
                    TargetDisk       = [pscustomobject]@{
                        DiskNumber = 0
                    }
                    WinPEConfig      = [pscustomobject]@{
                        DiskPolicy = [pscustomobject]@{
                            AllowDestructiveActions = $true
                        }
                    }
                }
            }
        }
        LogsRoot    = $env:TEMP
        StatePath   = 'C:\Windows\Temp\MCD\State.json'
        StartTime   = [datetime](Get-Date)
    }
}

Describe 'Step-MCDValidateSelection' {
    It 'Should load without errors' {
        { Get-Command -Name Step-MCDValidateSelection -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should return $true when selection is valid' {
        $result = Step-MCDValidateSelection
        $result | Should -Be $true
    }

    It 'Should throw when no selection is present' {
        $originalContext = $global:MCDWorkflowContext.CurrentStep
        $global:MCDWorkflowContext.CurrentStep = @{ parameters = @{} }
        $global:MCDWorkflowContext.Selection = $null

        { Step-MCDValidateSelection } | Should -Throw '*No deployment selection*'

        $global:MCDWorkflowContext.CurrentStep = $originalContext
    }
}

Describe 'Step-MCDPrepareDisk' {
    It 'Should load without errors' {
        { Get-Command -Name Step-MCDPrepareDisk -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should return $true on success' {
        $result = Step-MCDPrepareDisk
        $result | Should -Be $true
    }
}

Describe 'Step-MCDPrepareEnvironment' {
    It 'Should load without errors' {
        { Get-Command -Name Step-MCDPrepareEnvironment -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should return $true on success' {
        $result = Step-MCDPrepareEnvironment
        $result | Should -Be $true
    }
}

Describe 'Step-MCDCopyWinPELogs' {
    It 'Should load without errors' {
        { Get-Command -Name Step-MCDCopyWinPELogs -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should return $true when not in WinPE' {
        $global:MCDWorkflowIsWinPE = $false
        $result = Step-MCDCopyWinPELogs
        $result | Should -Be $true
    }
}

Describe 'Step-MCDDeployWindows' {
    It 'Should load without errors' {
        { Get-Command -Name Step-MCDDeployWindows -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should return $true (placeholder)' {
        $result = Step-MCDDeployWindows
        $result | Should -Be $true
    }
}

Describe 'Step-MCDCompleteDeployment' {
    It 'Should load without errors' {
        { Get-Command -Name Step-MCDCompleteDeployment -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should return $true on success' {
        $result = Step-MCDCompleteDeployment
        $result | Should -Be $true
    }
}

AfterAll {
    # Clean up global variables
    Remove-Variable -Name MCDWorkflowIsWinPE -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name MCDWorkflowCurrentStepIndex -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name MCDWorkflowContext -Scope Global -ErrorAction SilentlyContinue
}
