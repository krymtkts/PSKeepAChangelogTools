---
document type: cmdlet
external help file: PSKeepAChangelogTools-Help.xml
HelpUri: https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/Assert-KeepAChangelogReleaseMetadata.md
Locale: en-US
Module Name: PSKeepAChangelogTools
ms.date: 08-13-2026
PlatyPS schema version: 2024-05-01
title: Assert-KeepAChangelogReleaseMetadata
---

# Assert-KeepAChangelogReleaseMetadata

## SYNOPSIS

Check that a changelog version exists and optionally matches a release tag.

## SYNTAX

### __AllParameterSets

```
Assert-KeepAChangelogReleaseMetadata [[-Path] <string>] [-Version] <string> [[-ReleaseTag] <string>]
 [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Checks that the changelog contains the specified version.

When you specify `ReleaseTag`, the command removes an optional `refs/tags/` prefix.
The tag name must start with `v` and the remaining value must match `Version`.
The command throws an error when the version is missing or the values do not match.

## EXAMPLES

### Example 1

```powershell
Assert-KeepAChangelogReleaseMetadata -Version '1.2.0' -ReleaseTag 'refs/tags/v1.2.0'
```

Check version `1.2.0` in `CHANGELOG.md` in the current directory.
The release tag must identify the same version.

## PARAMETERS

### -Path

The path to the changelog.
The default is `CHANGELOG.md` in the current directory.

```yaml
Type: System.String
DefaultValue: ""
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: (All)
    Position: 0
    IsRequired: false
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### -ReleaseTag

The release tag to compare with `Version`.
The accepted forms are `v<version>` and `refs/tags/v<version>`.

```yaml
Type: System.String
DefaultValue: ""
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: (All)
    Position: 2
    IsRequired: false
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### -Version

The changelog version to check.

```yaml
Type: System.String
DefaultValue: ""
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: (All)
    Position: 1
    IsRequired: true
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable.
For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

This command produces no output when validation succeeds.

## RELATED LINKS

- [PSKeepAChangelogTools module](https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/PSKeepAChangelogTools.md)
