<#
.SYNOPSIS
Creates a bootable ISO from WinPE media using oscdimg.

.DESCRIPTION
Builds a bootable ISO file from a prepared WinPE media directory using the
ADK oscdimg tool. Supports both BIOS and UEFI boot modes with architecture-
aware bootdata configuration. For amd64, creates a dual-boot ISO (BIOS + UEFI).
For arm64, creates a UEFI-only ISO.

.PARAMETER MediaPath
Path to the prepared WinPE media directory (containing boot folder, sources, etc.).

.PARAMETER OutputPath
Full path where the output ISO file will be created.

.PARAMETER Label
Volume label for the ISO file. Limited to 16 characters.

.PARAMETER Architecture
Target architecture. Affects the bootdata configuration.

.PARAMETER ADKPaths
Hashtable containing ADK paths (from Get-MCDADKPaths).

.PARAMETER NoPrompt
When specified, uses efisys_noprompt.bin to skip the 'Press any key' prompt.

.EXAMPLE
New-MCDBootImageISO -MediaPath 'C:\WinPE\media' -OutputPath 'C:\Output\WinPE.iso' -Label 'MCD_WINPE' -Architecture 'amd64' -ADKPaths $adkPaths

Creates a bootable ISO from the media directory.
#>
function New-MCDBootImageISO
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MediaPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputPath,

        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 16)]
        [string]
        $Label,

        [Parameter(Mandatory = $true)]
        [ValidateSet('amd64', 'arm64')]
        [string]
        $Architecture,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $ADKPaths,

        [Parameter()]
        [switch]
        $NoPrompt
    )

    Write-MCDLog -Message "[BootImage] Creating ISO: $OutputPath" -Level Info
    Write-MCDLog -Message "[BootImage] Architecture: $Architecture, Label: $Label" -Level Verbose

    # Validate paths
    if (-not (Test-Path -Path $MediaPath))
    {
        throw "Media path does not exist: $MediaPath"
    }

    $oscdimgExe = $ADKPaths.OscdimgExe
    if (-not (Test-Path -Path $oscdimgExe))
    {
        throw "oscdimg.exe not found: $oscdimgExe"
    }

    # Ensure boot and EFI directories exist
    $bootPath = Join-Path -Path $MediaPath -ChildPath 'boot'
    $efiBootPath = Join-Path -Path $MediaPath -ChildPath 'efi\microsoft\boot'

    if (-not (Test-Path -Path $bootPath))
    {
        throw "Boot directory not found in media: $bootPath"
    }

    # Create EFI boot directory if it doesn't exist
    if (-not (Test-Path -Path $efiBootPath))
    {
        $null = New-Item -Path $efiBootPath -ItemType Directory -Force
    }

    # Copy boot files from ADK
    $etfsbootPath = $ADKPaths.EtfsbootPath
    $efisysPath = if ($NoPrompt) { $ADKPaths.EfisysNopromptPath } else { $ADKPaths.EfisysPath }

    # Destination paths within media
    $destEtfsboot = Join-Path -Path $bootPath -ChildPath 'etfsboot.com'
    $destEfisys = Join-Path -Path $efiBootPath -ChildPath 'efisys.bin'

    if ($PSCmdlet.ShouldProcess($destEtfsboot, 'Copy etfsboot.com'))
    {
        if (Test-Path -Path $etfsbootPath)
        {
            Copy-Item -Path $etfsbootPath -Destination $destEtfsboot -Force
        }
    }

    if ($PSCmdlet.ShouldProcess($destEfisys, 'Copy efisys.bin'))
    {
        if (Test-Path -Path $efisysPath)
        {
            Copy-Item -Path $efisysPath -Destination $destEfisys -Force
        }
    }

    # Build oscdimg arguments based on architecture
    # amd64: Dual boot (BIOS + UEFI) with bootdata:2
    # arm64: UEFI only with bootdata:1
    $labelArg = "-l`"$Label`""

    if ($Architecture -eq 'amd64')
    {
        # BIOS: etfsboot.com, UEFI: efisys.bin
        $bootdataArg = "-bootdata:2#p0,e,b`"$destEtfsboot`"#pEF,e,b`"$destEfisys`""
    }
    else
    {
        # arm64: UEFI only
        $bootdataArg = "-bootdata:1#pEF,e,b`"$destEfisys`""
    }

    $oscdimgArgs = @(
        '-m'
        '-o'
        '-u2'
        '-udfver102'
        $bootdataArg
        $labelArg
        "`"$MediaPath`""
        "`"$OutputPath`""
    )

    $argsString = $oscdimgArgs -join ' '
    Write-MCDLog -Message "[BootImage] oscdimg arguments: $argsString" -Level Verbose

    if ($PSCmdlet.ShouldProcess($OutputPath, 'Create ISO with oscdimg'))
    {
        # Ensure output directory exists
        $outputDir = Split-Path -Path $OutputPath -Parent
        if (-not (Test-Path -Path $outputDir))
        {
            $null = New-Item -Path $outputDir -ItemType Directory -Force
        }

        try
        {
            $processInfo = @{
                FilePath     = $oscdimgExe
                ArgumentList = $argsString
                Wait         = $true
                PassThru     = $true
                NoNewWindow  = $true
            }

            $process = Start-Process @processInfo

            if ($process.ExitCode -ne 0)
            {
                throw "oscdimg failed with exit code: $($process.ExitCode)"
            }

            if (Test-Path -Path $OutputPath)
            {
                Write-MCDLog -Message "[BootImage] ISO created successfully: $OutputPath" -Level Info
                return Get-Item -Path $OutputPath
            }
            else
            {
                throw 'oscdimg completed but ISO file was not created.'
            }
        }
        catch
        {
            Write-MCDLog -Message "[BootImage] Failed to create ISO: $($_.Exception.Message)" -Level Error
            throw "Failed to create ISO: $($_.Exception.Message)"
        }
    }
}
