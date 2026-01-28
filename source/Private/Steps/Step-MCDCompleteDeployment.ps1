function Step-MCDCompleteDeployment {
    <#
    .SYNOPSIS
    Completes the deployment process.

    .DESCRIPTION
    Final step in the workflow that performs cleanup operations and marks
    the deployment as complete. Writes a completion message to the log
    and displays final status.

    .EXAMPLE
    Step-MCDCompleteDeployment

    Completes the deployment process.

    .OUTPUTS
    System.Boolean
    Returns $true on success.
    #>
    [CmdletBinding()]
    param ()

    process {
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Completing deployment..."

        try {
            # Update global context with completion status
            if ($global:MCDWorkflowContext) {
                $global:MCDWorkflowContext['Status'] = 'Completed'
                $global:MCDWorkflowContext['EndTime'] = [datetime](Get-Date)
            }

            Write-Host -ForegroundColor Green "Deployment completed successfully!"
            Write-MCDLog -Level Information -Message "Deployment completed successfully"

            return $true
        }
        catch {
            Write-Error -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to complete deployment: $_"
            Write-MCDLog -Level Error -Message "Deployment completion failed: $_"
            throw
        }
    }
}
