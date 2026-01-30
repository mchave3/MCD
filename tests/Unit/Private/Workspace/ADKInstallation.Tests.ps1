BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\..\.." | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Get-MCDADKInstaller' {
    Context 'Parameter Validation' {
        It 'Has optional IncludeWinPE switch parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDADKInstaller'
                $param = $cmd.Parameters['IncludeWinPE']

                $param | Should -Not -BeNullOrEmpty
                $param.SwitchParameter | Should -BeTrue
            }
        }

        It 'Returns ADKInstallerModel type' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDADKInstaller'
                $outputType = $cmd.OutputType.Name

                $outputType | Should -Contain 'ADKInstallerModel'
            }
        }
    }

    Context 'When ADK is not installed' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Test-Path -ModuleName $script:moduleName -ParameterFilter { $Path -like '*Windows Kits*' } -MockWith { $false }
        }

        It 'Returns model with IsInstalled = false' {
            InModuleScope $script:moduleName {
                $result = Get-MCDADKInstaller

                $result | Should -Not -BeNullOrEmpty
                $result.IsInstalled | Should -BeFalse
            }
        }
    }

    Context 'When registry path does not exist' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Test-Path -ModuleName $script:moduleName -ParameterFilter { $Path -eq 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots' } -MockWith { $false }
        }

        It 'Returns model with IsInstalled = false' {
            InModuleScope $script:moduleName {
                $result = Get-MCDADKInstaller

                $result | Should -Not -BeNullOrEmpty
                $result.IsInstalled | Should -BeFalse
            }
        }
    }

    Context 'ADKInstallerModel construction' {
        It 'Creates valid default model' {
            InModuleScope $script:moduleName {
                $model = [ADKInstallerModel]::new()

                $model.IsInstalled | Should -BeFalse
                $model.HasWinPEAddOn | Should -BeFalse
                $model.DetectedAt | Should -Not -BeNullOrEmpty
            }
        }

        It 'Creates model with install path' {
            InModuleScope $script:moduleName {
                $model = [ADKInstallerModel]::new('C:\Test\ADK')

                $model.InstallPath | Should -Be 'C:\Test\ADK'
                $model.IsInstalled | Should -BeFalse
            }
        }

        It 'Throws on null install path in constructor' {
            InModuleScope $script:moduleName {
                { [ADKInstallerModel]::new('') } | Should -Throw '*cannot be null or empty*'
            }
        }

        It 'Serializes to hashtable correctly' {
            InModuleScope $script:moduleName {
                $model = [ADKInstallerModel]::new()
                $model.Version = '10.1.12345.0'
                $model.InstallPath = 'C:\Test\ADK'
                $model.IsInstalled = $true

                $hash = $model.ToHashtable()

                $hash.version | Should -Be '10.1.12345.0'
                $hash.installPath | Should -Be 'C:\Test\ADK'
                $hash.isInstalled | Should -BeTrue
            }
        }

        It 'Deserializes from hashtable correctly' {
            InModuleScope $script:moduleName {
                $hash = @{
                    version        = '10.1.12345.0'
                    installPath    = 'C:\Test\ADK'
                    winPEAddOnPath = 'C:\Test\ADK\WinPE'
                    isInstalled    = $true
                    hasWinPEAddOn  = $true
                    dismPath       = 'C:\Test\ADK\DISM\dism.exe'
                    oscdimgPath    = 'C:\Test\ADK\Oscdimg\oscdimg.exe'
                    detectedAt     = (Get-Date).ToString('o')
                }

                $model = [ADKInstallerModel]::FromHashtable($hash)

                $model.Version | Should -Be '10.1.12345.0'
                $model.InstallPath | Should -Be 'C:\Test\ADK'
                $model.IsInstalled | Should -BeTrue
                $model.HasWinPEAddOn | Should -BeTrue
            }
        }

        It 'Validate throws when IsInstalled but no InstallPath' {
            InModuleScope $script:moduleName {
                $model = [ADKInstallerModel]::new()
                $model.IsInstalled = $true

                { $model.Validate() } | Should -Throw '*InstallPath is required*'
            }
        }

        It 'Validate throws when HasWinPEAddOn but no WinPEAddOnPath' {
            InModuleScope $script:moduleName {
                $model = [ADKInstallerModel]::new()
                $model.IsInstalled = $true
                $model.InstallPath = 'C:\Test\ADK'
                $model.HasWinPEAddOn = $true

                { $model.Validate() } | Should -Throw '*WinPEAddOnPath is required*'
            }
        }
    }
}

Describe 'Start-MCDADKDownloadWithRetry' {
    Context 'Parameter Validation' {
        It 'Has mandatory Uri parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Start-MCDADKDownloadWithRetry'
                $param = $cmd.Parameters['Uri']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory DestinationPath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Start-MCDADKDownloadWithRetry'
                $param = $cmd.Parameters['DestinationPath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has MaxRetries parameter with default 3' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Start-MCDADKDownloadWithRetry'
                $param = $cmd.Parameters['MaxRetries']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has RetryDelaySeconds parameter with default 5' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Start-MCDADKDownloadWithRetry'
                $param = $cmd.Parameters['RetryDelaySeconds']

                $param | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'When file already exists' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Returns existing file without downloading when Force not specified' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'existing.exe'
                Set-Content -Path $testFile -Value 'test content'

                $result = Start-MCDADKDownloadWithRetry -Uri 'https://example.com/file.exe' -DestinationPath $testFile

                $result | Should -Not -BeNullOrEmpty
                $result.FullName | Should -Be $testFile
            }
        }
    }

    Context 'Download behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-Command -ModuleName $script:moduleName -ParameterFilter { $Name -eq 'Start-BitsTransfer' } -MockWith {
                return @{ Name = 'Start-BitsTransfer' }
            }
        }

        It 'Uses BITS transfer when available' {
            # Mock inside InModuleScope so Start-BitsTransfer can create the file properly
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                Mock Start-BitsTransfer -MockWith {
                    param($Source, $Destination)
                    Set-Content -Path $Destination -Value 'downloaded content'
                }

                $destPath = Join-Path -Path $TestDrive -ChildPath 'downloaded.exe'
                $result = Start-MCDADKDownloadWithRetry -Uri 'https://example.com/file.exe' -DestinationPath $destPath

                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke Start-BitsTransfer -ModuleName $script:moduleName -Times 1
        }
    }

    Context 'Retry behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Start-Sleep -ModuleName $script:moduleName
            Mock Get-Command -ModuleName $script:moduleName -ParameterFilter { $Name -eq 'Start-BitsTransfer' } -MockWith {
                return @{ Name = 'Start-BitsTransfer' }
            }
        }

        It 'Retries specified number of times on failure' {
            Mock Start-BitsTransfer -ModuleName $script:moduleName -MockWith { throw 'Download failed' }

            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $destPath = Join-Path -Path $TestDrive -ChildPath 'retry.exe'

                { Start-MCDADKDownloadWithRetry -Uri 'https://example.com/file.exe' -DestinationPath $destPath -MaxRetries 2 } | Should -Throw '*Failed to download*after 2 attempts*'
            }

            Should -Invoke Start-BitsTransfer -ModuleName $script:moduleName -Times 2
        }

        It 'Waits between retries' {
            Mock Start-BitsTransfer -ModuleName $script:moduleName -MockWith { throw 'Download failed' }

            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $destPath = Join-Path -Path $TestDrive -ChildPath 'retry2.exe'

                { Start-MCDADKDownloadWithRetry -Uri 'https://example.com/file.exe' -DestinationPath $destPath -MaxRetries 2 -RetryDelaySeconds 1 } | Should -Throw
            }

            Should -Invoke Start-Sleep -ModuleName $script:moduleName -Times 1
        }
    }
}

Describe 'Get-MCDADKDownloadUrl' {
    Context 'Parameter Validation' {
        It 'Has mandatory Component parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDADKDownloadUrl'
                $param = $cmd.Parameters['Component']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Validates Component to ADK or WinPE' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDADKDownloadUrl'
                $validateSet = $cmd.Parameters['Component'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }

                $validateSet.ValidValues | Should -Contain 'ADK'
                $validateSet.ValidValues | Should -Contain 'WinPE'
            }
        }
    }

    Context 'URL retrieval' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Returns string URL when successful' {
            # Mock the REST call to return simulated docs page
            Mock Invoke-RestMethod -ModuleName $script:moduleName -MockWith {
                return '<li><a href="https://go.microsoft.com/fwlink/?linkid=2243390" data-linktype="external">Download the Windows ADK</a></li>'
            }
            Mock Invoke-WebRequest -ModuleName $script:moduleName -MockWith {
                return @{
                    StatusCode = 302
                    Headers    = @{ Location = 'https://download.microsoft.com/download/adksetup.exe' }
                }
            }

            InModuleScope $script:moduleName {
                $result = Get-MCDADKDownloadUrl -Component 'ADK'

                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [string]
            }
        }

        It 'Throws when pattern not found on page' {
            Mock Invoke-RestMethod -ModuleName $script:moduleName -MockWith {
                return '<html><body>No ADK links here</body></html>'
            }

            InModuleScope $script:moduleName {
                { Get-MCDADKDownloadUrl -Component 'ADK' } | Should -Throw '*Failed to retrieve*'
            }
        }
    }
}

Describe 'Install-MCDADK' {
    Context 'Parameter Validation' {
        It 'Has optional InstallPath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Install-MCDADK'
                $param = $cmd.Parameters['InstallPath']

                $param | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has SkipIfInstalled switch' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Install-MCDADK'
                $param = $cmd.Parameters['SkipIfInstalled']

                $param | Should -Not -BeNullOrEmpty
                $param.SwitchParameter | Should -BeTrue
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Install-MCDADK'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
            }
        }
    }

    Context 'When SkipIfInstalled and ADK exists' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            # Create mock inside InModuleScope to access the class
            InModuleScope $script:moduleName {
                Mock Get-MCDADKInstaller -MockWith {
                    $model = [ADKInstallerModel]::new()
                    $model.IsInstalled = $true
                    $model.InstallPath = 'C:\Windows Kits\10\ADK'
                    $model.Version = '10.1.12345.0'
                    return $model
                }
            }
        }

        It 'Returns existing installation without downloading' {
            InModuleScope $script:moduleName {
                $result = Install-MCDADK -SkipIfInstalled

                $result.IsInstalled | Should -BeTrue
                $result.InstallPath | Should -Be 'C:\Windows Kits\10\ADK'
            }
        }
    }

    Context 'Installation process' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            # Create mocks inside InModuleScope to access the class
            InModuleScope $script:moduleName {
                Mock Get-MCDADKInstaller -MockWith {
                    $model = [ADKInstallerModel]::new()
                    $model.IsInstalled = $false
                    return $model
                }
                Mock Get-MCDADKDownloadUrl -MockWith { 'https://example.com/adksetup.exe' }
                Mock Start-MCDADKDownloadWithRetry
                Mock Start-Process -MockWith {
                    return @{ ExitCode = 0 }
                }
            }
            Mock Test-Path -ModuleName $script:moduleName -ParameterFilter { $Path -like '*adksetup.exe*' } -MockWith { $true }
            Mock Remove-Item -ModuleName $script:moduleName
        }

        It 'Downloads installer when not installed' {
            InModuleScope $script:moduleName {
                $null = Install-MCDADK
            }

            Should -Invoke Start-MCDADKDownloadWithRetry -ModuleName $script:moduleName -Times 1
        }

        It 'Runs silent installation' {
            InModuleScope $script:moduleName {
                $null = Install-MCDADK
            }

            Should -Invoke Start-Process -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $ArgumentList -like '*/quiet*' -and $ArgumentList -like '*/features OptionId.DeploymentTools*'
            }
        }

        It 'Handles exit code 3010 (reboot required) as success' {
            InModuleScope $script:moduleName {
                Mock Start-Process -MockWith {
                    return @{ ExitCode = 3010 }
                }
                # Should not throw
                { Install-MCDADK } | Should -Not -Throw
            }
        }

        It 'Throws on other non-zero exit codes' {
            InModuleScope $script:moduleName {
                Mock Start-Process -MockWith {
                    return @{ ExitCode = 1603 }
                }
                { Install-MCDADK } | Should -Throw '*failed with exit code: 1603*'
            }
        }

        It 'Cleans up installer file' {
            InModuleScope $script:moduleName {
                $null = Install-MCDADK
            }

            Should -Invoke Remove-Item -ModuleName $script:moduleName -Times 1
        }
    }

    Context 'WhatIf behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            InModuleScope $script:moduleName {
                Mock Get-MCDADKInstaller -MockWith {
                    $model = [ADKInstallerModel]::new()
                    $model.IsInstalled = $false
                    return $model
                }
                Mock Get-MCDADKDownloadUrl -MockWith { 'https://example.com/adksetup.exe' }
                Mock Start-MCDADKDownloadWithRetry
                Mock Start-Process
            }
        }

        It 'Does not install when WhatIf specified' {
            InModuleScope $script:moduleName {
                $null = Install-MCDADK -WhatIf
            }

            Should -Invoke Start-Process -ModuleName $script:moduleName -Times 0
        }
    }
}

Describe 'Install-MCDWinPEComponents' {
    Context 'Parameter Validation' {
        It 'Has optional InstallPath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Install-MCDWinPEComponents'
                $param = $cmd.Parameters['InstallPath']

                $param | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has SkipIfInstalled switch' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Install-MCDWinPEComponents'
                $param = $cmd.Parameters['SkipIfInstalled']

                $param | Should -Not -BeNullOrEmpty
                $param.SwitchParameter | Should -BeTrue
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Install-MCDWinPEComponents'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
            }
        }
    }

    Context 'When SkipIfInstalled and WinPE exists' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            InModuleScope $script:moduleName {
                Mock Get-MCDADKInstaller -MockWith {
                    $model = [ADKInstallerModel]::new()
                    $model.IsInstalled = $true
                    $model.InstallPath = 'C:\Windows Kits\10\ADK'
                    $model.HasWinPEAddOn = $true
                    $model.WinPEAddOnPath = 'C:\Windows Kits\10\ADK\Windows Preinstallation Environment'
                    return $model
                }
            }
        }

        It 'Returns existing installation without downloading' {
            InModuleScope $script:moduleName {
                $result = Install-MCDWinPEComponents -SkipIfInstalled

                $result.HasWinPEAddOn | Should -BeTrue
            }
        }
    }

    Context 'When ADK is not installed' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            InModuleScope $script:moduleName {
                Mock Get-MCDADKInstaller -MockWith {
                    $model = [ADKInstallerModel]::new()
                    $model.IsInstalled = $false
                    return $model
                }
            }
        }

        It 'Throws error requiring ADK first' {
            InModuleScope $script:moduleName {
                { Install-MCDWinPEComponents } | Should -Throw '*Windows ADK must be installed*'
            }
        }
    }

    Context 'Installation process' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            InModuleScope $script:moduleName {
                # ADK installed without WinPE
                Mock Get-MCDADKInstaller -MockWith {
                    $model = [ADKInstallerModel]::new()
                    $model.IsInstalled = $true
                    $model.InstallPath = 'C:\Windows Kits\10\ADK'
                    $model.HasWinPEAddOn = $false
                    return $model
                }
                Mock Get-MCDADKDownloadUrl -MockWith { 'https://example.com/adkwinpesetup.exe' }
                Mock Start-MCDADKDownloadWithRetry
                Mock Start-Process -MockWith {
                    return @{ ExitCode = 0 }
                }
            }
            Mock Test-Path -ModuleName $script:moduleName -ParameterFilter { $Path -like '*adkwinpesetup.exe*' } -MockWith { $true }
            Mock Remove-Item -ModuleName $script:moduleName
        }

        It 'Downloads WinPE installer' {
            InModuleScope $script:moduleName {
                $null = Install-MCDWinPEComponents
            }

            Should -Invoke Start-MCDADKDownloadWithRetry -ModuleName $script:moduleName -Times 1
        }

        It 'Runs silent installation with WinPE feature' {
            InModuleScope $script:moduleName {
                $null = Install-MCDWinPEComponents
            }

            Should -Invoke Start-Process -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $ArgumentList -like '*/quiet*' -and $ArgumentList -like '*/features OptionId.WindowsPreinstallationEnvironment*'
            }
        }

        It 'Handles exit code 3010 (reboot required) as success' {
            InModuleScope $script:moduleName {
                Mock Start-Process -MockWith {
                    return @{ ExitCode = 3010 }
                }
                { Install-MCDWinPEComponents } | Should -Not -Throw
            }
        }
    }
}
