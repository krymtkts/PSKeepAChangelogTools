BeforeAll {
    . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    $moduleRoot = Get-PSKeepAChangelogToolsTestModuleRoot

    $script:ModuleManifestPath = Join-Path $moduleRoot 'PSKeepAChangelogTools.psd1'
    Remove-Module -Name 'PSKeepAChangelogTools' -Force -ErrorAction SilentlyContinue
    Import-Module -Name $script:ModuleManifestPath -Force

    $script:NewIntegrationProject = {
        param(
            [Parameter(Mandatory)]
            [string] $ProjectRoot
        )

        $null = New-Item -ItemType Directory -Path $ProjectRoot -Force

        $changelogPath = Join-Path $ProjectRoot 'CHANGELOG.md'
        @(
            '# Changelog'
            ''
            'This file records all notable changes to this project.'
            ''
            '## [Unreleased]'
            ''
            'aaaaa'
            ''
            '## [1.1.2] - 2023-03-07'
            ''
            '### Added'
            ''
            'CCC'
            ''
            '## [1.1.1] - 2023-03-06'
            ''
            '### Added'
            ''
            'BBB'
            ''
            '## [1.1.0] - 2023-03-05'
            ''
            '### Added'
            ''
            'AAA'
            ''
            '---'
            ''
            '[Unreleased]: https://github.com/krymtkts/pslrm/commits/main'
        ) -join "`n" | Set-Content -LiteralPath $changelogPath -NoNewline

        $manifestPath = Join-Path $ProjectRoot 'TestModule.psd1'
        @(
            '@{'
            '    RootModule = ''TestModule.psm1'''
            '    ModuleVersion = ''1.1.2'''
            '    PrivateData = @{'
            '        PSData = @{'
            '            # ReleaseNotes of this module'
            '            # ReleaseNotes = '''''
            ''
            '            # Prerelease string of this module'
            '            # Prerelease = '''''
            '        }'
            '    }'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline

        [pscustomobject]@{
            ProjectRoot = $ProjectRoot
            ChangelogPath = $changelogPath
            ManifestPath = $manifestPath
        }
    }
}

Describe 'PSKeepAChangelogTools integration' {
    It 'imports the configured module artifacts and updates manifest release notes through the public flow' {
        $module = Get-Module -Name 'PSKeepAChangelogTools'
        $module | Should -Not -BeNullOrEmpty
        $module.ModuleBase | Should -BeExactly (Split-Path -Parent $script:ModuleManifestPath)

        $project = & $script:NewIntegrationProject -ProjectRoot (Join-Path $TestDrive 'project')

        Push-Location $project.ProjectRoot
        try {
            { Assert-KeepAChangelogReleaseMetadata -Version '1.1.2' -ReleaseTag 'refs/tags/v1.1.2' } |
                Should -Not -Throw

            $entry = Get-KeepAChangelogEntry -ReleaseTag 'refs/tags/v1.1.2'
            $entry | Should -BeExactly (@(
                    '### Added'
                    ''
                    'CCC'
                ) -join "`n")

            $releaseNotes = Get-KeepAChangelogManifestReleaseNotes -Version '1.1.2' -RecentCount 2 -FullChangelogUrl 'https://example.test/CHANGELOG.md'
            Set-KeepAChangelogManifestReleaseNotes -ManifestPath $project.ManifestPath -ReleaseNotes $releaseNotes
        }
        finally {
            Pop-Location
        }

        $manifest = Import-PowerShellDataFile -Path $project.ManifestPath
        $manifestText = Get-Content -LiteralPath $project.ManifestPath -Raw
        $expectedReleaseNotes = @(
            '## [1.1.2] - 2023-03-07'
            ''
            '### Added'
            ''
            'CCC'
            ''
            '## [1.1.1] - 2023-03-06'
            ''
            '### Added'
            ''
            'BBB'
            ''
            'Full CHANGELOG: https://example.test/CHANGELOG.md'
        ) -join "`n"

        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly $expectedReleaseNotes
        $manifestText | Should -Not -Match "`r"
    }
}

AfterAll {
    Remove-Module -Name 'PSKeepAChangelogTools' -Force -ErrorAction SilentlyContinue
}
