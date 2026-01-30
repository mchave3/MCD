<#
.SYNOPSIS
Represents the retry configuration for a workflow step.

.DESCRIPTION
The StepRetryConfig class defines retry behavior when a step fails, including
maximum attempts and delay between retries.
#>
class StepRetryConfig
{
    [bool]$Enabled = $false
    [int]$MaxAttempts = 3
    [int]$RetryDelay = 5

    StepRetryConfig() { }

    StepRetryConfig([bool]$enabled, [int]$maxAttempts, [int]$retryDelay)
    {
        $this.Enabled = $enabled
        $this.MaxAttempts = $maxAttempts
        $this.RetryDelay = $retryDelay
    }

    [hashtable]ToHashtable()
    {
        return @{
            enabled     = $this.Enabled
            maxAttempts = $this.MaxAttempts
            retryDelay  = $this.RetryDelay
        }
    }
}

<#
.SYNOPSIS
Represents the execution rules for a workflow step.

.DESCRIPTION
The StepRules class defines when and how a step should execute, including
skip conditions, environment requirements, architecture filtering, and error handling.
#>
class StepRules
{
    [bool]$Skip = $false
    [bool]$RunInFullOS = $false
    [bool]$RunInWinPE = $true
    [string[]]$Architecture = @('amd64', 'arm64')
    [StepRetryConfig]$Retry
    [bool]$ContinueOnError = $false

    StepRules()
    {
        $this.Retry = [StepRetryConfig]::new()
    }

    [void]Validate()
    {
        if ($this.Architecture.Count -eq 0)
        {
            throw [System.InvalidOperationException]::new('Architecture array cannot be empty.')
        }
        foreach ($arch in $this.Architecture)
        {
            if ($arch -notin @('amd64', 'arm64'))
            {
                throw [System.InvalidOperationException]::new("Invalid architecture: '$arch'. Must be 'amd64' or 'arm64'.")
            }
        }
    }

    [hashtable]ToHashtable()
    {
        return @{
            skip            = $this.Skip
            runinfullos     = $this.RunInFullOS
            runinwinpe      = $this.RunInWinPE
            architecture    = $this.Architecture
            retry           = $this.Retry.ToHashtable()
            continueOnError = $this.ContinueOnError
        }
    }
}

<#
.SYNOPSIS
Represents a workflow step in the MCD workflow system.

.DESCRIPTION
The StepModel class represents a single step in a workflow. It supports both
positional arguments (args array) and named parameters (parameters hashtable)
consistent with the workflow schema.
#>
class StepModel
{
    [string]$Name
    [string]$Description
    [string]$Command
    [object[]]$Args = @()
    [hashtable]$Parameters = @{}
    [StepRules]$Rules

    StepModel()
    {
        $this.Rules = [StepRules]::new()
    }

    StepModel([string]$name, [string]$command)
    {
        if ([string]::IsNullOrWhiteSpace($name))
        {
            throw [System.ArgumentException]::new('Name cannot be null or empty.', 'name')
        }
        if ([string]::IsNullOrWhiteSpace($command))
        {
            throw [System.ArgumentException]::new('Command cannot be null or empty.', 'command')
        }

        $this.Name = $name
        $this.Command = $command
        $this.Rules = [StepRules]::new()
    }

    [void]Validate()
    {
        if ([string]::IsNullOrWhiteSpace($this.Name))
        {
            throw [System.InvalidOperationException]::new('Name is required.')
        }
        if ([string]::IsNullOrWhiteSpace($this.Command))
        {
            throw [System.InvalidOperationException]::new('Command is required.')
        }
        $this.Rules.Validate()
    }

    [hashtable]ToHashtable()
    {
        return @{
            name        = $this.Name
            description = $this.Description
            command     = $this.Command
            args        = $this.Args
            parameters  = $this.Parameters
            rules       = $this.Rules.ToHashtable()
        }
    }

    [string]ToJson()
    {
        return $this.ToHashtable() | ConvertTo-Json -Depth 10
    }

    static [StepModel]FromHashtable([hashtable]$data)
    {
        $step = [StepModel]::new()
        $step.Name = $data.name
        $step.Description = $data.description
        $step.Command = $data.command

        if ($data.args -and $data.args -is [System.Array])
        {
            $step.Args = $data.args
        }

        if ($data.parameters)
        {
            if ($data.parameters -is [hashtable])
            {
                $step.Parameters = $data.parameters
            }
            elseif ($data.parameters -is [System.Collections.IDictionary])
            {
                $step.Parameters = @{} + $data.parameters
            }
            elseif ($data.parameters.PSObject)
            {
                $step.Parameters = @{}
                foreach ($prop in $data.parameters.PSObject.Properties)
                {
                    $step.Parameters[$prop.Name] = $prop.Value
                }
            }
        }

        if ($data.rules)
        {
            $rulesData = $data.rules
            $step.Rules.Skip = $rulesData.skip -eq $true
            $step.Rules.RunInFullOS = $rulesData.runinfullos -eq $true
            $step.Rules.RunInWinPE = if ($null -ne $rulesData.runinwinpe) { $rulesData.runinwinpe } else { $true }
            if ($rulesData.architecture -and $rulesData.architecture.Count -gt 0)
            {
                $step.Rules.Architecture = @($rulesData.architecture)
            }
            $step.Rules.ContinueOnError = $rulesData.continueOnError -eq $true

            if ($rulesData.retry)
            {
                $step.Rules.Retry.Enabled = $rulesData.retry.enabled -eq $true
                if ($null -ne $rulesData.retry.maxAttempts)
                {
                    $step.Rules.Retry.MaxAttempts = $rulesData.retry.maxAttempts
                }
                if ($null -ne $rulesData.retry.retryDelay)
                {
                    $step.Rules.Retry.RetryDelay = $rulesData.retry.retryDelay
                }
            }
        }

        return $step
    }

    static [StepModel]FromJson([string]$json)
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
        return [StepModel]::FromHashtable($data)
    }
}
