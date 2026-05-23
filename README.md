# PSKeepAChangelogTools

PSKeepAChangelogTools is a PowerShell module for Keep a Changelog style changelogs.

The current design uses Keep a Changelog 1.1 as its basis.

It treats `CHANGELOG.md` as the source of truth and supports:

- changelog parsing and validation
- release note extraction for automation
- optional PowerShell-specific helpers such as module manifest `ReleaseNotes`
  synchronization

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

## Planned scope

- Parse Keep a Changelog sections such as `Unreleased` and versioned releases.
- Check release metadata against changelog content.
- Render release notes for GitHub releases and tag messages.
- Synchronize derived release notes into PowerShell module manifests.
