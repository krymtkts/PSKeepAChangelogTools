BeforeAll {
    $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\PSKeepAChangelogTools.psd1'
    $script:ExpectedCommands = @(
        'Get-KeepAChangelogEntry'
        'Get-KeepAChangelogSection'
        'Get-KeepAChangelogSections'
        'Test-KeepAChangelogReleaseMetadata'
    )
}

Describe 'PSKeepAChangelogTools module scaffold' {
    It 'imports the module manifest without errors' {
        { Import-Module -Name $script:ModuleManifestPath -Force } |
            Should -Not -Throw
    }

    It 'exports the expected public commands' {
        Import-Module -Name $script:ModuleManifestPath -Force
        $module = Get-Module -Name 'PSKeepAChangelogTools'

        @($module.ExportedCommands.Keys | Sort-Object) | Should -Be ($script:ExpectedCommands | Sort-Object)
    }
}

AfterAll {
    Remove-Module -Name 'PSKeepAChangelogTools' -Force -ErrorAction SilentlyContinue
}
