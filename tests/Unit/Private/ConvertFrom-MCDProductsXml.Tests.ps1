BeforeAll {
    $projectRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\..')).Path

    . (Join-Path -Path $projectRoot -ChildPath 'source\Private\OperatingSystem\ConvertFrom-MCDProductsXml.ps1')
}

Describe 'ConvertFrom-MCDProductsXml' {
    It 'Extracts only .esd entries and preserves deterministic ordering' {
        $fixture = Join-Path -Path $projectRoot -ChildPath 'tests\TestData\products.sample.xml'
        [xml]$x = Get-Content -Path $fixture -Raw

        $items = ConvertFrom-MCDProductsXml -ProductsXml $x -SourceFwlinkId '2156292' -ClientTypes @('CLIENTCONSUMER', 'CLIENTBUSINESS') -IncludeUrl

        $items.Count | Should -Be 2
        ($items.fileName | Sort-Object) | Should -Be @(
            '19045.2965.230505-1139.22h2_release_svc_refresh_CLIENTBUSINESS_VOL_x64FRE_fr-fr.esd',
            '22631.2861.231204-0538.23H2_ni_release_svc_refresh_CLIENTCONSUMER_RET_x64FRE_en-us.esd'
        )

        # Newest build first (Win11 22631.* before Win10 19045.*)
        $items[0].buildMajor | Should -Be 22631
        $items[0].buildUbr | Should -Be 2861
        $items[0].url | Should -Match 'CLIENTCONSUMER'

        $items[1].buildMajor | Should -Be 19045
        $items[1].buildUbr | Should -Be 2965
        $items[1].url | Should -Match 'CLIENTBUSINESS'
    }
}
