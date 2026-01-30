<#
.SYNOPSIS
Creates a bootable Windows PE image from installed ADK components.

.DESCRIPTION
Orchestrates the WinPE boot image creation pipeline by copying ADK WinPE media
to a working directory, mounting the boot.wim, optionally adding WinPE packages,
dismounting, and building an ISO with oscdimg. Supports both amd64 and arm64
architectures. Uses installed ADK tooling to produce bootable media.

.PARAMETER WorkspacePath
Path to the workspace directory where the WinPE media will be built. A 'WinPE'
subdirectory will be created for the working files.

.PARAMETER Architecture
Target architecture for the WinPE image. Valid values are 'amd64' or 'arm64'.
Defaults to 'amd64'.

.PARAMETER IsoOutputPath
Full path where the output ISO file will be created. If not specified, defaults
to 'WinPE_MCD_<Architecture>.iso' in the workspace directory.

.PARAMETER IsoLabel
Volume label for the ISO file. Limited to 16 characters. Defaults to 'MCD_WINPE'.

.PARAMETER Packages
Array of WinPE optional component names to add to the boot image. Package names
should be specified without path (e.g., 'WinPE-WMI', 'WinPE-PowerShell').

.PARAMETER NoPrompt
When specified, creates an ISO that boots without the 'Press any key' prompt.

.PARAMETER CleanupWorkingDirectory
When specified, removes the working directory after ISO creation.

.EXAMPLE
New-MCDWinPEBootImage -WorkspacePath 'C:\MCD\Workspace' -Architecture 'amd64'

Creates an amd64 WinPE boot image ISO in the workspace directory.

.EXAMPLE
New-MCDWinPEBootImage -WorkspacePath 'C:\MCD\Workspace' -Architecture 'arm64' -IsoOutputPath 'C:\Output\WinPE_arm64.iso' -NoPrompt

Creates an arm64 WinPE boot image ISO at the specified path without boot prompt.
#>
function New-MCDWinPEBootImage
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $WorkspacePath,

        [Parameter()]
        [ValidateSet('amd64', 'arm64')]
        [string]
        $Architecture = 'amd64',

        [Parameter()]
        [string]
        $IsoOutputPath,

        [Parameter()]
        [ValidateLength(1, 16)]
        [string]
        $IsoLabel = 'MCD_WINPE',

        [Parameter()]
        [string[]]
        $Packages,

        [Parameter()]
        [switch]
        $NoPrompt,

        [Parameter()]
        [switch]
        $CleanupWorkingDirectory
    )

    Write-MCDLog -Message "[BootImage] Starting WinPE boot image creation for $Architecture." -Level Info

    # Validate ADK is installed with WinPE add-on
    $adkInfo = Get-MCDADKInstaller -IncludeWinPE
    if (-not $adkInfo.IsInstalled)
    {
        throw 'Windows ADK is not installed. Run Install-MCDADK first.'
    }
    if (-not $adkInfo.HasWinPEAddOn)
    {
        throw 'Windows PE add-on is not installed. Run Install-MCDWinPEComponents first.'
    }

    Write-MCDLog -Message "[BootImage] ADK detected at: $($adkInfo.InstallPath)" -Level Verbose

    # Resolve ADK paths for the target architecture
    $adkPaths = Get-MCDADKPaths -ADKInfo $adkInfo -Architecture $Architecture
    if (-not $adkPaths)
    {
        throw "Failed to resolve ADK paths for architecture: $Architecture"
    }

    # Setup working directory
    $winPEWorkPath = Join-Path -Path $WorkspacePath -ChildPath 'WinPE'
    $mediaPath = Join-Path -Path $winPEWorkPath -ChildPath 'media'
    $mountPath = Join-Path -Path $winPEWorkPath -ChildPath 'mount'
    $bootWimPath = Join-Path -Path $mediaPath -ChildPath 'sources\boot.wim'

    if ($PSCmdlet.ShouldProcess($winPEWorkPath, 'Create WinPE working directory'))
    {
        # Clean up existing working directory
        if (Test-Path -Path $winPEWorkPath)
        {
            Write-MCDLog -Message "[BootImage] Removing existing WinPE working directory: $winPEWorkPath" -Level Verbose
            Remove-Item -Path $winPEWorkPath -Recurse -Force
        }

        # Create working directories
        Write-MCDLog -Message "[BootImage] Creating WinPE working directories." -Level Verbose
        $null = New-Item -Path $mediaPath -ItemType Directory -Force
        $null = New-Item -Path $mountPath -ItemType Directory -Force
        $null = New-Item -Path (Join-Path -Path $mediaPath -ChildPath 'sources') -ItemType Directory -Force

        # Copy WinPE media files
        Write-MCDLog -Message "[BootImage] Copying WinPE media files from ADK." -Level Info
        Copy-Item -Path "$($adkPaths.WinPEMediaPath)\*" -Destination $mediaPath -Recurse -Force

        # Copy boot.wim
        Write-MCDLog -Message "[BootImage] Copying boot.wim from ADK." -Level Info
        Copy-Item -Path $adkPaths.WinPEWimPath -Destination $bootWimPath -Force
    }

    # Mount boot.wim
    if ($PSCmdlet.ShouldProcess($bootWimPath, 'Mount boot.wim'))
    {
        Mount-MCDBootImage -ImagePath $bootWimPath -MountPath $mountPath
    }

    # Add optional components if specified
    if ($Packages -and $Packages.Count -gt 0)
    {
        if ($PSCmdlet.ShouldProcess($mountPath, "Add WinPE packages: $($Packages -join ', ')"))
        {
            Add-MCDWinPEComponents -MountPath $mountPath -Packages $Packages -WinPEOCsPath $adkPaths.WinPEOCsPath
        }
    }

    # Dismount and save boot.wim
    if ($PSCmdlet.ShouldProcess($mountPath, 'Dismount and save boot.wim'))
    {
        Dismount-MCDBootImage -MountPath $mountPath -Save
    }

    # Build ISO
    if ([string]::IsNullOrWhiteSpace($IsoOutputPath))
    {
        $IsoOutputPath = Join-Path -Path $WorkspacePath -ChildPath "WinPE_MCD_$Architecture.iso"
    }

    $isoParams = @{
        MediaPath    = $mediaPath
        OutputPath   = $IsoOutputPath
        Label        = $IsoLabel
        Architecture = $Architecture
        ADKPaths     = $adkPaths
        NoPrompt     = $NoPrompt.IsPresent
    }

    if ($PSCmdlet.ShouldProcess($IsoOutputPath, 'Create boot ISO'))
    {
        $isoFile = New-MCDBootImageISO @isoParams
    }

    # Cleanup working directory if requested
    if ($CleanupWorkingDirectory -and (Test-Path -Path $winPEWorkPath))
    {
        if ($PSCmdlet.ShouldProcess($winPEWorkPath, 'Remove WinPE working directory'))
        {
            Write-MCDLog -Message "[BootImage] Cleaning up WinPE working directory." -Level Verbose
            Remove-Item -Path $winPEWorkPath -Recurse -Force
        }
    }

    Write-MCDLog -Message "[BootImage] WinPE boot image creation completed: $IsoOutputPath" -Level Info

    if ($isoFile)
    {
        return $isoFile
    }
}

<#
.SYNOPSIS
Resolves ADK paths for a specific architecture.

.DESCRIPTION
Internal helper function that builds a paths object for the Windows ADK based
on the installed ADK information and target architecture. Handles the ARM64
etfsboot.com redirect (falls back to amd64 if ARM64 version is missing).

.PARAMETER ADKInfo
An ADKInstallerModel object containing ADK installation information.

.PARAMETER Architecture
Target architecture. Valid values are 'amd64' or 'arm64'.

.EXAMPLE
$paths = Get-MCDADKPaths -ADKInfo $adkInfo -Architecture 'amd64'

Returns a hashtable with all ADK paths for the amd64 architecture.
#>
function Get-MCDADKPaths
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ADKInstallerModel]
        $ADKInfo,

        [Parameter(Mandatory = $true)]
        [ValidateSet('amd64', 'arm64')]
        [string]
        $Architecture
    )

    $deploymentToolsPath = Join-Path -Path $ADKInfo.InstallPath -ChildPath "Deployment Tools\$Architecture"
    $oscdimgPath = Join-Path -Path $deploymentToolsPath -ChildPath 'Oscdimg'

    # WinPE paths
    $winPEPath = Join-Path -Path $ADKInfo.WinPEAddOnPath -ChildPath $Architecture

    # etfsboot.com - ARM64 does not have this file, redirect to amd64
    $etfsbootPath = Join-Path -Path $oscdimgPath -ChildPath 'etfsboot.com'
    if (-not (Test-Path -Path $etfsbootPath) -and $Architecture -eq 'arm64')
    {
        Write-MCDLog -Message "[ADKPaths] ARM64 etfsboot.com not found, falling back to amd64." -Level Verbose
        $amd64OscdimgPath = Join-Path -Path $ADKInfo.InstallPath -ChildPath 'Deployment Tools\amd64\Oscdimg'
        $etfsbootPath = Join-Path -Path $amd64OscdimgPath -ChildPath 'etfsboot.com'
    }

    return @{
        DeploymentToolsPath = $deploymentToolsPath
        OscdimgPath         = $oscdimgPath
        OscdimgExe          = Join-Path -Path $oscdimgPath -ChildPath 'oscdimg.exe'
        EtfsbootPath        = $etfsbootPath
        EfisysPath          = Join-Path -Path $oscdimgPath -ChildPath 'efisys.bin'
        EfisysNopromptPath  = Join-Path -Path $oscdimgPath -ChildPath 'efisys_noprompt.bin'
        WinPEPath           = $winPEPath
        WinPEMediaPath      = Join-Path -Path $winPEPath -ChildPath 'Media'
        WinPEWimPath        = Join-Path -Path $winPEPath -ChildPath 'en-us\winpe.wim'
        WinPEOCsPath        = Join-Path -Path $winPEPath -ChildPath 'WinPE_OCs'
        Architecture        = $Architecture
    }
}
