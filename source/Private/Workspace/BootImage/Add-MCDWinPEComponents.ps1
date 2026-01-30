<#
.SYNOPSIS
Adds WinPE optional components to a mounted boot image.

.DESCRIPTION
Adds Windows PE optional components (packages) to a mounted WinPE boot image.
Handles both base packages and their language-specific counterparts. Uses
Add-WindowsPackage to add each component from the ADK WinPE_OCs folder.

.PARAMETER MountPath
Path where the WinPE boot.wim is currently mounted.

.PARAMETER Packages
Array of package names to add. Specify base package names without path or
extension (e.g., 'WinPE-WMI', 'WinPE-PowerShell'). The function automatically
adds the corresponding language pack (en-us) if it exists.

.PARAMETER WinPEOCsPath
Path to the WinPE_OCs directory in the ADK installation.

.PARAMETER Language
Language code for language packs. Defaults to 'en-us'.

.EXAMPLE
Add-MCDWinPEComponents -MountPath 'C:\WinPE\mount' -Packages @('WinPE-WMI', 'WinPE-PowerShell') -WinPEOCsPath 'C:\ADK\WinPE\amd64\WinPE_OCs'

Adds WMI and PowerShell components to the mounted WinPE image.
#>
function Add-MCDWinPEComponents
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MountPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Packages,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $WinPEOCsPath,

        [Parameter()]
        [string]
        $Language = 'en-us'
    )

    Write-MCDLog -Message "[BootImage] Adding WinPE components to mounted image: $MountPath" -Level Info
    Write-MCDLog -Message "[BootImage] Packages to add: $($Packages -join ', ')" -Level Verbose

    # Validate paths
    if (-not (Test-Path -Path $MountPath))
    {
        throw "Mount path does not exist: $MountPath"
    }

    if (-not (Test-Path -Path $WinPEOCsPath))
    {
        throw "WinPE_OCs path does not exist: $WinPEOCsPath"
    }

    $successCount = 0
    $failCount = 0

    foreach ($packageName in $Packages)
    {
        # Base package path
        $packagePath = Join-Path -Path $WinPEOCsPath -ChildPath "$packageName.cab"

        if (Test-Path -Path $packagePath)
        {
            if ($PSCmdlet.ShouldProcess($packageName, 'Add WinPE package'))
            {
                Write-MCDLog -Message "[BootImage] Adding package: $packageName" -Level Verbose
                try
                {
                    $null = Add-WindowsPackage -Path $MountPath -PackagePath $packagePath -ErrorAction Stop
                    $successCount++
                }
                catch
                {
                    Write-MCDLog -Message "[BootImage] Failed to add package $packageName : $($_.Exception.Message)" -Level Warning
                    $failCount++
                }
            }
        }
        else
        {
            Write-MCDLog -Message "[BootImage] Package not found: $packagePath" -Level Warning
            $failCount++
            continue
        }

        # Language pack path
        $langPackPath = Join-Path -Path $WinPEOCsPath -ChildPath "$Language\${packageName}_$Language.cab"

        if (Test-Path -Path $langPackPath)
        {
            if ($PSCmdlet.ShouldProcess("${packageName}_$Language", 'Add WinPE language pack'))
            {
                Write-MCDLog -Message "[BootImage] Adding language pack: ${packageName}_$Language" -Level Verbose
                try
                {
                    $null = Add-WindowsPackage -Path $MountPath -PackagePath $langPackPath -ErrorAction Stop
                }
                catch
                {
                    Write-MCDLog -Message "[BootImage] Failed to add language pack ${packageName}_$Language : $($_.Exception.Message)" -Level Warning
                }
            }
        }
    }

    Write-MCDLog -Message "[BootImage] Component installation complete. Success: $successCount, Failed: $failCount" -Level Info

    if ($failCount -gt 0 -and $successCount -eq 0)
    {
        throw "All package installations failed."
    }
}
