function Test-MCDPrerequisite
{
    <#
      .SYNOPSIS
      Checks if the required prerequisites for MCD operations are met.

      .DESCRIPTION
      This function validates that the system meets the requirements for running MCD
      operations. It checks for administrator privileges, PowerShell version, and
      detects the execution environment (Workspace vs WinPE).

      .EXAMPLE
      if (Test-MCDPrerequisite) { Start-MCDWorkspace }

      Checks prerequisites before starting the workspace.

      .EXAMPLE
      Test-MCDPrerequisite -Mode WinPE -Verbose

      Checks WinPE-specific prerequisites with verbose output.

      .EXAMPLE
      Test-MCDPrerequisite -SkipAdminCheck

      Checks prerequisites without requiring administrator privileges.

      .PARAMETER Mode
      The execution mode to check for. Valid values are Workspace, WinPE, and Auto.
      Auto mode detects the environment automatically. Defaults to Auto.

      .PARAMETER SkipAdminCheck
      If specified, skips the administrator privileges check.

      .OUTPUTS
      [bool] Returns $true if all prerequisites are met, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter()]
        [ValidateSet('Workspace', 'WinPE', 'Auto')]
        [string]
        $Mode = 'Auto',

        [Parameter()]
        [switch]
        $SkipAdminCheck
    )

    process
    {
        $allPassed = $true

        # Check PowerShell version (minimum 5.1)
        Write-Verbose -Message "Checking PowerShell version: $($PSVersionTable.PSVersion)"
        if ($PSVersionTable.PSVersion.Major -lt 5 -or
            ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1))
        {
            Write-Warning -Message 'MCD requires PowerShell 5.1 or higher.'
            $allPassed = $false
        }
        else
        {
            Write-Verbose -Message 'PowerShell version check passed.'
        }

        # Check administrator privileges unless skipped
        if (-not $SkipAdminCheck)
        {
            Write-Verbose -Message 'Checking administrator privileges...'
            $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $currentIdentity
            $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            if (-not $isAdmin)
            {
                Write-Warning -Message 'MCD requires administrator privileges. Please run as administrator.'
                $allPassed = $false
            }
            else
            {
                Write-Verbose -Message 'Administrator privileges check passed.'
            }
        }

        # Detect execution environment
        $detectedMode = 'Workspace'
        $isWinPE = $false

        # Check for WinPE indicators
        if ($env:SystemDrive -eq 'X:')
        {
            $isWinPE = $true
            $detectedMode = 'WinPE'
            Write-Verbose -Message 'Detected WinPE environment (X: system drive).'
        }
        elseif (Test-Path -Path 'X:\Windows\System32\winpeshl.ini' -PathType Leaf)
        {
            $isWinPE = $true
            $detectedMode = 'WinPE'
            Write-Verbose -Message 'Detected WinPE environment (winpeshl.ini present).'
        }
        else
        {
            Write-Verbose -Message 'Detected full Windows environment.'
        }

        # Validate mode if explicitly specified
        if ($Mode -ne 'Auto')
        {
            if ($Mode -eq 'WinPE' -and -not $isWinPE)
            {
                Write-Warning -Message 'WinPE mode requested but not running in WinPE environment.'
                $allPassed = $false
            }
            elseif ($Mode -eq 'Workspace' -and $isWinPE)
            {
                Write-Warning -Message 'Workspace mode requested but running in WinPE environment.'
                $allPassed = $false
            }
        }

        # Check for required Windows features/tools based on mode
        $effectiveMode = if ($Mode -eq 'Auto') { $detectedMode } else { $Mode }

        if ($effectiveMode -eq 'Workspace')
        {
            # Check for Hyper-V cmdlets availability (optional for workspace)
            # This is informational only, not a hard requirement for MVP
            $hasHyperV = Get-Command -Name 'Get-VM' -ErrorAction SilentlyContinue
            if ($hasHyperV)
            {
                Write-Verbose -Message 'Hyper-V cmdlets available.'
            }
            else
            {
                Write-Verbose -Message 'Hyper-V cmdlets not available (optional feature).'
            }
        }

        Write-Verbose -Message "Prerequisites check result: $allPassed"
        return $allPassed
    }
}
