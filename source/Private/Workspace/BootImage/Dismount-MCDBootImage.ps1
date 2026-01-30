<#
.SYNOPSIS
Dismounts a Windows PE boot image.

.DESCRIPTION
Dismounts a previously mounted Windows PE boot.wim image. Can either save
changes or discard them based on the Save parameter. Uses the Dismount-WindowsImage
cmdlet for the dismount operation.

.PARAMETER MountPath
Directory path where the image is currently mounted.

.PARAMETER Save
When specified, commits changes to the WIM file before dismounting.
When not specified, changes are discarded.

.EXAMPLE
Dismount-MCDBootImage -MountPath 'C:\WinPE\mount' -Save

Dismounts the boot image and saves all changes.

.EXAMPLE
Dismount-MCDBootImage -MountPath 'C:\WinPE\mount'

Dismounts the boot image and discards all changes.
#>
function Dismount-MCDBootImage
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MountPath,

        [Parameter()]
        [switch]
        $Save
    )

    $action = if ($Save) { 'Save' } else { 'Discard' }
    Write-MCDLog -Message "[BootImage] Dismounting boot image from: $MountPath (Action: $action)" -Level Info

    # Validate mount path exists
    if (-not (Test-Path -Path $MountPath))
    {
        throw "Mount path does not exist: $MountPath"
    }

    # Check if actually mounted
    $mountedImages = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue
    $currentMount = $mountedImages | Where-Object { $_.Path -eq $MountPath }

    if (-not $currentMount)
    {
        Write-MCDLog -Message "[BootImage] No image is mounted at: $MountPath" -Level Warning
        return
    }

    if ($PSCmdlet.ShouldProcess($MountPath, "Dismount Windows image ($action)"))
    {
        try
        {
            if ($Save)
            {
                Write-MCDLog -Message "[BootImage] Saving changes and dismounting image." -Level Verbose
                $null = Dismount-WindowsImage -Path $MountPath -Save -ErrorAction Stop
            }
            else
            {
                Write-MCDLog -Message "[BootImage] Discarding changes and dismounting image." -Level Verbose
                $null = Dismount-WindowsImage -Path $MountPath -Discard -ErrorAction Stop
            }

            Write-MCDLog -Message "[BootImage] Successfully dismounted image from: $MountPath" -Level Info
        }
        catch
        {
            Write-MCDLog -Message "[BootImage] Failed to dismount image: $($_.Exception.Message)" -Level Error
            throw "Failed to dismount boot image: $($_.Exception.Message)"
        }
    }
}
