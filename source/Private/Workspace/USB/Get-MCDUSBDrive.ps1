<#
.SYNOPSIS
Retrieves removable USB drives available for creating bootable media.

.DESCRIPTION
Enumerates all removable USB drives using Get-Disk and WMI (Win32_DiskDrive) to
identify drives suitable for creating MCD bootable media. Returns detailed info
about each drive including disk number, model, size, and bus type.

This function only returns removable drives to avoid accidental formatting of
fixed disks. Use the output to select a target disk for Format-MCDUSB.

.PARAMETER MinimumSizeGB
Minimum disk size in gigabytes to include in results. Drives smaller than
this are excluded. Default is 8 GB.

.EXAMPLE
Get-MCDUSBDrive

Returns all removable USB drives with at least 8 GB capacity.

.EXAMPLE
Get-MCDUSBDrive -MinimumSizeGB 16

Returns all removable USB drives with at least 16 GB capacity.
#>
function Get-MCDUSBDrive
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param
    (
        [Parameter()]
        [ValidateRange(1, 1024)]
        [int]
        $MinimumSizeGB = 8
    )

    Write-MCDLog -Level Info -Message 'Enumerating removable USB drives...'

    $minimumSizeBytes = [int64]$MinimumSizeGB * 1GB

    $disks = Get-Disk -ErrorAction SilentlyContinue | Where-Object {
        $_.BusType -eq 'USB' -and
        $_.Size -ge $minimumSizeBytes
    }

    if (-not $disks)
    {
        Write-MCDLog -Level Warning -Message 'No removable USB drives found meeting size requirements.'
        return @()
    }

    $results = @()
    foreach ($disk in $disks)
    {
        $sizeGB = [math]::Round($disk.Size / 1GB, 2)

        $usbDrive = [PSCustomObject]@{
            DiskNumber      = $disk.Number
            FriendlyName    = $disk.FriendlyName
            Model           = $disk.Model
            SizeGB          = $sizeGB
            SizeBytes       = $disk.Size
            BusType         = $disk.BusType
            PartitionStyle  = $disk.PartitionStyle
            OperationalStatus = $disk.OperationalStatus
            IsOffline       = $disk.IsOffline
            IsReadOnly      = $disk.IsReadOnly
        }

        $results += $usbDrive

        Write-MCDLog -Level Verbose -Message ("Found USB drive: DiskNumber={0}, Model='{1}', SizeGB={2}" -f $disk.Number, $disk.Model, $sizeGB)
    }

    Write-MCDLog -Level Info -Message ("Found {0} removable USB drive(s)." -f $results.Count)

    return $results
}
