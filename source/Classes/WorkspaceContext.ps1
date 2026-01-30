<#
.SYNOPSIS
Represents the workspace context for MCD operations.

.DESCRIPTION
The WorkspaceContext class holds the current workspace state including paths,
configuration, and runtime information for the MCD workspace operations.
#>
class WorkspaceContext
{
    [string]$ProfileName
    [string]$WorkspacePath
    [string]$ProfilesPath
    [string]$CachePath
    [string]$LogsPath
    [hashtable]$Configuration
    [datetime]$CreatedAt
    [bool]$IsInitialized

    WorkspaceContext()
    {
        $this.Configuration = @{}
        $this.CreatedAt = Get-Date
        $this.IsInitialized = $false
    }

    WorkspaceContext([string]$profileName, [string]$workspacePath)
    {
        if ([string]::IsNullOrWhiteSpace($profileName))
        {
            throw [System.ArgumentException]::new('ProfileName cannot be null or empty.', 'profileName')
        }
        if ([string]::IsNullOrWhiteSpace($workspacePath))
        {
            throw [System.ArgumentException]::new('WorkspacePath cannot be null or empty.', 'workspacePath')
        }

        $this.ProfileName = $profileName
        $this.WorkspacePath = $workspacePath
        $this.ProfilesPath = Join-Path -Path $workspacePath -ChildPath 'Profiles'
        $this.CachePath = Join-Path -Path $workspacePath -ChildPath 'Cache'
        $this.LogsPath = Join-Path -Path $workspacePath -ChildPath 'Logs'
        $this.Configuration = @{}
        $this.CreatedAt = Get-Date
        $this.IsInitialized = $true
    }

    [void]Validate()
    {
        if ([string]::IsNullOrWhiteSpace($this.ProfileName))
        {
            throw [System.InvalidOperationException]::new('ProfileName is required.')
        }
        if ([string]::IsNullOrWhiteSpace($this.WorkspacePath))
        {
            throw [System.InvalidOperationException]::new('WorkspacePath is required.')
        }
    }

    [string]ToJson()
    {
        $obj = @{
            profileName   = $this.ProfileName
            workspacePath = $this.WorkspacePath
            profilesPath  = $this.ProfilesPath
            cachePath     = $this.CachePath
            logsPath      = $this.LogsPath
            configuration = $this.Configuration
            createdAt     = $this.CreatedAt.ToString('o')
            isInitialized = $this.IsInitialized
        }
        return $obj | ConvertTo-Json -Depth 10
    }

    static [WorkspaceContext]FromJson([string]$json)
    {
        $obj = $json | ConvertFrom-Json
        $context = [WorkspaceContext]::new()
        $context.ProfileName = $obj.profileName
        $context.WorkspacePath = $obj.workspacePath
        $context.ProfilesPath = $obj.profilesPath
        $context.CachePath = $obj.cachePath
        $context.LogsPath = $obj.logsPath
        if ($obj.configuration)
        {
            $context.Configuration = @{}
            foreach ($prop in $obj.configuration.PSObject.Properties)
            {
                $context.Configuration[$prop.Name] = $prop.Value
            }
        }
        if ($obj.createdAt)
        {
            if ($obj.createdAt -is [datetime])
            {
                $context.CreatedAt = $obj.createdAt
            }
            else
            {
                $context.CreatedAt = [datetime]::Parse($obj.createdAt, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
            }
        }
        $context.IsInitialized = $obj.isInitialized
        return $context
    }
}
