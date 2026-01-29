<#
.SYNOPSIS
Prepares a target disk for Windows deployment in WinPE.

.DESCRIPTION
Clears and initializes a disk according to the WinPE DiskPolicy and creates
a basic UEFI/GPT partition layout suitable for applying a Windows image.
This function is intentionally guarded: destructive actions only run when
DiskPolicy.AllowDestructiveActions is enabled.

Current layout (UEFI/GPT):
- EFI System Partition (FAT32, 260MB)
- Microsoft Reserved Partition (MSR, 16MB)
- Windows partition (NTFS, remaining space)

The layout aligns with Microsoft partitioning guidance and uses the WinPE-
safe drive letters recommended by Microsoft (System=S, Windows=W) when
available.

.PARAMETER DiskNumber
Disk number to prepare (the disk will be wiped and repartitioned when
destructive actions are permitted).

.PARAMETER DiskPolicy
WinPE disk policy object (typically from WinPE config). The property
AllowDestructiveActions must be $true to permit wiping/partitioning.

.EXAMPLE
Initialize-MCDTargetDisk -DiskNumber 0 -DiskPolicy ([pscustomobject]@{ AllowDestructiveActions = $true })

Clears disk 0 and creates a UEFI/GPT partition layout.
#>
function Initialize-MCDTargetDisk
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 999)]
        [int]
        $DiskNumber,

        [Parameter()]
        [ValidateNotNull()]
        [pscustomobject]
        $DiskPolicy = [pscustomobject]@{ AllowDestructiveActions = $false }
    )

    if (-not $DiskPolicy)
    {
        $DiskPolicy = [pscustomobject]@{ AllowDestructiveActions = $false }
    }

    if (-not [bool]$DiskPolicy.AllowDestructiveActions)
    {
        throw "Refusing to prepare disk because DiskPolicy.AllowDestructiveActions is disabled (DiskNumber=$DiskNumber)."
    }

    $disk = Get-Disk -Number $DiskNumber -ErrorAction Stop
    $diskSizeGb = $null
    if ($disk.Size)
    {
        $diskSizeGb = [math]::Round(($disk.Size / 1GB), 0)
    }
    Write-MCDLog -Level Info -Message ("Preparing target disk {0} (BusType='{1}', SizeGB='{2}')." -f $disk.Number, $disk.BusType, $diskSizeGb)

    if (-not $PSCmdlet.ShouldProcess("Disk $DiskNumber", 'Clear and initialize target disk'))
    {
        return
    }

    $null = Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
    $null = Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -Confirm:$false -ErrorAction Stop

    $systemLetter = Get-MCDAvailableDriveLetter -PreferredLetters @('S')
    $windowsLetter = Get-MCDAvailableDriveLetter -PreferredLetters @('W') -ExcludeLetters @($systemLetter)

    $efiGuid = '{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}'
    $msrGuid = '{E3C9E316-0B5C-4DB8-817D-F92DF00215AE}'

    $null = New-Partition -DiskNumber $DiskNumber -Size 260MB -GptType $efiGuid -DriveLetter $systemLetter -ErrorAction Stop
    $null = Format-Volume -DriveLetter $systemLetter -FileSystem FAT32 -NewFileSystemLabel 'System' -Force -Confirm:$false -ErrorAction Stop

    $null = New-Partition -DiskNumber $DiskNumber -Size 16MB -GptType $msrGuid -ErrorAction Stop

    $null = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -DriveLetter $windowsLetter -ErrorAction Stop
    $null = Format-Volume -DriveLetter $windowsLetter -FileSystem NTFS -NewFileSystemLabel 'Windows' -Force -Confirm:$false -ErrorAction Stop

    [PSCustomObject]@{
        DiskNumber        = $DiskNumber
        PartitionStyle    = 'GPT'
        SystemDriveLetter = $systemLetter
        WindowsDriveLetter = $windowsLetter
    }
}
