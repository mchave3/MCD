BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\..\.." | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Get-MCDADKPaths' {
    Context 'Parameter Validation' {
        It 'Has mandatory ADKInfo parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDADKPaths'
                $param = $cmd.Parameters['ADKInfo']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory Architecture parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDADKPaths'
                $param = $cmd.Parameters['Architecture']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Validates Architecture to amd64 or arm64' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDADKPaths'
                $validateSet = $cmd.Parameters['Architecture'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }

                $validateSet.ValidValues | Should -Contain 'amd64'
                $validateSet.ValidValues | Should -Contain 'arm64'
            }
        }
    }

    Context 'Path resolution' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Returns hashtable with expected keys' {
            InModuleScope $script:moduleName {
                $adkInfo = [ADKInstallerModel]::new()
                $adkInfo.IsInstalled = $true
                $adkInfo.InstallPath = 'C:\ADK'
                $adkInfo.WinPEAddOnPath = 'C:\ADK\Windows Preinstallation Environment'

                Mock Test-Path -MockWith { $true }

                $result = Get-MCDADKPaths -ADKInfo $adkInfo -Architecture 'amd64'

                $result | Should -Not -BeNullOrEmpty
                $result.DeploymentToolsPath | Should -Not -BeNullOrEmpty
                $result.OscdimgPath | Should -Not -BeNullOrEmpty
                $result.OscdimgExe | Should -Not -BeNullOrEmpty
                $result.EtfsbootPath | Should -Not -BeNullOrEmpty
                $result.EfisysPath | Should -Not -BeNullOrEmpty
                $result.WinPEPath | Should -Not -BeNullOrEmpty
                $result.WinPEMediaPath | Should -Not -BeNullOrEmpty
                $result.WinPEWimPath | Should -Not -BeNullOrEmpty
                $result.WinPEOCsPath | Should -Not -BeNullOrEmpty
                $result.Architecture | Should -Be 'amd64'
            }
        }

        It 'Constructs correct paths for amd64' {
            InModuleScope $script:moduleName {
                $adkInfo = [ADKInstallerModel]::new()
                $adkInfo.IsInstalled = $true
                $adkInfo.InstallPath = 'C:\ADK'
                $adkInfo.WinPEAddOnPath = 'C:\ADK\Windows Preinstallation Environment'

                Mock Test-Path -MockWith { $true }

                $result = Get-MCDADKPaths -ADKInfo $adkInfo -Architecture 'amd64'

                $result.DeploymentToolsPath | Should -Be 'C:\ADK\Deployment Tools\amd64'
                $result.WinPEPath | Should -Be 'C:\ADK\Windows Preinstallation Environment\amd64'
            }
        }

        It 'Falls back to amd64 etfsboot.com for arm64 when missing' {
            InModuleScope $script:moduleName {
                $adkInfo = [ADKInstallerModel]::new()
                $adkInfo.IsInstalled = $true
                $adkInfo.InstallPath = 'C:\ADK'
                $adkInfo.WinPEAddOnPath = 'C:\ADK\Windows Preinstallation Environment'

                # Return false for arm64 etfsboot.com, true for amd64
                Mock Test-Path -MockWith {
                    param($Path)
                    if ($Path -like '*arm64*etfsboot.com*') { return $false }
                    return $true
                }

                $result = Get-MCDADKPaths -ADKInfo $adkInfo -Architecture 'arm64'

                $result.EtfsbootPath | Should -BeLike '*amd64*etfsboot.com'
            }
        }
    }
}

Describe 'Mount-MCDBootImage' {
    Context 'Parameter Validation' {
        It 'Has mandatory ImagePath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Mount-MCDBootImage'
                $param = $cmd.Parameters['ImagePath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory MountPath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Mount-MCDBootImage'
                $param = $cmd.Parameters['MountPath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has optional Index parameter with default 1' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Mount-MCDBootImage'
                $param = $cmd.Parameters['Index']

                $param | Should -Not -BeNullOrEmpty
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Mount-MCDBootImage'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
            }
        }
    }

    Context 'Path validation' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Throws when ImagePath does not exist' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                Mock Test-Path -MockWith { param($Path) return $false } -ParameterFilter { $Path -like '*boot.wim' }

                $fakePath = Join-Path -Path $TestDrive -ChildPath 'nonexistent.wim'

                { Mount-MCDBootImage -ImagePath $fakePath -MountPath $TestDrive } | Should -Throw '*not found*'
            }
        }

        It 'Throws when MountPath does not exist' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                # Create a fake WIM file
                $wimPath = Join-Path -Path $TestDrive -ChildPath 'boot.wim'
                Set-Content -Path $wimPath -Value 'fake wim'

                $fakeMountPath = Join-Path -Path $TestDrive -ChildPath 'nonexistent'

                { Mount-MCDBootImage -ImagePath $wimPath -MountPath $fakeMountPath } | Should -Throw '*Mount path does not exist*'
            }
        }
    }

    Context 'Mount behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-WindowsImage -ModuleName $script:moduleName -MockWith { @() }
            Mock Mount-WindowsImage -ModuleName $script:moduleName
        }

        It 'Calls Mount-WindowsImage with correct parameters' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                # Create test files
                $wimPath = Join-Path -Path $TestDrive -ChildPath 'boot.wim'
                $mountPath = Join-Path -Path $TestDrive -ChildPath 'mount'
                Set-Content -Path $wimPath -Value 'fake wim'
                $null = New-Item -Path $mountPath -ItemType Directory -Force

                Mount-MCDBootImage -ImagePath $wimPath -MountPath $mountPath
            }

            Should -Invoke Mount-WindowsImage -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $Index -eq 1
            }
        }

        It 'Logs mount operation' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $wimPath = Join-Path -Path $TestDrive -ChildPath 'boot2.wim'
                $mountPath = Join-Path -Path $TestDrive -ChildPath 'mount2'
                Set-Content -Path $wimPath -Value 'fake wim'
                $null = New-Item -Path $mountPath -ItemType Directory -Force

                Mount-MCDBootImage -ImagePath $wimPath -MountPath $mountPath
            }

            Should -Invoke Write-MCDLog -ModuleName $script:moduleName -ParameterFilter {
                $Message -like '*Mounting boot.wim*'
            }
        }
    }

    Context 'WhatIf behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-WindowsImage -ModuleName $script:moduleName -MockWith { @() }
            Mock Mount-WindowsImage -ModuleName $script:moduleName
        }

        It 'Does not mount when WhatIf specified' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $wimPath = Join-Path -Path $TestDrive -ChildPath 'boot3.wim'
                $mountPath = Join-Path -Path $TestDrive -ChildPath 'mount3'
                Set-Content -Path $wimPath -Value 'fake wim'
                $null = New-Item -Path $mountPath -ItemType Directory -Force

                Mount-MCDBootImage -ImagePath $wimPath -MountPath $mountPath -WhatIf
            }

            Should -Invoke Mount-WindowsImage -ModuleName $script:moduleName -Times 0
        }
    }
}

Describe 'Dismount-MCDBootImage' {
    Context 'Parameter Validation' {
        It 'Has mandatory MountPath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Dismount-MCDBootImage'
                $param = $cmd.Parameters['MountPath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has optional Save switch' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Dismount-MCDBootImage'
                $param = $cmd.Parameters['Save']

                $param | Should -Not -BeNullOrEmpty
                $param.SwitchParameter | Should -BeTrue
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Dismount-MCDBootImage'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
            }
        }
    }

    Context 'Dismount behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Dismount-WindowsImage -ModuleName $script:moduleName
        }

        It 'Calls Dismount-WindowsImage with Save when Save specified' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $mountPath = Join-Path -Path $TestDrive -ChildPath 'dismount1'
                $null = New-Item -Path $mountPath -ItemType Directory -Force

                Mock Get-WindowsImage -MockWith {
                    @([PSCustomObject]@{ Path = $mountPath })
                }

                Dismount-MCDBootImage -MountPath $mountPath -Save
            }

            Should -Invoke Dismount-WindowsImage -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $Save -eq $true
            }
        }

        It 'Calls Dismount-WindowsImage with Discard when Save not specified' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $mountPath = Join-Path -Path $TestDrive -ChildPath 'dismount2'
                $null = New-Item -Path $mountPath -ItemType Directory -Force

                Mock Get-WindowsImage -MockWith {
                    @([PSCustomObject]@{ Path = $mountPath })
                }

                Dismount-MCDBootImage -MountPath $mountPath
            }

            Should -Invoke Dismount-WindowsImage -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $Discard -eq $true
            }
        }

        It 'Logs warning when no image is mounted' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $mountPath = Join-Path -Path $TestDrive -ChildPath 'dismount3'
                $null = New-Item -Path $mountPath -ItemType Directory -Force

                Mock Get-WindowsImage -MockWith { @() }

                Dismount-MCDBootImage -MountPath $mountPath
            }

            Should -Invoke Write-MCDLog -ModuleName $script:moduleName -ParameterFilter {
                $Level -eq 'Warning' -and $Message -like '*No image is mounted*'
            }
        }
    }
}

Describe 'Add-MCDWinPEComponents' {
    Context 'Parameter Validation' {
        It 'Has mandatory MountPath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Add-MCDWinPEComponents'
                $param = $cmd.Parameters['MountPath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory Packages parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Add-MCDWinPEComponents'
                $param = $cmd.Parameters['Packages']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory WinPEOCsPath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Add-MCDWinPEComponents'
                $param = $cmd.Parameters['WinPEOCsPath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Add-MCDWinPEComponents'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
            }
        }
    }

    Context 'Package installation' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Add-WindowsPackage -ModuleName $script:moduleName
        }

        It 'Adds base package and language pack' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                # Create test directories
                $mountPath = Join-Path -Path $TestDrive -ChildPath 'mount'
                $ocsPath = Join-Path -Path $TestDrive -ChildPath 'WinPE_OCs'
                $langPath = Join-Path -Path $ocsPath -ChildPath 'en-us'
                $null = New-Item -Path $mountPath -ItemType Directory -Force
                $null = New-Item -Path $langPath -ItemType Directory -Force

                # Create fake cab files
                Set-Content -Path (Join-Path -Path $ocsPath -ChildPath 'WinPE-WMI.cab') -Value 'cab'
                Set-Content -Path (Join-Path -Path $langPath -ChildPath 'WinPE-WMI_en-us.cab') -Value 'cab'

                Add-MCDWinPEComponents -MountPath $mountPath -Packages @('WinPE-WMI') -WinPEOCsPath $ocsPath
            }

            Should -Invoke Add-WindowsPackage -ModuleName $script:moduleName -Times 2
        }

        It 'Logs package installation' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $mountPath = Join-Path -Path $TestDrive -ChildPath 'mount2'
                $ocsPath = Join-Path -Path $TestDrive -ChildPath 'WinPE_OCs2'
                $null = New-Item -Path $mountPath -ItemType Directory -Force
                $null = New-Item -Path $ocsPath -ItemType Directory -Force

                Set-Content -Path (Join-Path -Path $ocsPath -ChildPath 'WinPE-Test.cab') -Value 'cab'

                Add-MCDWinPEComponents -MountPath $mountPath -Packages @('WinPE-Test') -WinPEOCsPath $ocsPath
            }

            Should -Invoke Write-MCDLog -ModuleName $script:moduleName -ParameterFilter {
                $Message -like '*Adding package*'
            }
        }

        It 'Continues when package not found but logs warning' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $mountPath = Join-Path -Path $TestDrive -ChildPath 'mount3'
                $ocsPath = Join-Path -Path $TestDrive -ChildPath 'WinPE_OCs3'
                $null = New-Item -Path $mountPath -ItemType Directory -Force
                $null = New-Item -Path $ocsPath -ItemType Directory -Force

                # Create one valid package so we have partial success (not all fail)
                Set-Content -Path (Join-Path -Path $ocsPath -ChildPath 'WinPE-Valid.cab') -Value 'cab'
                # Don't create the WinPE-Missing cab file - that package not found

                Add-MCDWinPEComponents -MountPath $mountPath -Packages @('WinPE-Valid', 'WinPE-Missing') -WinPEOCsPath $ocsPath
            }

            Should -Invoke Write-MCDLog -ModuleName $script:moduleName -ParameterFilter {
                $Level -eq 'Warning' -and $Message -like '*Package not found*'
            }
        }
    }
}

Describe 'New-MCDBootImageISO' {
    Context 'Parameter Validation' {
        It 'Has mandatory MediaPath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDBootImageISO'
                $param = $cmd.Parameters['MediaPath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory OutputPath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDBootImageISO'
                $param = $cmd.Parameters['OutputPath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory Label parameter with length validation' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDBootImageISO'
                $param = $cmd.Parameters['Label']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
                $lengthAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateLengthAttribute] }
                $lengthAttr | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has mandatory Architecture parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDBootImageISO'
                $param = $cmd.Parameters['Architecture']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory ADKPaths parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDBootImageISO'
                $param = $cmd.Parameters['ADKPaths']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDBootImageISO'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
            }
        }
    }

    Context 'ISO creation for amd64' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Copy-Item -ModuleName $script:moduleName
            Mock New-Item -ModuleName $script:moduleName -MockWith {
                param($Path, $ItemType)
                if ($ItemType -eq 'Directory')
                {
                    return @{ FullName = $Path }
                }
            }
        }

        It 'Uses dual boot data for amd64' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                # Create test media structure
                $mediaPath = Join-Path -Path $TestDrive -ChildPath 'media'
                $bootPath = Join-Path -Path $mediaPath -ChildPath 'boot'
                $efiPath = Join-Path -Path $mediaPath -ChildPath 'efi\microsoft\boot'
                $null = New-Item -Path $bootPath -ItemType Directory -Force
                $null = New-Item -Path $efiPath -ItemType Directory -Force

                $outputPath = Join-Path -Path $TestDrive -ChildPath 'output.iso'

                $adkPaths = @{
                    OscdimgExe         = 'C:\ADK\oscdimg.exe'
                    EtfsbootPath       = 'C:\ADK\etfsboot.com'
                    EfisysPath         = 'C:\ADK\efisys.bin'
                    EfisysNopromptPath = 'C:\ADK\efisys_noprompt.bin'
                }

                # Mock Test-Path to return true for all ADK paths and output path check
                Mock Test-Path -MockWith { $true }

                # Mock Start-Process to simulate successful ISO creation
                Mock Start-Process -MockWith {
                    return @{ ExitCode = 0 }
                }

                # Mock Get-Item for the output file return
                Mock Get-Item -MockWith {
                    param($Path)
                    return [PSCustomObject]@{ FullName = $Path; Name = 'output.iso' }
                }

                $null = New-MCDBootImageISO -MediaPath $mediaPath -OutputPath $outputPath -Label 'TEST' -Architecture 'amd64' -ADKPaths $adkPaths
            }

            Should -Invoke Start-Process -ModuleName $script:moduleName -ParameterFilter {
                $ArgumentList -like '*bootdata:2*'
            }
        }
    }

    Context 'ISO creation for arm64' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Copy-Item -ModuleName $script:moduleName
            Mock New-Item -ModuleName $script:moduleName -MockWith {
                param($Path, $ItemType)
                if ($ItemType -eq 'Directory')
                {
                    return @{ FullName = $Path }
                }
            }
        }

        It 'Uses UEFI-only boot data for arm64' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $mediaPath = Join-Path -Path $TestDrive -ChildPath 'media2'
                $bootPath = Join-Path -Path $mediaPath -ChildPath 'boot'
                $null = New-Item -Path $bootPath -ItemType Directory -Force

                $outputPath = Join-Path -Path $TestDrive -ChildPath 'arm64.iso'

                $adkPaths = @{
                    OscdimgExe         = 'C:\ADK\oscdimg.exe'
                    EtfsbootPath       = 'C:\ADK\etfsboot.com'
                    EfisysPath         = 'C:\ADK\efisys.bin'
                    EfisysNopromptPath = 'C:\ADK\efisys_noprompt.bin'
                }

                # Mock Test-Path to return true for all paths
                Mock Test-Path -MockWith { $true }

                # Mock Start-Process to simulate successful ISO creation
                Mock Start-Process -MockWith {
                    return @{ ExitCode = 0 }
                }

                # Mock Get-Item for the output file return
                Mock Get-Item -MockWith {
                    param($Path)
                    return [PSCustomObject]@{ FullName = $Path; Name = 'arm64.iso' }
                }

                $null = New-MCDBootImageISO -MediaPath $mediaPath -OutputPath $outputPath -Label 'ARM64' -Architecture 'arm64' -ADKPaths $adkPaths
            }

            Should -Invoke Start-Process -ModuleName $script:moduleName -ParameterFilter {
                $ArgumentList -like '*bootdata:1*pEF*'
            }
        }
    }
}

Describe 'New-MCDWinPEBootImage' {
    Context 'Parameter Validation' {
        It 'Has mandatory WorkspacePath parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDWinPEBootImage'
                $param = $cmd.Parameters['WorkspacePath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has optional Architecture parameter with default amd64' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDWinPEBootImage'
                $param = $cmd.Parameters['Architecture']

                $param | Should -Not -BeNullOrEmpty
                $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                $validateSet.ValidValues | Should -Contain 'amd64'
                $validateSet.ValidValues | Should -Contain 'arm64'
            }
        }

        It 'Has optional IsoLabel parameter with length validation' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDWinPEBootImage'
                $param = $cmd.Parameters['IsoLabel']

                $param | Should -Not -BeNullOrEmpty
                $lengthAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateLengthAttribute] }
                $lengthAttr | Should -Not -BeNullOrEmpty
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDWinPEBootImage'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
            }
        }
    }

    Context 'ADK validation' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Throws when ADK is not installed' {
            InModuleScope $script:moduleName {
                Mock Get-MCDADKInstaller -MockWith {
                    $model = [ADKInstallerModel]::new()
                    $model.IsInstalled = $false
                    return $model
                }

                { New-MCDWinPEBootImage -WorkspacePath 'C:\Test' } | Should -Throw '*ADK is not installed*'
            }
        }

        It 'Throws when WinPE add-on is not installed' {
            InModuleScope $script:moduleName {
                Mock Get-MCDADKInstaller -MockWith {
                    $model = [ADKInstallerModel]::new()
                    $model.IsInstalled = $true
                    $model.InstallPath = 'C:\ADK'
                    $model.HasWinPEAddOn = $false
                    return $model
                }

                { New-MCDWinPEBootImage -WorkspacePath 'C:\Test' } | Should -Throw '*PE add-on is not installed*'
            }
        }
    }

    Context 'WhatIf behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            InModuleScope $script:moduleName {
                Mock Get-MCDADKInstaller -MockWith {
                    $model = [ADKInstallerModel]::new()
                    $model.IsInstalled = $true
                    $model.InstallPath = 'C:\ADK'
                    $model.HasWinPEAddOn = $true
                    $model.WinPEAddOnPath = 'C:\ADK\WinPE'
                    return $model
                }
                Mock Get-MCDADKPaths -MockWith {
                    @{
                        DeploymentToolsPath = 'C:\ADK\Deployment Tools\amd64'
                        OscdimgPath         = 'C:\ADK\Oscdimg'
                        OscdimgExe          = 'C:\ADK\oscdimg.exe'
                        EtfsbootPath        = 'C:\ADK\etfsboot.com'
                        EfisysPath          = 'C:\ADK\efisys.bin'
                        EfisysNopromptPath  = 'C:\ADK\efisys_noprompt.bin'
                        WinPEPath           = 'C:\ADK\WinPE\amd64'
                        WinPEMediaPath      = 'C:\ADK\WinPE\amd64\Media'
                        WinPEWimPath        = 'C:\ADK\WinPE\amd64\en-us\winpe.wim'
                        WinPEOCsPath        = 'C:\ADK\WinPE\amd64\WinPE_OCs'
                        Architecture        = 'amd64'
                    }
                }
                Mock Test-Path -MockWith { $false }
                Mock Remove-Item
                Mock New-Item
                Mock Copy-Item
                Mock Mount-MCDBootImage
                Mock Dismount-MCDBootImage
                Mock New-MCDBootImageISO
            }
        }

        It 'Does not create files when WhatIf specified' {
            InModuleScope $script:moduleName -Parameters @{ TestDrive = $TestDrive } {
                $null = New-MCDWinPEBootImage -WorkspacePath $TestDrive -WhatIf
            }

            Should -Invoke Mount-MCDBootImage -ModuleName $script:moduleName -Times 0
            Should -Invoke New-MCDBootImageISO -ModuleName $script:moduleName -Times 0
        }
    }
}
