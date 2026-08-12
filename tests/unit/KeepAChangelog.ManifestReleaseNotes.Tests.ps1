BeforeAll {
    . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    $moduleRoot = Get-PSKeepAChangelogToolsTestModuleRoot

    $commonPath = Join-Path $moduleRoot 'src/KeepAChangelog.Common.ps1'
    $corePath = Join-Path $moduleRoot 'src/KeepAChangelog.Core.ps1'
    $manifestHelperPath = Join-Path $moduleRoot 'src/KeepAChangelog.ManifestReleaseNotes.ps1'
    . $commonPath
    . $corePath
    . $manifestHelperPath

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

    $script:WriteTestManifest = {
        param(
            [string] $Path,
            [string] $Content,
            [System.Text.Encoding] $Encoding,
            [bool] $IncludeByteOrderMark
        )

        $contentBytes = $Encoding.GetBytes($Content)
        [byte[]] $byteOrderMark = [byte[]]::new(0)
        if ($IncludeByteOrderMark) {
            $byteOrderMark = $Encoding.GetPreamble()
        }
        $fileBytes = [byte[]]::new($byteOrderMark.Length + $contentBytes.Length)
        if ($byteOrderMark.Length -gt 0) {
            [System.Buffer]::BlockCopy($byteOrderMark, 0, $fileBytes, 0, $byteOrderMark.Length)
        }
        [System.Buffer]::BlockCopy($contentBytes, 0, $fileBytes, $byteOrderMark.Length, $contentBytes.Length)
        [System.IO.File]::WriteAllBytes($Path, $fileBytes)
    }

    $script:AssertTestManifestFormatPreserved = {
        param(
            [string] $FileName,
            [System.Text.Encoding] $Encoding,
            [bool] $IncludeByteOrderMark,
            [string] $NewLine,
            [string] $Copyright
        )

        $manifestPath = Join-Path $TestDrive $FileName
        $manifestContent = @(
            '@{'
            "    Copyright = '$Copyright'"
            '    PrivateData = @{'
            '        PSData = @{'
            '            # ReleaseNotes of this module'
            "            ReleaseNotes = ''"
            ''
            '            # Prerelease string of this module'
            "            Prerelease = 'alpha'"
            '        }'
            '    }'
            '}'
        ) -join $NewLine
        & $script:WriteTestManifest -Path $manifestPath -Content $manifestContent -Encoding $Encoding -IncludeByteOrderMark $IncludeByteOrderMark

        $releaseNotes = @(
            '### Added'
            ''
            '- Add thing'
        ) -join "`n"
        $expectedReleaseNotes = $releaseNotes -replace "`n", $NewLine

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes $releaseNotes

        $updatedBytes = [System.IO.File]::ReadAllBytes($manifestPath)
        [byte[]] $expectedByteOrderMark = [byte[]]::new(0)
        if ($IncludeByteOrderMark) {
            $expectedByteOrderMark = $Encoding.GetPreamble()
        }
        if ($expectedByteOrderMark.Length -gt 0) {
            [System.BitConverter]::ToString($updatedBytes, 0, $expectedByteOrderMark.Length) |
                Should -BeExactly ([System.BitConverter]::ToString($expectedByteOrderMark))
        }
        else {
            $updatedBytes[0] | Should -Be ($Encoding.GetBytes('@')[0])
        }

        $updatedText = $Encoding.GetString(
            $updatedBytes,
            $expectedByteOrderMark.Length,
            $updatedBytes.Length - $expectedByteOrderMark.Length
        )
        if ($NewLine -eq "`r`n") {
            ($updatedText -replace "`r`n", '') | Should -Not -Match '[\r\n]'
        }
        else {
            $updatedText | Should -Not -Match "`r"
            $updatedText | Should -Match "`n"
        }

        $updatedText | Should -Match ([regex]::Escape("Copyright = '$Copyright'"))
        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly $expectedReleaseNotes
    }
}

Describe 'Get-KeepAChangelogManifestReleaseNotes' {
    It 'formats the target version and the next two older versions plus a full changelog link' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $content = Get-KeepAChangelogManifestReleaseNotes -Path $changelogPath -Version '1.1.2' -RecentCount 3 -FullChangelogUrl 'https://example.test/CHANGELOG.md'

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
                '## [1.1.0] - 2023-03-05'
                ''
                '### Added'
                ''
                'AAA'
                ''
                'Full CHANGELOG: https://example.test/CHANGELOG.md'
            ) -join "`n")
    }

    It 'uses only the available sections when there are fewer than the requested count' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $content = Get-KeepAChangelogManifestReleaseNotes -Path $changelogPath -Version '1.1.1' -RecentCount 3 -FullChangelogUrl 'https://example.test/CHANGELOG.md'

        $content | Should -BeExactly (@(
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
                'Full CHANGELOG: https://example.test/CHANGELOG.md'
            ) -join "`n")
    }

    It 'limits the output when RecentCount is smaller than the available section count' {
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

    It 'requires an explicit version' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Get-KeepAChangelogManifestReleaseNotes -Path $changelogPath -ReleaseTag 'v1.1.2' -RecentCount 2 -FullChangelogUrl 'https://example.test/CHANGELOG.md'
        } | Should -Throw
    }
}

Describe 'Set-KeepAChangelogManifestReleaseNotes' {
    It 'writes a release notes here-string that Import-PowerShellDataFile can read' {
        $manifestPath = Join-Path $TestDrive 'test.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            '            # ReleaseNotes of this module'
            "            ReleaseNotes = ''"
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
        $fileCount = @(Get-ChildItem -LiteralPath $TestDrive -File -Force).Count

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes $releaseNotes
        $manifest = Import-PowerShellDataFile -Path $manifestPath
        $manifestText = Get-Content -LiteralPath $manifestPath -Raw

        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly $releaseNotes
        $manifestText | Should -Not -Match "`r"
        @(Get-ChildItem -LiteralPath $TestDrive -File -Force).Count | Should -Be $fileCount
    }

    It 'replaces a commented ReleaseNotes property without changing surrounding content' {
        $manifestPath = Join-Path $TestDrive 'commented.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            '            # ReleaseNotes of this module'
            "            # ReleaseNotes = ''"
            ''
            "            ProjectUri = 'https://example.test/project'"
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

        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly $releaseNotes
        Get-Content -LiteralPath $manifestPath -Raw | Should -BeExactly (@(
                '@{'
                '    PrivateData = @{'
                '        PSData = @{'
                '            # ReleaseNotes of this module'
                "            ReleaseNotes = @'"
                '### Added'
                ''
                '- Add thing'
                "'@"
                ''
                "            ProjectUri = 'https://example.test/project'"
                ''
                '            # Prerelease string of this module'
                "            Prerelease = 'alpha'"
                '        }'
                '    }'
                '}'
            ) -join "`n")
    }

    It 'replaces existing ReleaseNotes content instead of appending to it' {
        $manifestPath = Join-Path $TestDrive 'existing.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            '            # ReleaseNotes of this module'
            "            ReleaseNotes = @'"
            'old line'
            "'@"
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
            '- New line'
        ) -join "`n"

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes $releaseNotes
        $manifest = Import-PowerShellDataFile -Path $manifestPath
        $manifestText = Get-Content -LiteralPath $manifestPath -Raw

        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly $releaseNotes
        $manifestText | Should -Not -Match 'old line'
    }

    It 'updates ReleaseNotes without relying on manifest comments' {
        $manifestPath = Join-Path $TestDrive 'without-comments.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            "            ReleaseNotes = ''"
            "            Prerelease = 'alpha'"
            '        }'
            '    }'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline

        $releaseNotes = @(
            '### Fixed'
            ''
            '- Update without comments'
        ) -join "`n"

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes $releaseNotes

        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly $releaseNotes
        $manifest.PrivateData.PSData.Prerelease | Should -BeExactly 'alpha'
        Get-Content -LiteralPath $manifestPath -Raw | Should -BeExactly (@(
                '@{'
                '    PrivateData = @{'
                '        PSData = @{'
                "            ReleaseNotes = @'"
                '### Fixed'
                ''
                '- Update without comments'
                "'@"
                "            Prerelease = 'alpha'"
                '        }'
                '    }'
                '}'
            ) -join "`n")
    }

    It 'adds ReleaseNotes when the property is missing from PSData' {
        $manifestPath = Join-Path $TestDrive 'without-release-notes.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            "            Prerelease = 'alpha'"
            '        }'
            '    }'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes 'new notes'

        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly 'new notes'
        $manifest.PrivateData.PSData.Prerelease | Should -BeExactly 'alpha'
        Get-Content -LiteralPath $manifestPath -Raw | Should -BeExactly (@(
                '@{'
                '    PrivateData = @{'
                '        PSData = @{'
                "            Prerelease = 'alpha'"
                "            ReleaseNotes = @'"
                'new notes'
                "'@"
                '        }'
                '    }'
                '}'
            ) -join "`n")
    }

    It 'adds PSData and ReleaseNotes when PSData is missing from PrivateData' {
        $manifestPath = Join-Path $TestDrive 'without-psdata.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            "        Note = 'keep'"
            '    }'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes 'new notes'

        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly 'new notes'
        $manifest.PrivateData.Note | Should -BeExactly 'keep'
        Get-Content -LiteralPath $manifestPath -Raw | Should -BeExactly (@(
                '@{'
                '    PrivateData = @{'
                "        Note = 'keep'"
                '        PSData = @{'
                "            ReleaseNotes = @'"
                'new notes'
                "'@"
                '        }'
                '    }'
                '}'
            ) -join "`n")
    }

    It 'preserves comments and blank lines when adding PSData and ReleaseNotes' {
        $manifestPath = Join-Path $TestDrive 'without-psdata-with-comments.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        # Existing private data'
            "        Note = 'keep' # Keep this inline comment"
            ''
            '    }'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes 'new notes'

        Get-Content -LiteralPath $manifestPath -Raw | Should -BeExactly (@(
                '@{'
                '    PrivateData = @{'
                '        # Existing private data'
                "        Note = 'keep' # Keep this inline comment"
                ''
                '        PSData = @{'
                "            ReleaseNotes = @'"
                'new notes'
                "'@"
                '        }'
                '    }'
                '}'
            ) -join "`n")
    }

    It 'adds PrivateData, PSData, and ReleaseNotes when PrivateData is missing' {
        $manifestPath = Join-Path $TestDrive 'without-private-data.psd1'
        "@{ ModuleVersion = '1.0.0'}" | Set-Content -LiteralPath $manifestPath -NoNewline

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes 'new notes'

        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly 'new notes'
        $manifest.ModuleVersion | Should -BeExactly '1.0.0'
        Get-Content -LiteralPath $manifestPath -Raw | Should -BeExactly (@(
                "@{ ModuleVersion = '1.0.0'"
                '    PrivateData = @{'
                '        PSData = @{'
                "            ReleaseNotes = @'"
                'new notes'
                "'@"
                '        }'
                '    }'
                '}'
            ) -join "`n")
    }

    It 'preserves UTF-8 without a byte order mark and LF line endings' {
        & $script:AssertTestManifestFormatPreserved `
            -FileName 'utf8-no-bom-lf.psd1' `
            -Encoding ([System.Text.UTF8Encoding]::new($false, $true)) `
            -IncludeByteOrderMark $false `
            -NewLine "`n" `
            -Copyright '(c)'
    }

    It 'preserves UTF-8 with a byte order mark and CRLF line endings' {
        & $script:AssertTestManifestFormatPreserved `
            -FileName 'utf8-bom-crlf.psd1' `
            -Encoding ([System.Text.UTF8Encoding]::new($true, $true)) `
            -IncludeByteOrderMark $true `
            -NewLine "`r`n" `
            -Copyright '(c)'
    }

    It 'preserves UTF-16 little-endian encoding and LF line endings' {
        & $script:AssertTestManifestFormatPreserved `
            -FileName 'utf16-le-lf.psd1' `
            -Encoding ([System.Text.UnicodeEncoding]::new($false, $true, $true)) `
            -IncludeByteOrderMark $true `
            -NewLine "`n" `
            -Copyright '(c)'
    }

    It 'preserves UTF-16 big-endian encoding and CRLF line endings' {
        & $script:AssertTestManifestFormatPreserved `
            -FileName 'utf16-be-crlf.psd1' `
            -Encoding ([System.Text.UnicodeEncoding]::new($true, $true, $true)) `
            -IncludeByteOrderMark $true `
            -NewLine "`r`n" `
            -Copyright '(c)'
    }

    # NOTE: Windows PowerShell may misinterpret non-ASCII UTF-8 text without a byte order mark.
    # https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_character_encoding#the-byte-order-mark
    It 'preserves non-ASCII UTF-8 without a byte order mark on PowerShell 7' -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
        & $script:AssertTestManifestFormatPreserved `
            -FileName 'utf8-no-bom-non-ascii.psd1' `
            -Encoding ([System.Text.UTF8Encoding]::new($false, $true)) `
            -IncludeByteOrderMark $false `
            -NewLine "`n" `
            -Copyright '©'
    }

    It 'rejects a here-string terminator without changing the manifest bytes' {
        $manifestPath = Join-Path $TestDrive 'invalid-release-notes.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            "            ReleaseNotes = ''"
            '        }'
            '    }'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline
        $originalBytes = [System.IO.File]::ReadAllBytes($manifestPath)
        $releaseNotes = @(
            '### Added'
            "'@"
            '- Invalid here-string content'
        ) -join "`n"

        {
            Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes $releaseNotes
        } | Should -Throw 'Could not create a valid manifest from ReleaseNotes:*'

        [System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($manifestPath)) |
            Should -BeExactly ([System.BitConverter]::ToString($originalBytes))
    }

    It 'rejects a manifest with syntax errors without changing its bytes' {
        $manifestPath = Join-Path $TestDrive 'invalid-manifest.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            "            ReleaseNotes = ''"
            '        }'
            '    }'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline
        $originalBytes = [System.IO.File]::ReadAllBytes($manifestPath)

        {
            Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes 'new notes'
        } | Should -Throw 'Manifest contains syntax errors:*'

        [System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($manifestPath)) |
            Should -BeExactly ([System.BitConverter]::ToString($originalBytes))
    }

    It 'updates ReleaseNotes when another property contains a dynamic expression' {
        $manifestPath = Join-Path $TestDrive 'dynamic-expression.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            "            ReleaseNotes = ''"
            '        }'
            '    }'
            '    Generated = Get-Date'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline
        $fileCount = @(Get-ChildItem -LiteralPath $TestDrive -File -Force).Count

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes 'new notes'

        (Get-Content -Raw -LiteralPath $manifestPath) | Should -Match "ReleaseNotes = @'`nnew notes`n'@"
        @(Get-ChildItem -LiteralPath $TestDrive -File -Force).Count | Should -Be $fileCount
    }

    It 'keeps the original manifest when updated ReleaseNotes validation fails' {
        $manifestPath = Join-Path $TestDrive 'mismatched-release-notes.psd1'
        "@{ PrivateData = @{ PSData = @{ ReleaseNotes = '' } } }" |
            Set-Content -LiteralPath $manifestPath -NoNewline
        $originalBytes = [System.IO.File]::ReadAllBytes($manifestPath)
        $fileCount = @(Get-ChildItem -LiteralPath $TestDrive -File -Force).Count
        Mock Assert-KeepAChangelogManifestReleaseNotesValue {
            throw 'Updated manifest ReleaseNotes did not match the requested value'
        }

        {
            Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes 'new notes'
        } | Should -Throw 'Updated manifest ReleaseNotes did not match the requested value'

        [System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($manifestPath)) |
            Should -BeExactly ([System.BitConverter]::ToString($originalBytes))
        @(Get-ChildItem -LiteralPath $TestDrive -File -Force).Count | Should -Be $fileCount
    }

    It 'does not create another file with WhatIf' {
        $manifestPath = Join-Path $TestDrive 'what-if.psd1'
        "@{ PrivateData = @{ PSData = @{ ReleaseNotes = '' } } }" |
            Set-Content -LiteralPath $manifestPath -NoNewline
        $originalBytes = [System.IO.File]::ReadAllBytes($manifestPath)
        $fileCount = @(Get-ChildItem -LiteralPath $TestDrive -File -Force).Count

        Set-KeepAChangelogManifestReleaseNotes `
            -ManifestPath $manifestPath `
            -ReleaseNotes 'new notes' `
            -WhatIf

        [System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($manifestPath)) |
            Should -BeExactly ([System.BitConverter]::ToString($originalBytes))
        @(Get-ChildItem -LiteralPath $TestDrive -File -Force).Count | Should -Be $fileCount
    }

    It 'rejects invalid UTF-8 without changing the manifest bytes' {
        $manifestPath = Join-Path $TestDrive 'invalid-utf8.psd1'
        $invalidBytes = [byte[]] @(0xC3, 0x28)
        [System.IO.File]::WriteAllBytes($manifestPath, $invalidBytes)

        {
            Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes 'new notes'
        } | Should -Throw 'Could not decode manifest using a supported encoding:*'

        [System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($manifestPath)) |
            Should -BeExactly ([System.BitConverter]::ToString($invalidBytes))
    }
}
