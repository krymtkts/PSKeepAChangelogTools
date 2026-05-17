BeforeAll {
    . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    $moduleRoot = Get-PSKeepAChangelogToolsTestModuleRoot

    $script:ModuleManifestPath = Join-Path $moduleRoot 'PSKeepAChangelogTools.psd1'
    Import-Module -Name $script:ModuleManifestPath -Force

    $script:NewTestChangelogContent = {
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
        ) -join "`n"
    }
}

Describe 'PSKeepAChangelogTools public API' {
    It 'declares the expected public command parameter sets where multiple sets exist' {
        $expectedParameterSetsByCommand = [ordered]@{
            'Get-KeepAChangelogSection'            = @('ByVersion', 'List')
            'Get-KeepAChangelogEntry'              = @('ByReleaseTag', 'ByVersion')
        }

        foreach ($commandName in $expectedParameterSetsByCommand.Keys) {
            $actualParameterSets = (Get-Command $commandName).ParameterSets.Name | Sort-Object
            $expectedParameterSets = $expectedParameterSetsByCommand[$commandName] | Sort-Object

            $actualParameterSets | Should -Be $expectedParameterSets
        }
    }

    It 'reads changelog sections from the current location by default' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        Push-Location $TestDrive
        try {
            $sections = Get-KeepAChangelogSection

            $sections.Count | Should -Be 4
            $sections[1].Version | Should -BeExactly '1.1.2'
        }
        finally {
            Pop-Location
        }
    }

    It 'reads changelog sections through the public command' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $sections = Get-KeepAChangelogSection -Path $changelogPath

        $sections.Count | Should -Be 4
        $sections[1].Version | Should -BeExactly '1.1.2'
    }

    It 'reads a changelog section through the public command' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $section = Get-KeepAChangelogSection -Path $changelogPath -Version '1.1.1'

        $section.Heading | Should -BeExactly '## [1.1.1] - 2023-03-06'
        $section.Body | Should -BeExactly (@(
                '### Added'
                ''
                'BBB'
            ) -join "`n")
    }

    It 'reads a changelog entry through the public command' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $entry = Get-KeepAChangelogEntry -Path $changelogPath -Version '1.1.0'

        $entry | Should -BeExactly (@(
                '### Added'
                ''
                'AAA'
            ) -join "`n")
    }

    It 'reads a changelog entry through a release tag' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $entry = Get-KeepAChangelogEntry -Path $changelogPath -ReleaseTag 'refs/tags/v1.1.2'

        $entry | Should -BeExactly (@(
                '### Added'
                ''
                'CCC'
            ) -join "`n")
    }

    It 'does not accept both version and release tag when reading a changelog entry' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Get-KeepAChangelogEntry -Path $changelogPath -Version '1.1.2' -ReleaseTag 'v1.1.2'
        } | Should -Throw
    }

    It 'does not accept a release tag when reading a changelog section' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Get-KeepAChangelogSection -Path $changelogPath -ReleaseTag 'v1.1.1'
        } | Should -Throw
    }

    It 'asserts release metadata from a version alone' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Assert-KeepAChangelogReleaseMetadata -Path $changelogPath -Version '1.1.2'
        } | Should -Not -Throw
    }

    It 'asserts release metadata when version and release tag match' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Assert-KeepAChangelogReleaseMetadata -Path $changelogPath -Version '1.1.2' -ReleaseTag 'v1.1.2'
        } | Should -Not -Throw
    }

    It 'throws when release metadata is invalid' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Assert-KeepAChangelogReleaseMetadata -Path $changelogPath -Version '1.1.2' -ReleaseTag 'v1.1.1'
        } | Should -Throw 'Release tag version does not match manifest version. Tag: 1.1.1, Manifest: 1.1.2'
    }

    It 'requires version and keeps release tag optional for release metadata' {
        $command = Get-Command 'Assert-KeepAChangelogReleaseMetadata'

        $command.ParameterSets | Should -HaveCount 1
        $parameterSet = $command.ParameterSets[0]

        ($parameterSet.Parameters | Where-Object Name -EQ 'Version').IsMandatory | Should -BeTrue
        ($parameterSet.Parameters | Where-Object Name -EQ 'ReleaseTag').IsMandatory | Should -BeFalse
    }

    It 'rejects an empty release tag before running release metadata validation' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Assert-KeepAChangelogReleaseMetadata -Path $changelogPath -Version '1.1.2' -ReleaseTag ''
        } | Should -Throw "*Cannot validate argument on parameter 'ReleaseTag'*"
    }

    It 'rejects a null release tag when splatted' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline
        $parameters = @{
            Path = $changelogPath
            Version = '1.1.2'
            ReleaseTag = $null
        }

        {
            Assert-KeepAChangelogReleaseMetadata @parameters
        } | Should -Throw "*Cannot validate argument on parameter 'ReleaseTag'*"
    }

    It 'rejects a whitespace-only release tag as an invalid tag format' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Assert-KeepAChangelogReleaseMetadata -Path $changelogPath -Version '1.1.2' -ReleaseTag '   '
        } | Should -Throw '*Release tag must use the form v<version>*'
    }

    It 'renders manifest release notes through the public command' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $content = Get-KeepAChangelogManifestReleaseNotes -Path $changelogPath -Version '1.1.2' -RecentCount 2 -FullChangelogUrl 'https://example.test/CHANGELOG.md'

        $content | Should -BeExactly (@(
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
            ) -join "`n")
    }

    It 'does not accept a release tag for manifest release notes' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Get-KeepAChangelogManifestReleaseNotes -Path $changelogPath -ReleaseTag 'v1.1.2' -RecentCount 2 -FullChangelogUrl 'https://example.test/CHANGELOG.md'
        } | Should -Throw
    }

    It 'updates manifest release notes through the public command' {
        $manifestPath = Join-Path $TestDrive 'test.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            '            # ReleaseNotes of this module'
            "            # ReleaseNotes = ''"
            ''
            '            # Prerelease string of this module'
            "            Prerelease = 'alpha'"
            '        }'
            '    }'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline

        $releaseNotes = @(
            '### Added'
            ''
            '- Add thing'
        ) -join "`n"

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes $releaseNotes

        $manifest = Import-PowerShellDataFile -Path $manifestPath
        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly $releaseNotes
    }
}

AfterAll {
    Remove-Module -Name 'PSKeepAChangelogTools' -Force -ErrorAction SilentlyContinue
}
