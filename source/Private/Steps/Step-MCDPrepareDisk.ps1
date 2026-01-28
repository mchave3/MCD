function Step-MCDPrepareDisk {
    <#
    .SYNOPSIS
    Prepares the target disk for Windows deployment.

    .DESCRIPTION
    Prepares the target disk by clearing it and creating a new partition layout
    suitable for Windows installation. This step migrates the disk preparation
    logic from Initialize-MCDTargetDisk but runs as a standalone workflow step
    with proper error handling and logging.

    .PARAMETER DiskNumber
    Disk number to prepare (default: 0).

    .PARAMETER DiskPolicy
    Disk policy to apply for partitioning. Valid values: 'Clean', 'New'.

    .EXAMPLE
    Step-MCDPrepareDisk -DiskNumber 0 -DiskPolicy Clean

    Prepares disk 0 with a clean layout for deployment.

    .OUTPUTS
    System.Boolean
    Returns $true on success.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 99)]
        [int]
        $DiskNumber = 0,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Clean', 'New')]
        [string]
        $DiskPolicy = 'Clean'
    )

    process {
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Preparing disk $DiskNumber with policy: $DiskPolicy"

        try {
            if ($DiskPolicy -eq 'Clean') {
                # Clear disk
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Clearing disk $DiskNumber"
                Clear-Disk -Number $DiskNumber -RemoveData -ErrorAction Stop
            }
            elseif ($DiskPolicy -eq 'New') {
                # New partition layout
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Creating new partition layout on disk $DiskNumber"
                Initialize-Disk -Number $DiskNumber -ErrorAction Stop
            }
            else {
                throw "Invalid DiskPolicy: $DiskPolicy"
            }

            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Disk preparation completed successfully"
            Write-MCDLog -Level Information -Message "Disk $DiskNumber prepared successfully"
            return $true
        }
        catch {
            Write-Error -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to prepare disk $DiskNumber: $_"
            Write-MCDLog -Level Error -Message "Disk preparation failed: $_"
            throw
        }
    }
}
