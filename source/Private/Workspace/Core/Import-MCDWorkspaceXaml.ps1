<#
.SYNOPSIS
Loads a Workspace WPF window from a XAML file.

.DESCRIPTION
Loads required WPF assemblies (PresentationCore, PresentationFramework, WindowsBase,
System.Windows.Forms) and parses the provided XAML file using Windows.Markup.XamlReader.
Returns the resulting Window instance. Logs operation start and completion using Write-MCDLog.

.PARAMETER XamlPath
Full path to the XAML file to load as a WPF window.

.EXAMPLE
$window = Import-MCDWorkspaceXaml -XamlPath 'C:\MCD\Xaml\Workspace\MainWindow.xaml'

Loads the Workspace main window XAML and returns the Window object.
#>
function Import-MCDWorkspaceXaml
{
    [CmdletBinding()]
    [OutputType([System.Windows.Window])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $XamlPath
    )

    Write-MCDLog -Message "Loading XAML from: $XamlPath" -Level 'Verbose'

    if (-not (Test-Path -Path $XamlPath))
    {
        throw "XAML file not found: $XamlPath"
    }

    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Windows.Forms

    [xml]$xaml = Get-Content -Path $XamlPath -ErrorAction Stop
    $reader = New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml

    $window = [Windows.Markup.XamlReader]::Load($reader)

    Write-MCDLog -Message 'XAML loaded successfully' -Level 'Verbose'

    return $window
}
