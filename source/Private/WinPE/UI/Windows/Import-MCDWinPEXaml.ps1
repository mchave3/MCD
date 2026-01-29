function Import-MCDWinPEXaml
{
    <#
    .SYNOPSIS
    Loads a WinPE WPF window from a XAML file.

    .DESCRIPTION
    Loads required WPF assemblies and parses the provided XAML file using
    Windows.Markup.XamlReader. Returns the resulting Window instance.

    .PARAMETER XamlPath
    Full path to the XAML file to load as a WPF window.

    .EXAMPLE
    $window = Import-MCDWinPEXaml -XamlPath 'X:\\MCD\\Xaml\\WinPE\\ProgressWindow.xaml'

    Loads the main WinPE window XAML and returns the Window object.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $XamlPath
    )

    if (-not (Test-Path -Path $XamlPath))
    {
        throw "XAML file not found: $XamlPath"
    }

    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Windows.Forms

    [xml]$xaml = Get-Content -Path $XamlPath -ErrorAction Stop
    $reader = New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml

    [Windows.Markup.XamlReader]::Load($reader)
}
