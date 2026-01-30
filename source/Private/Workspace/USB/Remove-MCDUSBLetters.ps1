<#
.SYNOPSIS
Removes all drive letter access paths from a disk's partitions.

.DESCRIPTION
Removes all access paths (drive letters) from all partitions on the specified
disk. This is an OSD-style safety pattern to prevent Windows from automatically
reassigning drive letters during destructive disk operations.

Returns a collection of removed access paths that can be passed to
Restore-MCDUSBLetters to restore them after operations complete.

This function is typically used before Format-MCDUSB and restored after
Copy-MCDBootImageToUSB completes.

.PARAMETER DiskNumber
The disk number to remove access paths from.

.EXAMPLE
$removedPaths = Remove-MCDUSBLetters -DiskNumber 2

Removes all drive letters from disk 2 and stores the info for later restoration.

.EXAMPLE
$removedPaths = Remove-MCDUSBLetters -DiskNumber 2
# ... perform disk operations ...
Restore-MCDUSBLetters -RemovedPaths $removedPaths

Full pattern: remove letters, operate, restore letters.
#>
function Remove-MCDUSBLetters
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 999)]
        [int]
        $DiskNumber
    )

    Write-MCDLog -Level Info -Message ("Removing access paths from disk {0}..." -f $DiskNumber)

    $partitions = Get-Partition -DiskNumber $DiskNumber -ErrorAction SilentlyContinue

    if (-not $partitions)
    {
        Write-MCDLog -Level Verbose -Message ("No partitions found on disk {0}." -f $DiskNumber)
        return @()
    }

    $removedPaths = @()

    foreach ($partition in $partitions)
    {
        $accessPaths = $partition.AccessPaths | Where-Object {
            $_ -match '^[A-Z]:\\$'
        }

        foreach ($accessPath in $accessPaths)
        {
            $driveLetter = $accessPath.Substring(0, 1)

            $description = "Remove access path '{0}' from partition {1} on disk {2}" -f $accessPath, $partition.PartitionNumber, $DiskNumber

            if ($PSCmdlet.ShouldProcess($description, 'Remove-PartitionAccessPath'))
            {
                try
                {
                    Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath $accessPath -ErrorAction Stop

                    $removedPath = [PSCustomObject]@{
                        DiskNumber      = $DiskNumber
                        PartitionNumber = $partition.PartitionNumber
                        AccessPath      = $accessPath
                        DriveLetter     = $driveLetter
                        RemovedAt       = (Get-Date)
                    }

                    $removedPaths += $removedPath

                    Write-MCDLog -Level Verbose -Message ("Removed access path '{0}' from partition {1}." -f $accessPath, $partition.PartitionNumber)
                }
                catch
                {
                    Write-MCDLog -Level Warning -Message ("Failed to remove access path '{0}': {1}" -f $accessPath, $_.Exception.Message)
                }
            }
            else
            {
                $removedPath = [PSCustomObject]@{
                    DiskNumber      = $DiskNumber
                    PartitionNumber = $partition.PartitionNumber
                    AccessPath      = $accessPath
                    DriveLetter     = $driveLetter
                    RemovedAt       = (Get-Date)
                }

                $removedPaths += $removedPath
            }
        }
    }

    Write-MCDLog -Level Info -Message ("Removed {0} access path(s) from disk {1}." -f $removedPaths.Count, $DiskNumber)

    return $removedPaths
}
