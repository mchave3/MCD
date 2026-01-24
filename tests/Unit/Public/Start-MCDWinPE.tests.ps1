BeforeAll {
    $script:dscModuleName = 'MCD'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Start-MCDWinPE' {
    BeforeAll {
        # Mock private functions to avoid side effects
        Mock -CommandName Test-MCDPrerequisite -MockWith {
            return $true
        } -ModuleName $dscModuleName

        Mock -CommandName Test-MCDNetwork -MockWith {
            return $true
        } -ModuleName $dscModuleName

        Mock -CommandName Get-MCDConfig -MockWith {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                return $config
            }
        } -ModuleName $dscModuleName

        # Mock Get-Volume to avoid actual disk operations
        Mock -CommandName Get-Volume -MockWith {
            return @()
        } -ModuleName $dscModuleName
    }

    Context 'When checking command parameters' {
        It 'Should have ConfigPath parameter' {
            (Get-Command -Name 'Start-MCDWinPE').Parameters.ContainsKey('ConfigPath') | Should -BeTrue
        }

        It 'Should have WorkingPath parameter' {
            (Get-Command -Name 'Start-MCDWinPE').Parameters.ContainsKey('WorkingPath') | Should -BeTrue
        }

        It 'Should have NoGui parameter' {
            (Get-Command -Name 'Start-MCDWinPE').Parameters.ContainsKey('NoGui') | Should -BeTrue
        }

        It 'Should support WhatIf parameter' {
            (Get-Command -Name 'Start-MCDWinPE').Parameters.ContainsKey('WhatIf') | Should -BeTrue
        }

        It 'Should support Confirm parameter' {
            (Get-Command -Name 'Start-MCDWinPE').Parameters.ContainsKey('Confirm') | Should -BeTrue
        }
    }

    Context 'When running with NoGui' {
        It 'Should return MCDDeployment object' {
            $testPath = Join-Path -Path $TestDrive -ChildPath 'WinPETest1'
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            $result = Start-MCDWinPE -WorkingPath $testPath -NoGui -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should call Test-MCDPrerequisite' {
            $testPath = Join-Path -Path $TestDrive -ChildPath 'WinPETest2'
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            Start-MCDWinPE -WorkingPath $testPath -NoGui -Confirm:$false

            Should -Invoke -CommandName Test-MCDPrerequisite -ModuleName $dscModuleName
        }

        It 'Should call Test-MCDNetwork' {
            $testPath = Join-Path -Path $TestDrive -ChildPath 'WinPETest3'
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            Start-MCDWinPE -WorkingPath $testPath -NoGui -Confirm:$false

            Should -Invoke -CommandName Test-MCDNetwork -ModuleName $dscModuleName
        }

        It 'Should create deployment with custom working path' {
            $testPath = Join-Path -Path $TestDrive -ChildPath 'CustomPath'
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            $result = Start-MCDWinPE -WorkingPath $testPath -NoGui -Confirm:$false

            $result.WorkingPath | Should -Be $testPath
        }

        It 'Should have a valid SessionId' {
            $testPath = Join-Path -Path $TestDrive -ChildPath 'SessionTest'
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            $result = Start-MCDWinPE -WorkingPath $testPath -NoGui -Confirm:$false

            $result.SessionId | Should -Not -BeNullOrEmpty
            { [guid]::Parse($result.SessionId) } | Should -Not -Throw
        }
    }

    Context 'When WhatIf is specified' {
        It 'Should not create directories with WhatIf' {
            $testPath = Join-Path -Path $TestDrive -ChildPath 'WhatIfWinPE'

            Start-MCDWinPE -WorkingPath $testPath -NoGui -WhatIf

            # With WhatIf, the working directory should not be created
            Test-Path -Path (Join-Path -Path $testPath -ChildPath 'Logs') | Should -BeFalse
        }
    }

    Context 'When network is unavailable' {
        It 'Should continue even when network check fails' {
            Mock -CommandName Test-MCDNetwork -MockWith {
                return $false
            } -ModuleName $dscModuleName

            $testPath = Join-Path -Path $TestDrive -ChildPath 'NoNetwork'
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            # Should not throw even with no network
            { Start-MCDWinPE -WorkingPath $testPath -NoGui -Confirm:$false } | Should -Not -Throw
        }
    }
}
