<#
.SYNOPSIS
Copies boot image files (ISO contents) to a formatted USB Boot partition.

.DESCRIPTION
Copies the contents of a WinPE boot ISO or mounted ISO to the Boot partition
of a formatted USB drive. This includes EFI boot files, boot manager, BCD,
and WinPE boot.wim.

The function expects the source to be either:
- A mounted ISO drive letter (e.g., 'E:\')
- A path to extracted boot media content

The destination should be the Boot partition created by Format-MCDUSB.

This is a potentially destructive operation as it overwrites existing files
on the target partition. Implements ShouldProcess for safety.

.PARAMETER MediaPath
Path to the WinPE media directory (mounted ISO root or extracted folder).
Must contain the expected boot structure: 'boot', 'efi', and 'sources' directories.
Alias: SourcePath

.PARAMETER BootDriveLetter
Drive letter of the target Boot partition (without colon).
Alias: DestinationDriveLetter

.PARAMETER UseRobocopy
Use Robocopy instead of Copy-Item for more reliable copying. Default is true.

.EXAMPLE
Copy-MCDBootImageToUSB -MediaPath 'E:\' -BootDriveLetter 'B'

Copies boot files from mounted ISO at E:\ to USB Boot partition B:.

.EXAMPLE
$usbInfo = Format-MCDUSB -DiskNumber 2
Mount-DiskImage -ImagePath 'C:\WinPE.iso'
$isoLetter = (Get-DiskImage -ImagePath 'C:\WinPE.iso' | Get-Volume).DriveLetter
Copy-MCDBootImageToUSB -MediaPath "$isoLetter`:\" -BootDriveLetter $usbInfo.BootDriveLetter

Full workflow: format USB, mount ISO, copy boot files.
#>
function Copy-MCDBootImageToUSB
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('SourcePath')]
        [string]
        $MediaPath,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z]$')]
        [Alias('DestinationDriveLetter')]
        [string]
        $BootDriveLetter,

        [Parameter()]
        [switch]
        $UseRobocopy = $true
    )

    $BootDriveLetter = $BootDriveLetter.ToUpperInvariant()
    $destinationRoot = "{0}:\" -f $BootDriveLetter

    Write-MCDLog -Level Info -Message ("Preparing to copy boot files from '{0}' to '{1}'..." -f $MediaPath, $destinationRoot)

    if (-not (Test-Path -Path $MediaPath -PathType Container))
    {
        throw ("Media path does not exist or is not a directory: {0}" -f $MediaPath)
    }

    # Validate WinPE media structure: boot, efi, sources directories
    $requiredPaths = @(
        'boot',
        'efi',
        'sources'
    )

    $missingPaths = @()
    foreach ($requiredPath in $requiredPaths)
    {
        $fullPath = Join-Path -Path $MediaPath -ChildPath $requiredPath
        if (-not (Test-Path -Path $fullPath))
        {
            $missingPaths += $requiredPath
        }
    }

    if ($missingPaths.Count -gt 0)
    {
        Write-MCDLog -Level Warning -Message ("Media path is missing expected boot structure: {0}. Expected: boot, efi, sources directories." -f ($missingPaths -join ', '))
    }

    if (-not (Test-Path -Path $destinationRoot -PathType Container))
    {
        throw ("Destination drive does not exist: {0}" -f $destinationRoot)
    }

    $operationDescription = "Copy boot files from '{0}' to USB Boot partition '{1}'" -f $MediaPath, $destinationRoot

    if (-not $PSCmdlet.ShouldProcess($operationDescription, 'Copy-MCDBootImageToUSB'))
    {
        return
    }

    $startTime = Get-Date
    $filesCopied = 0
    $bytesCopied = 0

    if ($UseRobocopy)
    {
        Write-MCDLog -Level Info -Message 'Using Robocopy for file transfer...'

        $robocopyArgs = @(
            "`"$MediaPath`""
            "`"$destinationRoot`""
            '/E'
            '/COPYALL'
            '/R:3'
            '/W:3'
            '/NP'
            '/NDL'
            '/NFL'
        )

        $robocopyResult = Start-Process -FilePath 'robocopy.exe' -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop

        if ($robocopyResult.ExitCode -ge 8)
        {
            throw ("Robocopy failed with exit code {0}. This indicates a copy error." -f $robocopyResult.ExitCode)
        }

        Write-MCDLog -Level Verbose -Message ("Robocopy completed with exit code {0}." -f $robocopyResult.ExitCode)
    }
    else
    {
        Write-MCDLog -Level Info -Message 'Using Copy-Item for file transfer...'

        $sourceItems = Get-ChildItem -Path $MediaPath -Force -ErrorAction Stop

        foreach ($item in $sourceItems)
        {
            $destPath = Join-Path -Path $destinationRoot -ChildPath $item.Name

            try
            {
                Copy-Item -Path $item.FullName -Destination $destPath -Recurse -Force -ErrorAction Stop

                if ($item.PSIsContainer)
                {
                    $subItems = Get-ChildItem -Path $item.FullName -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { -not $_.PSIsContainer }
                    $filesCopied += @($subItems).Count
                    $bytesCopied += (@($subItems) | Measure-Object -Property Length -Sum).Sum
                }
                else
                {
                    $filesCopied++
                    $bytesCopied += $item.Length
                }

                Write-MCDLog -Level Verbose -Message ("Copied: {0}" -f $item.Name)
            }
            catch
            {
                Write-MCDLog -Level Warning -Message ("Failed to copy '{0}': {1}" -f $item.Name, $_.Exception.Message)
            }
        }
    }

    $endTime = Get-Date
    $duration = $endTime - $startTime

    $copiedFiles = Get-ChildItem -Path $destinationRoot -Recurse -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer }
    $totalFiles = @($copiedFiles).Count
    $totalSizeMB = [math]::Round((@($copiedFiles) | Measure-Object -Property Length -Sum).Sum / 1MB, 2)

    $result = [PSCustomObject]@{
        MediaPath              = $MediaPath
        DestinationPath        = $destinationRoot
        BootDriveLetter        = $BootDriveLetter
        TotalFiles             = $totalFiles
        TotalSizeMB            = $totalSizeMB
        DurationSeconds        = [math]::Round($duration.TotalSeconds, 2)
        UsedRobocopy           = [bool]$UseRobocopy
        CopyCompletedAt        = $endTime
    }

    Write-MCDLog -Level Info -Message ("Boot files copied successfully. Files={0}, SizeMB={1}, Duration={2}s" -f $totalFiles, $totalSizeMB, [math]::Round($duration.TotalSeconds, 2))

    return $result
}
