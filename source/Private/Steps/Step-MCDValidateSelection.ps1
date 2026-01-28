function Step-MCDValidateSelection {
    <#
    .SYNOPSIS
    Validates the wizard selection before deployment.

    .DESCRIPTION
    Checks that the selection object contains required properties (OperatingSystem,
    ComputerLanguage, WindowsImage, DriverPack) and that they are not null or empty.
    This is the first step in the deployment workflow.

    .PARAMETER Selection
    The selection object returned by Start-MCDWizard.

    .EXAMPLE
    $selection = Start-MCDWizard
    Step-MCDValidateSelection -Selection $selection

    Validates the wizard selection before deployment.

    .OUTPUTS
    System.Boolean
    Returns $true if validation succeeds, $false otherwise.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $Selection
    )

    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Validating wizard selection..."

    $isValid = $true

    # Validate OperatingSystem
    if (-not $Selection.OperatingSystem) {
        Write-Error -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] OperatingSystem is null or empty"
        $isValid = $false
    }

    # Validate ComputerLanguage
    if (-not $Selection.ComputerLanguage) {
        Write-Error -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] ComputerLanguage is null or empty"
        $isValid = $false
    }

    # Validate WindowsImage
    if (-not $Selection.WindowsImage) {
        Write-Error -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] WindowsImage is null or empty"
        $isValid = $false
    }

    # Validate DriverPack (optional, can be empty)
    if (-not $Selection.DriverPack) {
        Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] DriverPack is null or empty (optional)"
    }

    Write-MCDLog -Level Information -Message "Selection validation completed: $($isValid)"

    Write-Output -InputObject $isValid
}
