# PSKeepAChangelogTools

PSKeepAChangelogTools is a PowerShell module for Keep a Changelog style changelogs.

The current design uses Keep a Changelog 1.1 as its basis.

It treats `CHANGELOG.md` as the source of truth and supports:

- changelog parsing and validation
- release note extraction for automation
- PowerShell module manifest `ReleaseNotes` synchronization

## Installation

Install from the PowerShell Gallery with PSResourceGet:

```powershell
Install-PSResource -Name PSKeepAChangelogTools -Repository PSGallery
```

Windows PowerShell 5.1 users can install with PowerShellGet:

```powershell
Install-Module -Name PSKeepAChangelogTools -Repository PSGallery
```

## Public commands

| Command                                  | Purpose                                                            |
| ---------------------------------------- | ------------------------------------------------------------------ |
| `Get-KeepAChangelogSection`              | Read all sections, or one section by `-Version`.                   |
| `Get-KeepAChangelogEntry`                | Read one section body by `-Version` or `-ReleaseTag`.              |
| `Assert-KeepAChangelogReleaseMetadata`   | Validate a versioned section, with optional release tag checking.  |
| `Get-KeepAChangelogManifestReleaseNotes` | Render manifest-oriented release notes for a target `-Version`.    |
| `Set-KeepAChangelogManifestReleaseNotes` | Write derived release notes into a module manifest `ReleaseNotes`. |

## Format notes

This module follows Keep a Changelog style, but it does not enforce every part of the 1.1 example.

- Release dates are not required yet.
  This avoids hidden timezone assumptions in automated heading generation.
- Semantic Versioning is not required by default.
  Version rules remain project policy rather than parser policy.
- Footer links are optional.
  The module recommends an explicit `---` separator.
  This keeps footer editing automation-safe.

## Usage

Read all sections, one section, or one section body:

```powershell
Get-KeepAChangelogSection
Get-KeepAChangelogSection -Version '1.0.0'
Get-KeepAChangelogEntry -ReleaseTag 'v1.0.0'
```

Check that a version exists and optionally matches a release tag:

```powershell
Assert-KeepAChangelogReleaseMetadata -Version '1.0.0' -ReleaseTag 'v1.0.0'
```

Render recent sections and write them to a PowerShell module manifest:

```powershell
$releaseNotes = Get-KeepAChangelogManifestReleaseNotes `
    -Version '1.0.0' `
    -RecentCount 3 `
    -FullChangelogUrl 'https://github.com/example/project/blob/main/CHANGELOG.md'

Set-KeepAChangelogManifestReleaseNotes `
    -ManifestPath './Example.psd1' `
    -ReleaseNotes $releaseNotes
```

Commands that accept `-Path` use `CHANGELOG.md` in the current directory by default.
`Set-KeepAChangelogManifestReleaseNotes` requires `-ManifestPath`.

## Development

### Release

Use `ReleaseTag` after you prepare the version metadata commit and configure Git signing.

```powershell
./.build.ps1 ReleaseTag -ReleaseTag v0.1.0
git push origin v0.1.0
```

`ReleaseTag` creates a local signed annotated tag from `CHANGELOG.md`.
It does not create the metadata commit.
It does not push the tag.

If you need to retry, do it before pushing. Delete the local tag and run the
task again.

```powershell
git tag -d v0.1.0
./.build.ps1 ReleaseTag -ReleaseTag v0.1.0
```
