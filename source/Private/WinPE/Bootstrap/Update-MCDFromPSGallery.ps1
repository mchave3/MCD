function Update-MCDFromPSGallery
{
    <#
    .SYNOPSIS
    Updates the MCD module from PowerShell Gallery when a newer version exists.

    .DESCRIPTION
    Compares the locally available module version with the PowerShell Gallery
    version. If the Gallery version is newer, the module is installed and then
    imported again. This mirrors the version-check behavior used by OSDCloud.

    .PARAMETER ModuleName
    Name of the module to check and update from PowerShell Gallery.

    .EXAMPLE
    Update-MCDFromPSGallery -ModuleName MCD

    Updates MCD from PSGallery when the Gallery version is newer.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([bool])]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleName = 'MCD'
    )

    $installed = Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    $gallery = Find-Module -Name $ModuleName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if (-not $gallery)
    {
        Write-MCDLog -Level Verbose -Message "Unable to query PSGallery for module '$ModuleName'."
        return $false
    }

    if ($installed -and (($installed.Version -as [version]) -ge ($gallery.Version -as [version])))
    {
        Write-MCDLog -Level Verbose -Message "Installed module '$ModuleName' is up to date ($($installed.Version))."
        return $true
    }

    if (-not $PSCmdlet.ShouldProcess($ModuleName, "Install-Module to version $($gallery.Version)"))
    {
        return $false
    }

    try
    {
        Write-MCDLog -Level Info -Message "Installing '$ModuleName' $($gallery.Version) from PSGallery."
        Install-Module -Name $ModuleName -Scope AllUsers -Force -SkipPublisherCheck -ErrorAction Stop
        Import-Module -Name $ModuleName -Force -ErrorAction Stop
        return $true
    }
    catch
    {
        Write-MCDLog -Level Warning -Message "Failed to update module '$ModuleName' from PSGallery: $($_.Exception.Message)"
        return $false
    }
}
