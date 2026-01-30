<#
.SYNOPSIS
Mounts a Windows PE boot.wim image for servicing.

.DESCRIPTION
Mounts a Windows PE boot.wim image to a specified mount path using DISM. The
mounted image can then be modified by adding packages, drivers, or files.
Uses the Mount-WindowsImage cmdlet for the mount operation.

.PARAMETER ImagePath
Full path to the boot.wim file to mount.

.PARAMETER MountPath
Directory path where the image will be mounted. The directory must exist.

.PARAMETER Index
Image index within the WIM file to mount. Defaults to 1 (WinPE has only one image).

.EXAMPLE
Mount-MCDBootImage -ImagePath 'C:\WinPE\media\sources\boot.wim' -MountPath 'C:\WinPE\mount'

Mounts the boot.wim to the specified mount path.
#>
function Mount-MCDBootImage
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ImagePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MountPath,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]
        $Index = 1
    )

    Write-MCDLog -Message "[BootImage] Mounting boot.wim: $ImagePath" -Level Info
    Write-MCDLog -Message "[BootImage] Mount path: $MountPath (Index: $Index)" -Level Verbose

    # Validate paths
    if (-not (Test-Path -Path $ImagePath))
    {
        throw "Boot.wim not found: $ImagePath"
    }

    if (-not (Test-Path -Path $MountPath))
    {
        throw "Mount path does not exist: $MountPath"
    }

    # Check if already mounted
    $existingMount = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $MountPath }

    if ($existingMount)
    {
        Write-MCDLog -Message "[BootImage] Mount path already has a mounted image. Dismounting first." -Level Warning
        if ($PSCmdlet.ShouldProcess($MountPath, 'Dismount existing image'))
        {
            Dismount-WindowsImage -Path $MountPath -Discard -ErrorAction SilentlyContinue
        }
    }

    if ($PSCmdlet.ShouldProcess($ImagePath, 'Mount Windows image'))
    {
        try
        {
            $null = Mount-WindowsImage -ImagePath $ImagePath -Index $Index -Path $MountPath -ErrorAction Stop
            Write-MCDLog -Message "[BootImage] Successfully mounted boot.wim to: $MountPath" -Level Info
        }
        catch
        {
            Write-MCDLog -Message "[BootImage] Failed to mount boot.wim: $($_.Exception.Message)" -Level Error
            throw "Failed to mount boot.wim: $($_.Exception.Message)"
        }
    }
}
