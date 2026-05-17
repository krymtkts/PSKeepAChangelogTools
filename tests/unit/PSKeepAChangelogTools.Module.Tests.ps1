BeforeAll {
    $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\PSKeepAChangelogTools.psd1'
}

Describe 'PSKeepAChangelogTools module scaffold' {
    It 'imports the module manifest without errors' {
        { Import-Module -Name $script:ModuleManifestPath -Force } |
            Should -Not -Throw
    }

    It 'exports no public commands yet' {
        Import-Module -Name $script:ModuleManifestPath -Force
        $module = Get-Module -Name 'PSKeepAChangelogTools'

        @($module.ExportedCommands.Keys).Count | Should -Be 0
    }
}

AfterAll {
    Remove-Module -Name 'PSKeepAChangelogTools' -Force -ErrorAction SilentlyContinue
}
