# Changelog

This file records all notable changes to this project.

This changelog uses the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## [Unreleased]

### Changed

- Require a `---` separator before link definitions at the end of `CHANGELOG.md`.
- Update existing manifest release note values and add a missing `PrivateData.PSData.ReleaseNotes` path. Preserve unrelated text, encoding, byte order marks, and line endings.

### Fixed

- Check existing and generated manifest syntax before writing. Confirm that the generated `PrivateData.PSData.ReleaseNotes` value matches the requested text. Keep the original manifest unchanged if any check fails.
- Reject duplicate changelog versions while excluding fenced code blocks from section parsing.

## [0.1.0]

### Added

- Add `Get-KeepAChangelogSection` for reading changelog sections by version.
- Add `Get-KeepAChangelogEntry` for reading rendered changelog entries by version.
- Add `Assert-KeepAChangelogReleaseMetadata` for validating changelog versions and release tags.
- Add `Get-KeepAChangelogManifestReleaseNotes` for rendering manifest release notes from `CHANGELOG.md`.
- Add `Set-KeepAChangelogManifestReleaseNotes` for updating manifest release notes.
- Add build tasks for linting, tests, and release note synchronization.
- Add staged-module integration tests, CI, and release automation.

### Notes

- This is the first public release of `PSKeepAChangelogTools`.
- Supported PowerShell versions are Windows PowerShell 5.1 through PowerShell 7.x.
- The module scope is intentionally limited to Keep a Changelog style changelogs.

---

[Unreleased]: https://github.com/krymtkts/PSKeepAChangelogTools/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/krymtkts/PSKeepAChangelogTools/releases/tag/v0.1.0
