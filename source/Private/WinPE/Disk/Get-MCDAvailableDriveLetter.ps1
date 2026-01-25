function Get-MCDAvailableDriveLetter
{
    <#
    .SYNOPSIS
    Returns an available drive letter for use during WinPE deployment.

    .DESCRIPTION
    Determines an unused drive letter by inspecting existing PowerShell drives.
    This helper is used when creating temporary WinPE drive letters (for example
    System=S and Windows=W) while avoiding collisions with already-mounted
    volumes.

    .PARAMETER PreferredLetters
    Ordered list of preferred drive letters to try first.

    .PARAMETER FallbackLetters
    Ordered list of fallback drive letters to try if none of the preferred
    letters are available.

    .PARAMETER ExcludeLetters
    One or more letters to treat as unavailable (reserved by the caller).

    .EXAMPLE
    Get-MCDAvailableDriveLetter -PreferredLetters @('S','W')

    Returns the first available letter from the preferred list.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $PreferredLetters = @('S', 'W', 'R', 'T'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $FallbackLetters = @('D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'U', 'V', 'X', 'Y', 'Z'),

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $ExcludeLetters = @()
    )

    $used = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Name.ToUpperInvariant() })
    if ($ExcludeLetters)
    {
        foreach ($exclude in @($ExcludeLetters))
        {
            $excludeValue = [string]$exclude
            if ([string]::IsNullOrWhiteSpace($excludeValue))
            {
                continue
            }
            $excludeCandidate = $excludeValue.Trim().Substring(0, 1).ToUpperInvariant()
            if ($excludeCandidate -match '^[A-Z]$')
            {
                $used += $excludeCandidate
            }
        }
    }

    $candidates = @()
    if ($PreferredLetters)
    {
        $candidates += @($PreferredLetters)
    }
    if ($FallbackLetters)
    {
        $candidates += @($FallbackLetters)
    }

    foreach ($letter in $candidates)
    {
        $value = [string]$letter
        if ([string]::IsNullOrWhiteSpace($value))
        {
            continue
        }

        $candidate = $value.Trim().Substring(0, 1).ToUpperInvariant()
        if ($candidate -notmatch '^[A-Z]$')
        {
            continue
        }

        if ($candidate -notin $used)
        {
            return $candidate
        }
    }

    throw 'No available drive letter could be determined.'
}
