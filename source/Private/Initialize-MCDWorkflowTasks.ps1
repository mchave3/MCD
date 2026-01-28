function Initialize-MCDWorkflowTasks {
    <#
    .SYNOPSIS
    Initializes and loads MCD workflow tasks from module or USB profiles.

    .DESCRIPTION
    Loads workflow JSON files from either the module's built-in workflow directory
    or from USB profile directories. Returns a sorted array of workflow objects
    that can be passed to Invoke-MCDWorkflow. Supports architecture filtering
    and profile name selection.

    .PARAMETER ProfileName
    Name of the USB profile to load workflows from. If not specified,
    loads only built-in workflows.

    .PARAMETER Architecture
    Target architecture to filter workflows for. Valid values: 'amd64' or 'arm64'.
    Defaults to current system architecture.

    .EXAMPLE
    $workflows = Initialize-MCDWorkflowTasks

    Loads all built-in workflows for current architecture.

    .EXAMPLE
    $workflows = Initialize-MCDWorkflowTasks -ProfileName 'MyCustomProfile'

    Loads workflows from USB profile 'MyCustomProfile' and built-in workflows.

    .EXAMPLE
    $workflows = Initialize-MCDWorkflowTasks -Architecture 'amd64'

    Loads only amd64 workflows from built-in directory.

    .OUTPUTS
    System.Management.Automation.PSCustomObject[]
    Array of workflow objects with id, name, description, version, author, amd64, arm64, default, and steps.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ProfileName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('amd64', 'arm64')]
        [System.String]
        $Architecture = $env:PROCESSOR_ARCHITECTURE
    )

    #=================================================
    $Error.Clear()
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Start"
    $ModuleName = $MyInvocation.MyCommand.Module.Name
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] ModuleName: $ModuleName"
    $ModuleBase = $MyInvocation.MyCommand.Module.ModuleBase
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] ModuleBase: $ModuleBase"
    $ModuleVersion = $MyInvocation.MyCommand.Module.Version
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] ModuleVersion: $ModuleVersion"
    #=================================================

    $workflowTasks = @()

    #=================================================
    # Load built-in workflows from module
    #=================================================
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Loading built-in workflows..."

    $builtInWorkflowsPath = Join-Path -Path $ModuleBase -ChildPath 'Workflows'

    if (Test-Path -Path $builtInWorkflowsPath) {
        try {
            $builtInWorkflowFiles = Get-ChildItem -Path $builtInWorkflowsPath -Filter '*.json' -ErrorAction Stop

            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Found $($builtInWorkflowFiles.Count) built-in workflow file(s)"

            foreach ($file in $builtInWorkflowFiles) {
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Loading built-in workflow: $($file.FullName)"

                try {
                    $workflow = Get-Content -Path $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                    $workflowTasks += $workflow
                }
                catch {
                    Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to parse workflow file '$($file.FullName)': $_"
                }
            }
        }
        catch {
            Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to load built-in workflows: $_"
        }
    }
    else {
        Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Built-in workflows directory does not exist: $builtInWorkflowsPath"
    }

    #=================================================
    # Load custom workflows from USB profiles
    #=================================================
    if ($ProfileName) {
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Loading custom workflows from profile: $ProfileName"

        $usbVolume = Get-MCDExternalVolume
        if ($usbVolume) {
            $profileRoot = Join-Path -Path $usbVolume -ChildPath "MCD\Profiles\$ProfileName"
            $profileWorkflowPath = Join-Path -Path $profileRoot -ChildPath 'workflow.json'

            if (Test-Path -Path $profileWorkflowPath) {
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Loading custom workflow: $profileWorkflowPath"

                try {
                    $customWorkflow = Get-Content -Path $profileWorkflowPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                    $workflowTasks += $customWorkflow
                }
                catch {
                    Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to parse custom workflow file '$profileWorkflowPath': $_"
                }
            }
            else {
                Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Custom workflow file not found: $profileWorkflowPath"
            }
        }
        else {
            Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] USB volume not found for profile: $ProfileName"
        }
    }

    #=================================================
    # Filter by architecture
    #=================================================
    if ($Architecture -eq 'amd64') {
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Filtering workflows for amd64 architecture"
        $workflowTasks = $workflowTasks | Where-Object { $_.amd64 -eq $true }
    }
    elseif ($Architecture -eq 'arm64') {
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Filtering workflows for arm64 architecture"
        $workflowTasks = $workflowTasks | Where-Object { $_.arm64 -eq $true }
    }

    if ($workflowTasks.Count -eq 0) {
        Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] No workflows found for architecture: $Architecture"
        return @()
    }

    #=================================================
    # Validate step availability (warning only, don't fail)
    #=================================================
    foreach ($workflow in $workflowTasks) {
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Validating workflow: $($workflow.name)"

        foreach ($step in $workflow.steps) {
            $stepFunctionPath = "function:\$($step.command)"

            if (-not (Test-Path -Path $stepFunctionPath)) {
                Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Workflow '$($workflow.name)' step '$($step.name)' references missing command: $($step.command)"
            }
        }
    }

    #=================================================
    # Sort workflows (default first, then by name)
    #=================================================
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Sorting workflows (default first, then by name)"

    $workflowTasks = $workflowTasks | Sort-Object -Property @{Expression = 'default'; Descending = $true }, @{Expression = 'name'; Descending = $false }

    #=================================================
    # Return workflows
    #=================================================
    $Message = "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Loaded $($workflowTasks.Count) workflow(s)"
    Write-Verbose -Message $Message
    Write-Debug -Message $Message

    Write-Output $workflowTasks
    #=================================================
    # End of function
    #=================================================
}
