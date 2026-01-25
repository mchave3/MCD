function Get-MCDTargetDiskCandidate
{
    <#
    .SYNOPSIS
    Returns candidate target disks for deployment in WinPE.

    .DESCRIPTION
    Enumerates local disks and filters out disks by BusType (for example USB)
    to build a candidate list. Each returned object includes a DisplayName that
    is suitable for use in the WinPE wizard UI.

    .PARAMETER ExcludeBusTypes
    One or more storage BusTypes to exclude (for example 'USB').

    .EXAMPLE
    Get-MCDTargetDiskCandidate -ExcludeBusTypes @('USB')

    Lists candidate target disks excluding USB devices.
    #>
    [CmdletBinding()]
    [OutputType([System.Array])]
    param
    (
        [Parameter()]
        [string[]]
        $ExcludeBusTypes = @('USB')
    )

    $exclude = @()
    if ($ExcludeBusTypes)
    {
        $exclude = @($ExcludeBusTypes)
    }

    $disks = Get-Disk -ErrorAction Stop | Sort-Object -Property Number
    $candidates = foreach ($disk in $disks)
    {
        if ($exclude -and ($disk.BusType -in $exclude))
        {
            continue
        }

        $sizeGb = [math]::Round(($disk.Size / 1GB), 0)
        $label = "Disk {0} - {1}GB - {2} - {3} ({4})" -f $disk.Number, $sizeGb, $disk.BusType, $disk.FriendlyName, $disk.PartitionStyle

        [PSCustomObject]@{
            DiskNumber     = $disk.Number
            BusType        = [string]$disk.BusType
            FriendlyName   = [string]$disk.FriendlyName
            PartitionStyle = [string]$disk.PartitionStyle
            Size           = $disk.Size
            SizeGB         = $sizeGb
            DisplayName    = $label
        }
    }

    @($candidates)
}
