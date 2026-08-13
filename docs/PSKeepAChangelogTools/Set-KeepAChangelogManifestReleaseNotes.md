---
document type: cmdlet
external help file: PSKeepAChangelogTools-Help.xml
HelpUri: https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/Set-KeepAChangelogManifestReleaseNotes.md
Locale: en-US
Module Name: PSKeepAChangelogTools
ms.date: 08-13-2026
PlatyPS schema version: 2024-05-01
title: Set-KeepAChangelogManifestReleaseNotes
---

# Set-KeepAChangelogManifestReleaseNotes

## SYNOPSIS

Set `PrivateData.PSData.ReleaseNotes` in a PowerShell module manifest.

## SYNTAX

### __AllParameterSets

```
Set-KeepAChangelogManifestReleaseNotes [-ManifestPath] <string> [-ReleaseNotes] <string> [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Updates the `PrivateData.PSData.ReleaseNotes` value in a PowerShell module manifest.
When `PrivateData`, `PSData`, or `ReleaseNotes` is missing, the command adds the missing path.

The command preserves comments and empty lines outside the edited range.
It also preserves property order and other text.
It also preserves the manifest encoding, byte order mark, and line endings.
Before writing the file, the command checks the updated manifest syntax and release notes value.

## EXAMPLES

### Example 1

```powershell
$releaseNotes = Get-KeepAChangelogManifestReleaseNotes `
    -Version '1.2.0' `
    -FullChangelogUrl 'https://github.com/example/project/blob/main/CHANGELOG.md'

Set-KeepAChangelogManifestReleaseNotes `
    -ManifestPath './Example.psd1' `
    -ReleaseNotes $releaseNotes
```

Generate release notes from `CHANGELOG.md` and write them to `Example.psd1`.

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ""
SupportsWildcards: false
Aliases:
  - cf
ParameterSets:
  - Name: (All)
    Position: Named
    IsRequired: false
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### -ManifestPath

The path to the PowerShell module manifest to update.

```yaml
Type: System.String
DefaultValue: ""
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: (All)
    Position: 0
    IsRequired: true
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### -ReleaseNotes

The text to store in `PrivateData.PSData.ReleaseNotes`.

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

### -WhatIf

Shows what would happen without updating the manifest.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ""
SupportsWildcards: false
Aliases:
  - wi
ParameterSets:
  - Name: (All)
    Position: Named
    IsRequired: false
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

The command produces no output.
Use `WhatIf` to inspect the target without writing the manifest.

If validation fails, the original manifest remains unchanged.

## RELATED LINKS

- [Get-KeepAChangelogManifestReleaseNotes](https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/Get-KeepAChangelogManifestReleaseNotes.md)
- [PSKeepAChangelogTools module](https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/PSKeepAChangelogTools.md)
