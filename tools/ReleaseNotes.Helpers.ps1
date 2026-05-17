Set-StrictMode -Version Latest

$script:PSKeepAChangelogToolsSourceRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $script:PSKeepAChangelogToolsSourceRoot 'src/KeepAChangelog.Common.ps1')
. (Join-Path $script:PSKeepAChangelogToolsSourceRoot 'src/KeepAChangelog.Core.ps1')
. (Join-Path $script:PSKeepAChangelogToolsSourceRoot 'src/KeepAChangelog.ManifestReleaseNotes.ps1')
