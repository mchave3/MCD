function Step-MCDPrepareEnvironment {
    <#
    .SYNOPSIS
    Prepares the deployment environment.

    .DESCRIPTION
    Sets up the environment for Windows deployment by ensuring required
    directories exist and loading any necessary PowerShell modules. This step
    runs before the actual deployment to ensure all prerequisites are met.

    .PARAMETER WorkspacePath
    Path to the MCD workspace (optional, defaults to context value).

    .EXAMPLE
    Step-MCDPrepareEnvironment

    Prepares the deployment environment.

    .OUTPUTS
    System.Boolean
    Returns $true on success.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $WorkspacePath
    )

    process {
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Preparing deployment environment..."

        try {
            # Create required directories
            $requiredDirectories = @(
                "C:\Windows\Temp\MCD",
                "C:\Windows\Temp\MCD\Steps",
                "C:\Windows\Temp\MCD\Logs"
                "C:\Windows\Temp\MCD\Workspace"
            )

            foreach ($dir in $requiredDirectories) {
                if (-not (Test-Path -Path $dir)) {
                    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Creating directory: $dir"
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
            }

            # Copy workspace to Windows\Temp\MCD\Workspace if provided
            if ($WorkspacePath -and (Test-Path -Path $WorkspacePath)) {
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Copying workspace from: $WorkspacePath"
                Copy-Item -Path $WorkspacePath -Destination "C:\Windows\Temp\MCD\Workspace" -Recurse -Force
            }

            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Environment preparation completed successfully"
            Write-MCDLog -Level Information -Message "Deployment environment prepared successfully"
            return $true
        }
        catch {
            Write-Error -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to prepare environment: $_"
            Write-MCDLog -Level Error -Message "Environment preparation failed: $_"
            throw
        }
    }
}
