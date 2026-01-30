<#
.SYNOPSIS
Represents an MCD workflow with metadata and steps for the editor.

.DESCRIPTION
The WorkflowEditorModel class represents a complete workflow definition
including metadata (id, name, version, author) and an ordered list of steps.
Supports serialization to JSON matching the workflow schema.
#>
class WorkflowEditorModel
{
    [string]$Id
    [string]$Name
    [string]$Description
    [string]$Version = '1.0.0'
    [string]$Author
    [bool]$Amd64 = $true
    [bool]$Arm64 = $true
    [bool]$Default = $false
    [System.Collections.Generic.List[StepModel]]$Steps

    WorkflowEditorModel()
    {
        $this.Id = [guid]::NewGuid().ToString()
        $this.Steps = [System.Collections.Generic.List[StepModel]]::new()
    }

    WorkflowEditorModel([string]$name)
    {
        if ([string]::IsNullOrWhiteSpace($name))
        {
            throw [System.ArgumentException]::new('Name cannot be null or empty.', 'name')
        }

        $this.Id = [guid]::NewGuid().ToString()
        $this.Name = $name
        $this.Steps = [System.Collections.Generic.List[StepModel]]::new()
    }

    [void]Validate()
    {
        if ([string]::IsNullOrWhiteSpace($this.Id))
        {
            throw [System.InvalidOperationException]::new('Id is required.')
        }
        if ([string]::IsNullOrWhiteSpace($this.Name))
        {
            throw [System.InvalidOperationException]::new('Name is required.')
        }
        if (-not $this.Amd64 -and -not $this.Arm64)
        {
            throw [System.InvalidOperationException]::new('At least one architecture (amd64 or arm64) must be enabled.')
        }
        foreach ($step in $this.Steps)
        {
            $step.Validate()
        }
    }

    [void]AddStep([StepModel]$step)
    {
        if ($null -eq $step)
        {
            throw [System.ArgumentNullException]::new('step')
        }
        $this.Steps.Add($step)
    }

    [void]RemoveStep([int]$index)
    {
        if ($index -lt 0 -or $index -ge $this.Steps.Count)
        {
            throw [System.ArgumentOutOfRangeException]::new('index')
        }
        $this.Steps.RemoveAt($index)
    }

    [void]MoveStep([int]$fromIndex, [int]$toIndex)
    {
        if ($fromIndex -lt 0 -or $fromIndex -ge $this.Steps.Count)
        {
            throw [System.ArgumentOutOfRangeException]::new('fromIndex')
        }
        if ($toIndex -lt 0 -or $toIndex -ge $this.Steps.Count)
        {
            throw [System.ArgumentOutOfRangeException]::new('toIndex')
        }
        $step = $this.Steps[$fromIndex]
        $this.Steps.RemoveAt($fromIndex)
        $this.Steps.Insert($toIndex, $step)
    }

    [hashtable]ToHashtable()
    {
        $stepsArray = @()
        foreach ($step in $this.Steps)
        {
            $stepsArray += $step.ToHashtable()
        }

        return @{
            id          = $this.Id
            name        = $this.Name
            description = $this.Description
            version     = $this.Version
            author      = $this.Author
            amd64       = $this.Amd64
            arm64       = $this.Arm64
            default     = $this.Default
            steps       = $stepsArray
        }
    }

    [string]ToJson()
    {
        return $this.ToHashtable() | ConvertTo-Json -Depth 10
    }

    static [WorkflowEditorModel]FromHashtable([hashtable]$data)
    {
        $workflow = [WorkflowEditorModel]::new()
        $workflow.Id = if ($data.id) { $data.id } else { [guid]::NewGuid().ToString() }
        $workflow.Name = $data.name
        $workflow.Description = $data.description
        $workflow.Version = if ($data.version) { $data.version } else { '1.0.0' }
        $workflow.Author = $data.author
        $workflow.Amd64 = if ($null -ne $data.amd64) { $data.amd64 } else { $true }
        $workflow.Arm64 = if ($null -ne $data.arm64) { $data.arm64 } else { $true }
        $workflow.Default = $data.default -eq $true

        if ($data.steps)
        {
            foreach ($stepData in $data.steps)
            {
                if ($stepData -is [hashtable])
                {
                    $workflow.Steps.Add([StepModel]::FromHashtable($stepData))
                }
                elseif ($stepData.PSObject)
                {
                    $stepHash = @{}
                    foreach ($prop in $stepData.PSObject.Properties)
                    {
                        $stepHash[$prop.Name] = $prop.Value
                    }
                    $workflow.Steps.Add([StepModel]::FromHashtable($stepHash))
                }
            }
        }

        return $workflow
    }

    static [WorkflowEditorModel]FromJson([string]$json)
    {
        $data = $json | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
        if (-not $data)
        {
            $obj = $json | ConvertFrom-Json
            $data = @{}
            foreach ($prop in $obj.PSObject.Properties)
            {
                $data[$prop.Name] = $prop.Value
            }
        }
        return [WorkflowEditorModel]::FromHashtable($data)
    }
}
