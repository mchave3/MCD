<#
.SYNOPSIS
Restores previously removed drive letter access paths to disk partitions.

.DESCRIPTION
Restores access paths (drive letters) that were previously removed by
Remove-MCDUSBLetters. This function attempts to restore the same drive
letters to the same partition numbers they were removed from.

If the original drive letter is no longer available (assigned to another
drive), the function logs a warning and skips that access path.

This is the second half of the OSD-style drive letter safety pattern.

.PARAMETER RemovedPaths
Collection of removed path objects returned by Remove-MCDUSBLetters.

.EXAMPLE
$removedPaths = Remove-MCDUSBLetters -DiskNumber 2
# ... perform disk operations ...
Restore-MCDUSBLetters -RemovedPaths $removedPaths

Restores all previously removed drive letters.
#>
function Restore-MCDUSBLetters
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [pscustomobject[]]
        $RemovedPaths
    )

    if (-not $RemovedPaths -or $RemovedPaths.Count -eq 0)
    {
        Write-MCDLog -Level Verbose -Message 'No access paths to restore.'
        return
    }

    Write-MCDLog -Level Info -Message ("Restoring {0} access path(s)..." -f $RemovedPaths.Count)

    $usedDrives = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Name.ToUpperInvariant() })

    foreach ($removedPath in $RemovedPaths)
    {
        $driveLetter = $removedPath.DriveLetter.ToUpperInvariant()

        if ($driveLetter -in $usedDrives)
        {
            Write-MCDLog -Level Warning -Message ("Drive letter '{0}' is no longer available, skipping restoration." -f $driveLetter)
            continue
        }

        $description = "Restore access path '{0}' to partition {1} on disk {2}" -f $removedPath.AccessPath, $removedPath.PartitionNumber, $removedPath.DiskNumber

        if ($PSCmdlet.ShouldProcess($description, 'Add-PartitionAccessPath'))
        {
            try
            {
                $partition = Get-Partition -DiskNumber $removedPath.DiskNumber -PartitionNumber $removedPath.PartitionNumber -ErrorAction SilentlyContinue

                if (-not $partition)
                {
                    Write-MCDLog -Level Warning -Message ("Partition {0} on disk {1} no longer exists, skipping." -f $removedPath.PartitionNumber, $removedPath.DiskNumber)
                    continue
                }

                Add-PartitionAccessPath -DiskNumber $removedPath.DiskNumber -PartitionNumber $removedPath.PartitionNumber -AccessPath $removedPath.AccessPath -ErrorAction Stop

                Write-MCDLog -Level Verbose -Message ("Restored access path '{0}' to partition {1}." -f $removedPath.AccessPath, $removedPath.PartitionNumber)
            }
            catch
            {
                Write-MCDLog -Level Warning -Message ("Failed to restore access path '{0}': {1}" -f $removedPath.AccessPath, $_.Exception.Message)
            }
        }
    }

    Write-MCDLog -Level Info -Message 'Access path restoration completed.'
}
