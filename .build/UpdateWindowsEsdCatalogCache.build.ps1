task Update_WindowsEsdCatalogCache {
    $repoRoot = (Get-Location).Path

    $fn0 = Join-Path -Path $repoRoot -ChildPath 'source/Private/Core/IO/Invoke-MCDDownload.ps1'
    $fn1 = Join-Path -Path $repoRoot -ChildPath 'source/Private/OperatingSystem/ConvertFrom-MCDProductsXml.ps1'
    $fn2 = Join-Path -Path $repoRoot -ChildPath 'source/Private/OperatingSystem/Update-MCDWindowsEsdCatalogCache.ps1'

    . $fn0
    . $fn1
    . $fn2

    $outDir = Join-Path -Path $repoRoot -ChildPath 'source/Cache/Operating System'
    Update-MCDWindowsEsdCatalogCache -OutputDirectory $outDir
}
