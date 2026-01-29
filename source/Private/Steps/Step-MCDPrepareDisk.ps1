<#
.SYNOPSIS
Prepares the target disk for Windows deployment.

.DESCRIPTION
Clears and initializes the target disk with a UEFI/GPT partition layout suitable
for Windows deployment. Reads the target disk and disk policy from the global
workflow context. If no target disk is specified or destructive actions are
disabled, the step completes without making changes.

The partition layout created:
- EFI System Partition (FAT32, 260MB)
- Microsoft Reserved Partition (MSR, 16MB)
- Windows partition (NTFS, remaining space)

.EXAMPLE
Step-MCDPrepareDisk

Prepares the target disk from the workflow context selection.

.NOTES
Uses $global:MCDWorkflowContext for selection and disk policy. Delegates to
Initialize-MCDTargetDisk for the actual disk operations.
#>
function Step-MCDPrepareDisk
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'OSDCloud pattern: workflow context shared via globals')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Determine logs root
    $logsRoot = $global:MCDWorkflowContext.LogsRoot
    if (-not $logsRoot)
    {
        if ($global:MCDWorkflowIsWinPE)
        {
            $logsRoot = 'X:\MCD\Logs'
        }
        else
        {
            $logsRoot = 'C:\Windows\Temp\MCD\Logs'
        }
    }

    # Ensure logs directory exists
    if (-not (Test-Path -Path $logsRoot))
    {
        $null = New-Item -Path $logsRoot -ItemType Directory -Force
    }

    # Build transcript path
    $stepIndex = $global:MCDWorkflowCurrentStepIndex
    $functionName = $MyInvocation.MyCommand.Name -replace '^Step-', ''
    $transcriptPath = Join-Path -Path $logsRoot -ChildPath ('{0:D2}_{1}.log' -f $stepIndex, $functionName)

    try
    {
        Start-Transcript -Path $transcriptPath -Force | Out-Null

        Write-MCDLog -Level Info -Message 'Preparing target disk...'

        # Get selection from workflow context
        $selection = $null
        if ($global:MCDWorkflowContext.CurrentStep.parameters.Selection)
        {
            $selection = $global:MCDWorkflowContext.CurrentStep.parameters.Selection
        }
        elseif ($global:MCDWorkflowContext.Selection)
        {
            $selection = $global:MCDWorkflowContext.Selection
        }

        if (-not $selection)
        {
            Write-MCDLog -Level Verbose -Message 'No selection in workflow context; skipping disk preparation.'
            return $true
        }

        if (-not $selection.TargetDisk)
        {
            Write-MCDLog -Level Verbose -Message 'No TargetDisk provided; skipping disk preparation.'
            return $true
        }

        $diskNumber = $selection.TargetDisk.DiskNumber
        if ($null -eq $diskNumber)
        {
            Write-MCDLog -Level Verbose -Message 'TargetDisk does not include DiskNumber; skipping disk preparation.'
            return $true
        }

        # Get disk policy
        $diskPolicy = $null
        if ($selection.WinPEConfig -and $selection.WinPEConfig.DiskPolicy)
        {
            $diskPolicy = $selection.WinPEConfig.DiskPolicy
        }
        if (-not $diskPolicy)
        {
            $diskPolicy = [pscustomobject]@{ AllowDestructiveActions = $false }
        }

        if (-not [bool]$diskPolicy.AllowDestructiveActions)
        {
            Write-MCDLog -Level Warning -Message 'DiskPolicy.AllowDestructiveActions is false; skipping disk preparation.'
            return $true
        }

        Write-MCDLog -Level Info -Message ("Initializing target disk {0} with UEFI/GPT layout..." -f $diskNumber)

        $layout = Initialize-MCDTargetDisk -DiskNumber $diskNumber -DiskPolicy $diskPolicy

        # Store layout in selection for later steps
        if ($selection -and $layout)
        {
            $selection | Add-Member -NotePropertyName DiskLayout -NotePropertyValue $layout -Force
            Write-MCDLog -Level Info -Message ("Disk prepared: SystemDrive={0}, WindowsDrive={1}" -f $layout.SystemDriveLetter, $layout.WindowsDriveLetter)
        }

        Write-MCDLog -Level Info -Message 'Disk preparation completed successfully.'
        return $true
    }
    finally
    {
        Stop-Transcript | Out-Null
    }
}
