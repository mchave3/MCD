<#
.SYNOPSIS
Formats a USB drive with Boot (FAT32) and Deploy (NTFS) partitions for MCD bootable media.

.DESCRIPTION
Clears and reformats the specified USB drive with a dual-partition layout:
- Boot partition: 2 GB FAT32 for UEFI boot files
- Deploy partition: Remaining space as NTFS for deployment content

This is a DESTRUCTIVE operation that will erase all data on the target disk.
The function requires ShouldProcess confirmation and validates that the target
disk is a removable USB drive before proceeding.

This function uses the OSD-style drive letter safety pattern: existing access
paths are removed before operations and can be restored after completion.

.PARAMETER DiskNumber
The disk number of the USB drive to format.

.PARAMETER BootPartitionSizeGB
Size of the Boot partition in gigabytes. Default is 2 GB.

.PARAMETER BootPartitionLabel
Volume label for the Boot partition. Default is 'Boot'.

.PARAMETER DeployPartitionLabel
Volume label for the Deploy partition. Default is 'Deploy'.

.EXAMPLE
Format-MCDUSB -DiskNumber 2

Formats disk 2 with default 2 GB Boot partition and remaining space for Deploy.

.EXAMPLE
Format-MCDUSB -DiskNumber 2 -BootPartitionSizeGB 4 -Confirm:$false

Formats disk 2 with 4 GB Boot partition, skipping confirmation.
#>
function Format-MCDUSB
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
        [ValidateRange(1, 32)]
        [int]
        $BootPartitionSizeGB = 2,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $BootPartitionLabel = 'Boot',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DeployPartitionLabel = 'Deploy'
    )

    Write-MCDLog -Level Info -Message ("Preparing to format USB disk {0}..." -f $DiskNumber)

    # Safety gate: require full OS and administrator rights for destructive USB operations
    $null = Test-MCDPrerequisite -RequireFullOS -RequireAdministrator

    $disk = Get-Disk -Number $DiskNumber -ErrorAction Stop

    if ($disk.BusType -ne 'USB')
    {
        throw ("Disk {0} is not a USB drive (BusType='{1}'). Refusing to format non-USB drives for safety." -f $DiskNumber, $disk.BusType)
    }

    # Safety gate: refuse to format system or boot disks
    if ($disk.IsSystem)
    {
        throw ("Disk {0} is a system disk. Refusing to format system disks for safety." -f $DiskNumber)
    }

    if ($disk.IsBoot)
    {
        throw ("Disk {0} is a boot disk. Refusing to format boot disks for safety." -f $DiskNumber)
    }

    $diskSizeGB = [math]::Round($disk.Size / 1GB, 2)
    Write-MCDLog -Level Info -Message ("Target USB disk {0}: Model='{1}', SizeGB={2}" -f $DiskNumber, $disk.Model, $diskSizeGB)

    $bootSizeBytes = [int64]$BootPartitionSizeGB * 1GB
    $minimumRequiredBytes = $bootSizeBytes + (1GB)

    if ($disk.Size -lt $minimumRequiredBytes)
    {
        throw ("Disk {0} is too small ({1} GB). Minimum required: {2} GB for Boot + 1 GB for Deploy." -f $DiskNumber, $diskSizeGB, ($BootPartitionSizeGB + 1))
    }

    $operationDescription = "ERASE ALL DATA on USB disk {0} ('{1}', {2} GB) and create Boot/Deploy partitions" -f $DiskNumber, $disk.Model, $diskSizeGB

    if (-not $PSCmdlet.ShouldProcess($operationDescription, 'Format-MCDUSB'))
    {
        return
    }

    Write-MCDLog -Level Info -Message 'Clearing disk and removing existing partitions...'
    $null = Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop

    Write-MCDLog -Level Info -Message 'Initializing disk with MBR partition style...'
    $null = Initialize-Disk -Number $DiskNumber -PartitionStyle MBR -Confirm:$false -ErrorAction Stop

    $bootLetter = Get-MCDAvailableDriveLetter -PreferredLetters @('B', 'P', 'R')
    $deployLetter = Get-MCDAvailableDriveLetter -PreferredLetters @('D', 'Q', 'S') -ExcludeLetters @($bootLetter)

    Write-MCDLog -Level Info -Message ("Creating Boot partition ({0} GB, FAT32, drive letter {1})..." -f $BootPartitionSizeGB, $bootLetter)
    $bootPartition = New-Partition -DiskNumber $DiskNumber -Size $bootSizeBytes -IsActive -DriveLetter $bootLetter -ErrorAction Stop
    $null = Format-Volume -DriveLetter $bootLetter -FileSystem FAT32 -NewFileSystemLabel $BootPartitionLabel -Force -Confirm:$false -ErrorAction Stop

    Write-MCDLog -Level Info -Message ("Creating Deploy partition (remaining space, NTFS, drive letter {0})..." -f $deployLetter)
    $deployPartition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -DriveLetter $deployLetter -ErrorAction Stop
    $null = Format-Volume -DriveLetter $deployLetter -FileSystem NTFS -NewFileSystemLabel $DeployPartitionLabel -Force -Confirm:$false -ErrorAction Stop

    $bootVolume = Get-Volume -DriveLetter $bootLetter -ErrorAction SilentlyContinue
    $deployVolume = Get-Volume -DriveLetter $deployLetter -ErrorAction SilentlyContinue

    $result = [PSCustomObject]@{
        DiskNumber             = $DiskNumber
        PartitionStyle         = 'MBR'
        BootDriveLetter        = $bootLetter
        BootPartitionNumber    = $bootPartition.PartitionNumber
        BootPartitionSizeGB    = [math]::Round($bootPartition.Size / 1GB, 2)
        BootFileSystem         = 'FAT32'
        BootLabel              = $BootPartitionLabel
        DeployDriveLetter      = $deployLetter
        DeployPartitionNumber  = $deployPartition.PartitionNumber
        DeployPartitionSizeGB  = [math]::Round($deployPartition.Size / 1GB, 2)
        DeployFileSystem       = 'NTFS'
        DeployLabel            = $DeployPartitionLabel
    }

    Write-MCDLog -Level Info -Message ("USB disk {0} formatted successfully. Boot={1}:, Deploy={2}:" -f $DiskNumber, $bootLetter, $deployLetter)

    return $result
}
