BeforeAll {
    $script:ModuleManifestPath = Join-Path $PSScriptRoot '../../PSKeepAChangelogTools.psd1'
    $script:ExpectedCommands = @(
        'Assert-KeepAChangelogReleaseMetadata'
        'Get-KeepAChangelogEntry'
        'Get-KeepAChangelogManifestReleaseNotes'
        'Get-KeepAChangelogSection'
        'Set-KeepAChangelogManifestReleaseNotes'
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
