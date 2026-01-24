<#
    .SYNOPSIS
    MCD Media Builder class for creating USB and ISO deployment media.

    .DESCRIPTION
    The MCDMediaBuilder class provides methods for creating bootable USB drives
    and ISO images from an MCD workspace. It handles the dual-partition USB layout
    and WinPE media preparation.
#>
class MCDMediaBuilder
{
    # Associated workspace containing the media source
    [MCDWorkspace] $Workspace

    # Output path for generated media (ISO files, etc.)
    [string] $OutputPath

    # Default constructor
    MCDMediaBuilder()
    {
    }

    # Constructor with workspace
    MCDMediaBuilder([MCDWorkspace] $Workspace)
    {
        $this.Workspace = $Workspace
        if ($null -ne $Workspace)
        {
            $this.OutputPath = $Workspace.MediaPath
        }
    }

    # Constructor with workspace and custom output path
    MCDMediaBuilder([MCDWorkspace] $Workspace, [string] $OutputPath)
    {
        $this.Workspace = $Workspace
        $this.OutputPath = $OutputPath
    }

    <#
        .SYNOPSIS
        Validates the media builder configuration.

        .DESCRIPTION
        Checks that the workspace is set and valid before media operations.

        .OUTPUTS
        [bool] True if the configuration is valid.
    #>
    [bool] Validate()
    {
        if ($null -eq $this.Workspace)
        {
            return $false
        }

        if (-not $this.Workspace.Validate())
        {
            return $false
        }

        if ([string]::IsNullOrEmpty($this.OutputPath))
        {
            return $false
        }

        return $true
    }

    <#
        .SYNOPSIS
        Creates a bootable USB drive with dual-partition layout.

        .DESCRIPTION
        Formats the specified disk with a dual-partition layout:
        - Partition 1: FAT32 (~2GB) for WinPE boot files (Label: MCD)
        - Partition 2: NTFS (remaining) for cached content (Label: MCDData)

        WARNING: This operation is destructive and will erase all data on the disk.

        .PARAMETER DiskNumber
        The disk number to format (e.g., '1' for Disk 1).

        .NOTES
        This method performs validation only in MVP. Actual disk operations
        should be called through a public function with ShouldProcess support.
    #>
    [void] CreateUSB([string] $DiskNumber)
    {
        # Validate inputs
        if ([string]::IsNullOrEmpty($DiskNumber))
        {
            throw 'DiskNumber is required for USB creation.'
        }

        if (-not $this.Validate())
        {
            throw 'MediaBuilder validation failed. Ensure workspace is configured and valid.'
        }

        # Validate disk number format
        if ($DiskNumber -notmatch '^\d+$')
        {
            throw "Invalid DiskNumber format: '$DiskNumber'. Expected a numeric value."
        }

        # MVP: This is a scaffold. Actual implementation will:
        # 1. Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM
        # 2. Initialize-Disk -Number $DiskNumber -PartitionStyle GPT
        # 3. Create FAT32 partition (~2GB) for WinPE
        # 4. Create NTFS partition (remaining) for data
        # 5. Copy WinPE boot files to FAT32 partition
        # 6. Set up USB cache structure on NTFS partition

        # For now, just validate the configuration is ready
        Write-Verbose -Message "USB creation validated for disk $DiskNumber"
    }

    <#
        .SYNOPSIS
        Creates a bootable ISO image from the workspace.

        .DESCRIPTION
        Creates a bootable ISO image suitable for VM testing or DVD burning.
        Requires oscdimg.exe from the Windows ADK.

        .PARAMETER IsoOutputPath
        The full path for the output ISO file. If not specified, uses
        the workspace MediaPath with default filename.

        .NOTES
        This method performs validation and staging only in MVP. Actual ISO
        creation requires oscdimg.exe from the Windows ADK.
    #>
    [void] CreateISO([string] $IsoOutputPath)
    {
        # Validate inputs
        if ([string]::IsNullOrEmpty($IsoOutputPath))
        {
            throw 'IsoOutputPath is required for ISO creation.'
        }

        if (-not $this.Validate())
        {
            throw 'MediaBuilder validation failed. Ensure workspace is configured and valid.'
        }

        # Validate output path directory exists
        $parentDir = Split-Path -Path $IsoOutputPath -Parent
        if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path -Path $parentDir))
        {
            throw "Output directory does not exist: $parentDir"
        }

        # Validate file extension
        if (-not $IsoOutputPath.EndsWith('.iso', [System.StringComparison]::OrdinalIgnoreCase))
        {
            throw 'IsoOutputPath must have .iso extension.'
        }

        # MVP: This is a scaffold. Actual implementation will:
        # 1. Verify oscdimg.exe is available (from ADK)
        # 2. Create staging directory with WinPE files
        # 3. Run oscdimg with appropriate boot sector parameters
        # 4. Clean up staging directory

        # For now, just validate the configuration is ready
        Write-Verbose -Message "ISO creation validated for output: $IsoOutputPath"
    }

    <#
        .SYNOPSIS
        Gets the path to the WinPE boot files in the workspace.

        .OUTPUTS
        [string] The path to the WinPE boot files.
    #>
    [string] GetWinPESourcePath()
    {
        if ($null -eq $this.Workspace)
        {
            return $null
        }
        return Join-Path -Path $this.Workspace.TemplatePath -ChildPath 'WinPE'
    }

    <#
        .SYNOPSIS
        Gets information about a disk for USB creation.

        .DESCRIPTION
        Retrieves disk information to help users select the correct disk.

        .PARAMETER DiskNumber
        The disk number to query.

        .OUTPUTS
        [hashtable] Disk information including size, model, etc.
    #>
    [hashtable] GetDiskInfo([string] $DiskNumber)
    {
        if ([string]::IsNullOrEmpty($DiskNumber) -or $DiskNumber -notmatch '^\d+$')
        {
            return $null
        }

        try
        {
            $disk = Get-Disk -Number ([int]$DiskNumber) -ErrorAction Stop
            return @{
                Number      = $disk.Number
                FriendlyName = $disk.FriendlyName
                Size        = $disk.Size
                SizeGB      = [math]::Round($disk.Size / 1GB, 2)
                PartitionStyle = $disk.PartitionStyle
                BusType     = $disk.BusType
                IsRemovable = ($disk.BusType -eq 'USB')
            }
        }
        catch
        {
            return $null
        }
    }

    <#
        .SYNOPSIS
        Returns a string representation of the media builder.

        .OUTPUTS
        [string] A description of the media builder.
    #>
    [string] ToString()
    {
        $workspaceName = if ($null -ne $this.Workspace) { $this.Workspace.Name } else { '<none>' }
        return "MCDMediaBuilder: Workspace=$workspaceName, Output=$($this.OutputPath)"
    }
}
