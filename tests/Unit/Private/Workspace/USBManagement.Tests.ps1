BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Get-MCDUSBDrive' {
    Context 'Parameter Validation' {
        It 'Has optional MinimumSizeGB parameter with default 8' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDUSBDrive'
                $param = $cmd.Parameters['MinimumSizeGB']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Returns pscustomobject array type' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDUSBDrive'
                $outputType = $cmd.OutputType.Name

                # PowerShell resolves PSCustomObject[] to PSObject[] internally
                ($outputType -contains 'PSCustomObject[]' -or $outputType -contains 'System.Management.Automation.PSObject[]') | Should -BeTrue
            }
        }
    }

    Context 'When no USB drives found' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-Disk -ModuleName $script:moduleName -MockWith { return @() }
        }

        It 'Returns empty array' {
            InModuleScope $script:moduleName {
                $result = Get-MCDUSBDrive

                $result | Should -BeNullOrEmpty
            }
        }

        It 'Logs warning about no drives found' {
            InModuleScope $script:moduleName {
                $null = Get-MCDUSBDrive
            }

            Should -Invoke Write-MCDLog -ModuleName $script:moduleName -ParameterFilter {
                $Level -eq 'Warning' -and $Message -like '*No removable USB drives*'
            }
        }
    }

    Context 'When USB drives exist' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return @(
                    [PSCustomObject]@{
                        Number            = 2
                        FriendlyName      = 'USB Flash Drive'
                        Model             = 'SanDisk Ultra'
                        Size              = 32GB
                        BusType           = 'USB'
                        PartitionStyle    = 'MBR'
                        OperationalStatus = 'Online'
                        IsOffline         = $false
                        IsReadOnly        = $false
                    },
                    [PSCustomObject]@{
                        Number            = 3
                        FriendlyName      = 'USB HDD'
                        Model             = 'Seagate Portable'
                        Size              = 500GB
                        BusType           = 'USB'
                        PartitionStyle    = 'GPT'
                        OperationalStatus = 'Online'
                        IsOffline         = $false
                        IsReadOnly        = $false
                    }
                )
            }
        }

        It 'Returns USB drives with correct properties' {
            InModuleScope $script:moduleName {
                $result = Get-MCDUSBDrive

                $result.Count | Should -Be 2
                $result[0].DiskNumber | Should -Be 2
                $result[0].Model | Should -Be 'SanDisk Ultra'
                $result[0].BusType | Should -Be 'USB'
            }
        }

        It 'Calculates size in GB correctly' {
            InModuleScope $script:moduleName {
                $result = Get-MCDUSBDrive

                $result[0].SizeGB | Should -Be 32
            }
        }

        It 'Logs count of drives found' {
            InModuleScope $script:moduleName {
                $null = Get-MCDUSBDrive
            }

            Should -Invoke Write-MCDLog -ModuleName $script:moduleName -ParameterFilter {
                $Level -eq 'Info' -and $Message -like '*Found 2 removable USB drive*'
            }
        }
    }

    Context 'MinimumSizeGB filtering' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return @(
                    [PSCustomObject]@{
                        Number   = 2
                        Model    = 'Small USB'
                        Size     = 4GB
                        BusType  = 'USB'
                    },
                    [PSCustomObject]@{
                        Number   = 3
                        Model    = 'Large USB'
                        Size     = 64GB
                        BusType  = 'USB'
                    }
                )
            }
        }

        It 'Filters out drives smaller than MinimumSizeGB' {
            InModuleScope $script:moduleName {
                $result = Get-MCDUSBDrive -MinimumSizeGB 8

                $result.Count | Should -Be 1
                $result[0].Model | Should -Be 'Large USB'
            }
        }

        It 'Includes drives when MinimumSizeGB is lower' {
            InModuleScope $script:moduleName {
                $result = Get-MCDUSBDrive -MinimumSizeGB 2

                $result.Count | Should -Be 2
            }
        }
    }

    Context 'Non-USB drives filtering' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return @(
                    [PSCustomObject]@{
                        Number   = 0
                        Model    = 'NVMe SSD'
                        Size     = 512GB
                        BusType  = 'NVMe'
                    },
                    [PSCustomObject]@{
                        Number   = 1
                        Model    = 'SATA HDD'
                        Size     = 1TB
                        BusType  = 'SATA'
                    },
                    [PSCustomObject]@{
                        Number   = 2
                        Model    = 'USB Drive'
                        Size     = 32GB
                        BusType  = 'USB'
                    }
                )
            }
        }

        It 'Only returns USB bus type drives' {
            InModuleScope $script:moduleName {
                $result = Get-MCDUSBDrive

                $result.Count | Should -Be 1
                $result[0].BusType | Should -Be 'USB'
            }
        }
    }
}

Describe 'Remove-MCDUSBLetters' {
    Context 'Parameter Validation' {
        It 'Has mandatory DiskNumber parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Remove-MCDUSBLetters'
                $param = $cmd.Parameters['DiskNumber']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Remove-MCDUSBLetters'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
            }
        }
    }

    Context 'When no partitions exist' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-Partition -ModuleName $script:moduleName -MockWith { return $null }
        }

        It 'Returns empty array' {
            InModuleScope $script:moduleName {
                $result = Remove-MCDUSBLetters -DiskNumber 2

                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'When partitions have access paths' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-Partition -ModuleName $script:moduleName -MockWith {
                return @(
                    [PSCustomObject]@{
                        PartitionNumber = 1
                        AccessPaths     = @('E:\', '\\?\Volume{guid}')
                    },
                    [PSCustomObject]@{
                        PartitionNumber = 2
                        AccessPaths     = @('F:\', '\\?\Volume{guid2}')
                    }
                )
            }
            Mock Remove-PartitionAccessPath -ModuleName $script:moduleName
        }

        It 'Removes drive letter access paths' {
            InModuleScope $script:moduleName {
                $result = Remove-MCDUSBLetters -DiskNumber 2

                $result.Count | Should -Be 2
            }

            Should -Invoke Remove-PartitionAccessPath -ModuleName $script:moduleName -Times 2
        }

        It 'Returns removed path info with correct properties' {
            InModuleScope $script:moduleName {
                $result = Remove-MCDUSBLetters -DiskNumber 2

                $result[0].DiskNumber | Should -Be 2
                $result[0].PartitionNumber | Should -Be 1
                $result[0].AccessPath | Should -Be 'E:\'
                $result[0].DriveLetter | Should -Be 'E'
            }
        }

        It 'Does not remove non-letter access paths (volume GUIDs)' {
            InModuleScope $script:moduleName {
                $null = Remove-MCDUSBLetters -DiskNumber 2
            }

            Should -Invoke Remove-PartitionAccessPath -ModuleName $script:moduleName -Times 2 -ParameterFilter {
                $AccessPath -match '^[A-Z]:\\$'
            }
        }
    }

    Context 'WhatIf behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-Partition -ModuleName $script:moduleName -MockWith {
                return @(
                    [PSCustomObject]@{
                        PartitionNumber = 1
                        AccessPaths     = @('E:\')
                    }
                )
            }
            Mock Remove-PartitionAccessPath -ModuleName $script:moduleName
        }

        It 'Does not remove paths when WhatIf specified' {
            InModuleScope $script:moduleName {
                $null = Remove-MCDUSBLetters -DiskNumber 2 -WhatIf
            }

            Should -Invoke Remove-PartitionAccessPath -ModuleName $script:moduleName -Times 0
        }
    }
}

Describe 'Restore-MCDUSBLetters' {
    Context 'Parameter Validation' {
        It 'Has mandatory RemovedPaths parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Restore-MCDUSBLetters'
                $param = $cmd.Parameters['RemovedPaths']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Restore-MCDUSBLetters'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
            }
        }
    }

    Context 'When RemovedPaths is empty' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Returns without error' {
            InModuleScope $script:moduleName {
                { Restore-MCDUSBLetters -RemovedPaths @() } | Should -Not -Throw
            }
        }
    }

    Context 'When paths need restoration' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-PSDrive -ModuleName $script:moduleName -MockWith {
                return @(
                    [PSCustomObject]@{ Name = 'C' },
                    [PSCustomObject]@{ Name = 'D' }
                )
            }
            Mock Get-Partition -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{ PartitionNumber = 1 }
            }
            Mock Add-PartitionAccessPath -ModuleName $script:moduleName
        }

        It 'Restores available drive letters' {
            InModuleScope $script:moduleName {
                $removedPaths = @(
                    [PSCustomObject]@{
                        DiskNumber      = 2
                        PartitionNumber = 1
                        AccessPath      = 'E:\'
                        DriveLetter     = 'E'
                        RemovedAt       = (Get-Date)
                    }
                )

                Restore-MCDUSBLetters -RemovedPaths $removedPaths
            }

            Should -Invoke Add-PartitionAccessPath -ModuleName $script:moduleName -Times 1
        }

        It 'Skips letters that are no longer available' {
            InModuleScope $script:moduleName {
                $removedPaths = @(
                    [PSCustomObject]@{
                        DiskNumber      = 2
                        PartitionNumber = 1
                        AccessPath      = 'C:\'
                        DriveLetter     = 'C'
                        RemovedAt       = (Get-Date)
                    }
                )

                Restore-MCDUSBLetters -RemovedPaths $removedPaths
            }

            Should -Invoke Add-PartitionAccessPath -ModuleName $script:moduleName -Times 0
            Should -Invoke Write-MCDLog -ModuleName $script:moduleName -ParameterFilter {
                $Level -eq 'Warning' -and $Message -like '*no longer available*'
            }
        }
    }

    Context 'WhatIf behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-PSDrive -ModuleName $script:moduleName -MockWith { return @() }
            Mock Get-Partition -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{ PartitionNumber = 1 }
            }
            Mock Add-PartitionAccessPath -ModuleName $script:moduleName
        }

        It 'Does not add paths when WhatIf specified' {
            InModuleScope $script:moduleName {
                $removedPaths = @(
                    [PSCustomObject]@{
                        DiskNumber      = 2
                        PartitionNumber = 1
                        AccessPath      = 'E:\'
                        DriveLetter     = 'E'
                        RemovedAt       = (Get-Date)
                    }
                )

                Restore-MCDUSBLetters -RemovedPaths $removedPaths -WhatIf
            }

            Should -Invoke Add-PartitionAccessPath -ModuleName $script:moduleName -Times 0
        }
    }
}

Describe 'Format-MCDUSB' {
    Context 'Parameter Validation' {
        It 'Has mandatory DiskNumber parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Format-MCDUSB'
                $param = $cmd.Parameters['DiskNumber']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has optional BootPartitionSizeGB with default 2' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Format-MCDUSB'
                $param = $cmd.Parameters['BootPartitionSizeGB']

                $param | Should -Not -BeNullOrEmpty
            }
        }

        It 'Supports ShouldProcess with High ConfirmImpact' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Format-MCDUSB'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
                $attr.ConfirmImpact | Should -Be 'High'
            }
        }
    }

    Context 'Safety validation' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Test-MCDPrerequisite -ModuleName $script:moduleName -MockWith { $true }
            # Mock destructive cmdlets to prevent real calls if validation logic regresses
            Mock Clear-Disk -ModuleName $script:moduleName
            Mock Initialize-Disk -ModuleName $script:moduleName
        }

        It 'Calls Test-MCDPrerequisite for safety validation' {
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    Number   = 2
                    BusType  = 'USB'
                    Model    = 'Test USB'
                    Size     = 32GB
                    IsSystem = $false
                    IsBoot   = $false
                }
            }
            Mock Clear-Disk -ModuleName $script:moduleName
            Mock Initialize-Disk -ModuleName $script:moduleName
            Mock Get-MCDAvailableDriveLetter -ModuleName $script:moduleName -MockWith { 'B' }
            Mock New-Partition -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{ PartitionNumber = 1; Size = 2GB }
            }
            Mock Format-Volume -ModuleName $script:moduleName
            Mock Get-Volume -ModuleName $script:moduleName

            InModuleScope $script:moduleName {
                $null = Format-MCDUSB -DiskNumber 2 -Confirm:$false
            }

            Should -Invoke Test-MCDPrerequisite -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $RequireFullOS.IsPresent -and $RequireAdministrator.IsPresent
            }
        }

        It 'Throws when disk is not USB bus type' {
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    Number   = 0
                    BusType  = 'SATA'
                    Model    = 'Internal HDD'
                    Size     = 1TB
                    IsSystem = $false
                    IsBoot   = $false
                }
            }

            InModuleScope $script:moduleName {
                { Format-MCDUSB -DiskNumber 0 -Confirm:$false } | Should -Throw '*not a USB drive*'
            }
        }

        It 'Throws when disk is a system disk' {
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    Number   = 2
                    BusType  = 'USB'
                    Model    = 'System USB'
                    Size     = 32GB
                    IsSystem = $true
                    IsBoot   = $false
                }
            }

            InModuleScope $script:moduleName {
                { Format-MCDUSB -DiskNumber 2 -Confirm:$false } | Should -Throw '*system disk*'
            }
        }

        It 'Throws when disk is a boot disk' {
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    Number   = 2
                    BusType  = 'USB'
                    Model    = 'Boot USB'
                    Size     = 32GB
                    IsSystem = $false
                    IsBoot   = $true
                }
            }

            InModuleScope $script:moduleName {
                { Format-MCDUSB -DiskNumber 2 -Confirm:$false } | Should -Throw '*boot disk*'
            }
        }

        It 'Throws when disk is too small' {
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    Number   = 2
                    BusType  = 'USB'
                    Model    = 'Small USB'
                    Size     = 2GB
                    IsSystem = $false
                    IsBoot   = $false
                }
            }

            InModuleScope $script:moduleName {
                { Format-MCDUSB -DiskNumber 2 -Confirm:$false } | Should -Throw '*too small*'
            }
        }
    }

    Context 'Format operation' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Test-MCDPrerequisite -ModuleName $script:moduleName -MockWith { $true }
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    Number   = 2
                    BusType  = 'USB'
                    Model    = 'Test USB Drive'
                    Size     = 32GB
                    IsSystem = $false
                    IsBoot   = $false
                }
            }
            Mock Clear-Disk -ModuleName $script:moduleName
            Mock Initialize-Disk -ModuleName $script:moduleName
            Mock Get-MCDAvailableDriveLetter -ModuleName $script:moduleName -MockWith {
                param($PreferredLetters, $ExcludeLetters)
                if ($ExcludeLetters) { return 'D' }
                return 'B'
            }
            Mock New-Partition -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    PartitionNumber = if ($Size) { 1 } else { 2 }
                    Size            = if ($Size) { $Size } else { 30GB }
                }
            }
            Mock Format-Volume -ModuleName $script:moduleName
            Mock Get-Volume -ModuleName $script:moduleName
        }

        It 'Clears disk before partitioning' {
            InModuleScope $script:moduleName {
                $null = Format-MCDUSB -DiskNumber 2 -Confirm:$false
            }

            Should -Invoke Clear-Disk -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $Number -eq 2 -and $RemoveData -eq $true
            }
        }

        It 'Initializes disk with MBR partition style' {
            InModuleScope $script:moduleName {
                $null = Format-MCDUSB -DiskNumber 2 -Confirm:$false
            }

            Should -Invoke Initialize-Disk -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $Number -eq 2 -and $PartitionStyle -eq 'MBR'
            }
        }

        It 'Creates Boot partition with FAT32' {
            InModuleScope $script:moduleName {
                $null = Format-MCDUSB -DiskNumber 2 -Confirm:$false
            }

            Should -Invoke New-Partition -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $Size -eq 2GB -and $IsActive -eq $true
            }
            Should -Invoke Format-Volume -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $FileSystem -eq 'FAT32'
            }
        }

        It 'Creates Deploy partition with NTFS using remaining space' {
            InModuleScope $script:moduleName {
                $null = Format-MCDUSB -DiskNumber 2 -Confirm:$false
            }

            Should -Invoke New-Partition -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $UseMaximumSize -eq $true
            }
            Should -Invoke Format-Volume -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $FileSystem -eq 'NTFS'
            }
        }

        It 'Returns result with partition info' {
            InModuleScope $script:moduleName {
                $result = Format-MCDUSB -DiskNumber 2 -Confirm:$false

                $result.DiskNumber | Should -Be 2
                $result.PartitionStyle | Should -Be 'MBR'
                $result.BootDriveLetter | Should -Be 'B'
                $result.BootFileSystem | Should -Be 'FAT32'
                $result.DeployDriveLetter | Should -Be 'D'
                $result.DeployFileSystem | Should -Be 'NTFS'
            }
        }
    }

    Context 'WhatIf behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Test-MCDPrerequisite -ModuleName $script:moduleName -MockWith { $true }
            Mock Get-Disk -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    Number   = 2
                    BusType  = 'USB'
                    Model    = 'Test USB'
                    Size     = 32GB
                    IsSystem = $false
                    IsBoot   = $false
                }
            }
            Mock Clear-Disk -ModuleName $script:moduleName
            Mock Initialize-Disk -ModuleName $script:moduleName
        }

        It 'Does not format when WhatIf specified' {
            InModuleScope $script:moduleName {
                $null = Format-MCDUSB -DiskNumber 2 -WhatIf
            }

            Should -Invoke Clear-Disk -ModuleName $script:moduleName -Times 0
            Should -Invoke Initialize-Disk -ModuleName $script:moduleName -Times 0
        }
    }
}

Describe 'Copy-MCDBootImageToUSB' {
    Context 'Parameter Validation' {
        It 'Has mandatory MediaPath parameter with SourcePath alias' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Copy-MCDBootImageToUSB'
                $param = $cmd.Parameters['MediaPath']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
                $param.Aliases | Should -Contain 'SourcePath'
            }
        }

        It 'Has mandatory BootDriveLetter parameter with DestinationDriveLetter alias' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Copy-MCDBootImageToUSB'
                $param = $cmd.Parameters['BootDriveLetter']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Contain $true
                $param.Aliases | Should -Contain 'DestinationDriveLetter'
            }
        }

        It 'Validates BootDriveLetter is single letter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Copy-MCDBootImageToUSB'
                $validatePattern = $cmd.Parameters['BootDriveLetter'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }

                $validatePattern | Should -Not -BeNullOrEmpty
            }
        }

        It 'Supports ShouldProcess with High ConfirmImpact' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Copy-MCDBootImageToUSB'
                $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                $attr.SupportsShouldProcess | Should -BeTrue
                $attr.ConfirmImpact | Should -Be 'High'
            }
        }
    }

    Context 'Source validation' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Throws when media path does not exist' {
            InModuleScope $script:moduleName {
                { Copy-MCDBootImageToUSB -MediaPath 'Z:\NonExistent' -BootDriveLetter 'B' -Confirm:$false } | Should -Throw '*does not exist*'
            }
        }
    }

    Context 'Copy operation with Robocopy' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Test-Path -ModuleName $script:moduleName -MockWith { return $true }
            Mock Join-Path -ModuleName $script:moduleName -MockWith {
                param($Path, $ChildPath)
                return "$Path$ChildPath"
            }
            Mock Start-Process -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{ ExitCode = 1 }
            }
            Mock Get-ChildItem -ModuleName $script:moduleName -MockWith {
                return @([PSCustomObject]@{ Name = 'bootmgr'; Length = 1024 })
            }
        }

        It 'Uses Robocopy by default' {
            InModuleScope $script:moduleName {
                $null = Copy-MCDBootImageToUSB -MediaPath 'E:\' -BootDriveLetter 'B' -Confirm:$false
            }

            Should -Invoke Start-Process -ModuleName $script:moduleName -Times 1 -ParameterFilter { $FilePath -eq 'robocopy.exe' }
        }

        It 'Returns result with copy statistics' {
            InModuleScope $script:moduleName {
                $result = Copy-MCDBootImageToUSB -MediaPath 'E:\' -BootDriveLetter 'B' -Confirm:$false

                $result.MediaPath | Should -Be 'E:\'
                $result.DestinationPath | Should -Be 'B:\'
                $result.UsedRobocopy | Should -BeTrue
            }
        }

        It 'Throws when Robocopy fails with exit code >= 8' {
            Mock Start-Process -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{ ExitCode = 8 }
            }

            InModuleScope $script:moduleName {
                { Copy-MCDBootImageToUSB -MediaPath 'E:\' -BootDriveLetter 'B' -Confirm:$false } | Should -Throw '*Robocopy failed*'
            }
        }
    }

    Context 'Copy operation with Copy-Item' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Test-Path -ModuleName $script:moduleName -MockWith { return $true }
            Mock Join-Path -ModuleName $script:moduleName -MockWith {
                param($Path, $ChildPath)
                return "$Path$ChildPath"
            }
            Mock Get-ChildItem -ModuleName $script:moduleName -MockWith {
                return @([PSCustomObject]@{
                    Name          = 'bootmgr'
                    FullName      = 'E:\bootmgr'
                    Length        = 1024
                    PSIsContainer = $false
                })
            }
            Mock Copy-Item -ModuleName $script:moduleName
        }

        It 'Uses Copy-Item when UseRobocopy is false' {
            InModuleScope $script:moduleName {
                $null = Copy-MCDBootImageToUSB -MediaPath 'E:\' -BootDriveLetter 'B' -UseRobocopy:$false -Confirm:$false
            }

            Should -Invoke Copy-Item -ModuleName $script:moduleName -Times 1
        }

        It 'Returns result indicating Copy-Item was used' {
            InModuleScope $script:moduleName {
                $result = Copy-MCDBootImageToUSB -MediaPath 'E:\' -BootDriveLetter 'B' -UseRobocopy:$false -Confirm:$false

                $result.UsedRobocopy | Should -BeFalse
            }
        }
    }

    Context 'WhatIf behavior' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Test-Path -ModuleName $script:moduleName -MockWith { return $true }
            Mock Start-Process -ModuleName $script:moduleName
            Mock Copy-Item -ModuleName $script:moduleName
        }

        It 'Does not copy when WhatIf specified' {
            InModuleScope $script:moduleName {
                $null = Copy-MCDBootImageToUSB -MediaPath 'E:\' -BootDriveLetter 'B' -WhatIf
            }

            Should -Invoke Start-Process -ModuleName $script:moduleName -Times 0
            Should -Invoke Copy-Item -ModuleName $script:moduleName -Times 0
        }
    }

    Context 'Missing boot structure warning' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Test-Path -ModuleName $script:moduleName -MockWith {
                param($Path)
                # Source and destination exist, but boot/efi/sources don't
                if ($Path -eq 'E:\' -or $Path -eq 'B:\') { return $true }
                return $false
            }
            Mock Join-Path -ModuleName $script:moduleName -MockWith {
                param($Path, $ChildPath)
                return "$Path$ChildPath"
            }
            Mock Start-Process -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{ ExitCode = 0 }
            }
            Mock Get-ChildItem -ModuleName $script:moduleName -MockWith {
                return @()
            }
        }

        It 'Logs warning when expected boot structure is missing (boot, efi, sources)' {
            InModuleScope $script:moduleName {
                $null = Copy-MCDBootImageToUSB -MediaPath 'E:\' -BootDriveLetter 'B' -Confirm:$false
            }

            Should -Invoke Write-MCDLog -ModuleName $script:moduleName -ParameterFilter {
                $Level -eq 'Warning' -and $Message -like '*missing expected boot structure*'
            }
        }
    }
}

Describe 'USB Management Integration Pattern' {
    Context 'Full workflow pattern' {
        It 'Functions exist and can be called in correct order' {
            InModuleScope $script:moduleName {
                $getCmdExists = $null -ne (Get-Command -Name 'Get-MCDUSBDrive' -ErrorAction SilentlyContinue)
                $removeCmdExists = $null -ne (Get-Command -Name 'Remove-MCDUSBLetters' -ErrorAction SilentlyContinue)
                $formatCmdExists = $null -ne (Get-Command -Name 'Format-MCDUSB' -ErrorAction SilentlyContinue)
                $copyCmdExists = $null -ne (Get-Command -Name 'Copy-MCDBootImageToUSB' -ErrorAction SilentlyContinue)
                $restoreCmdExists = $null -ne (Get-Command -Name 'Restore-MCDUSBLetters' -ErrorAction SilentlyContinue)

                $getCmdExists | Should -BeTrue
                $removeCmdExists | Should -BeTrue
                $formatCmdExists | Should -BeTrue
                $copyCmdExists | Should -BeTrue
                $restoreCmdExists | Should -BeTrue
            }
        }

        It 'All functions use Write-MCDLog for consistency' {
            InModuleScope $script:moduleName {
                $functions = @(
                    'Get-MCDUSBDrive',
                    'Remove-MCDUSBLetters',
                    'Restore-MCDUSBLetters',
                    'Format-MCDUSB',
                    'Copy-MCDBootImageToUSB'
                )

                foreach ($funcName in $functions)
                {
                    $func = Get-Command -Name $funcName
                    $definition = $func.Definition

                    $definition | Should -Match 'Write-MCDLog' -Because "$funcName should use Write-MCDLog"
                }
            }
        }

        It 'Destructive functions support ShouldProcess' {
            InModuleScope $script:moduleName {
                $destructiveFunctions = @(
                    'Remove-MCDUSBLetters',
                    'Restore-MCDUSBLetters',
                    'Format-MCDUSB',
                    'Copy-MCDBootImageToUSB'
                )

                foreach ($funcName in $destructiveFunctions)
                {
                    $cmd = Get-Command -Name $funcName
                    $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

                    $attr.SupportsShouldProcess | Should -BeTrue -Because "$funcName should support ShouldProcess"
                }
            }
        }
    }
}
