---
document type: module
Help Version: 0.1.0
HelpInfoUri: https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/PSKeepAChangelogTools.md
Locale: en-US
Module Guid: b90e468d-788a-40a5-b06f-12c527599efe
Module Name: PSKeepAChangelogTools
ms.date: 08-13-2026
PlatyPS schema version: 2024-05-01
title: PSKeepAChangelogTools Module
---

# PSKeepAChangelogTools Module

## Description

A PowerShell module for parsing, validating, and synchronizing Keep a Changelog style changelogs.

The module uses `CHANGELOG.md` as the source of truth for release automation.
Commands that accept `-Path` use `CHANGELOG.md` in the current directory by default.

Footer link definitions are optional.
When a changelog ends with link definitions, place a `---` separator before the link definition block.

## PSKeepAChangelogTools

### [Assert-KeepAChangelogReleaseMetadata](Assert-KeepAChangelogReleaseMetadata.md)

Check that a changelog version exists and optionally matches a release tag.

### [Get-KeepAChangelogEntry](Get-KeepAChangelogEntry.md)

Get the body of a changelog section by version or release tag.

### [Get-KeepAChangelogManifestReleaseNotes](Get-KeepAChangelogManifestReleaseNotes.md)

Create module manifest release notes from recent changelog sections.

### [Get-KeepAChangelogSection](Get-KeepAChangelogSection.md)

Get changelog sections or a section for a specific version.

### [Set-KeepAChangelogManifestReleaseNotes](Set-KeepAChangelogManifestReleaseNotes.md)

Set `PrivateData.PSData.ReleaseNotes` in a PowerShell module manifest.
