# Startup Monitor 64 — Allowed and Denied Rules

Startup Monitor 64 normally remembers a specific detected item together with its saved fingerprint. If that item's data later changes, Startup Monitor 64 can report it again as modified.

Rules are different. A rule tells Startup Monitor 64 to trust or deny a narrowly defined identity or name pattern even when the item's fingerprint or generated identifier changes.

## Safety warning

**WARNING:** Rules apply automatically to future detections.

- An **Allowed** rule can suppress future review prompts for matching startup items.
- A **Denied** rule can cause matching startup items to be removed, depending on the application's Denied notification/review settings.
- Only create rules you understand.
- Avoid broad prefixes.
- File rules match an **exact filename only**. They do not use arbitrary substring matching.
- A file-name rule may match that same filename in more than one monitored folder.
- Registry prefix rules are restricted to the **exact registry key** you specify.
- Scheduled-task prefix rules are restricted to the task name.

## Adding a rule

Open **Settings**, then select either **Allowed** or **Denied** and click **Add**.

Choose one of the supported rule types:

### File name equals

Matches files only, and only when the filename is an exact case-insensitive match.

Example:

```text
Dropbox.exe
```

This can match `Dropbox.exe`, but it does not match `DropboxHelper.exe` or `MyDropbox.exe`.

The rule can match the same filename in more than one monitored folder.

### Registry value equals

Matches one exact registry key and one exact value name.

Example key:

```text
HKLM\System\CurrentControlSet\Control\Session Manager
```

Example value:

```text
PendingFileRenameOperations
```

Changes to the data stored in that exact registry value can then be handled by the rule instead of being treated as a newly modified identity each time.

### Registry value name starts with

Matches value names beginning with a specified prefix, but only inside the exact registry key entered.

Example key:

```text
HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce
```

Example prefix:

```text
msedge_cleanup_
```

This is intended for software that creates transient values with changing suffixes, such as generated identifiers.

Do not use a broad prefix unless you understand every value it could match in that registry key.

### Scheduled task name equals

Matches one exact scheduled-task name.

### Scheduled task name starts with

Matches scheduled tasks whose names begin with the specified text.

Use task prefixes narrowly.

## Rule precedence

If a detected item matches both an Allowed rule and a Denied rule, the **Denied rule takes precedence**.

This is intentional so an Allowed rule cannot override a more restrictive Denied rule.

## Existing Allowed and Denied entries

Normal entries continue to work exactly as before. They contain the detected item's key together with a saved fingerprint.

Rules are stored separately in the same INI section using a recognisable `[RULE ...]` key and `*` as the marker value.

Examples:

```ini
[RULE FILE NAME] Dropbox.exe=*
[RULE REG EXACT] HKLM\System\CurrentControlSet\Control\Session Manager|PendingFileRenameOperations=*
[RULE REG PREFIX] HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce|msedge_cleanup_=*
```

Existing Allowed.ini and Denied.ini files do not need to be converted.

## Removing a rule

Rules appear in the normal Allowed or Denied table. Tick the rule and click **Remove**, the same as any other saved entry.

## Recommended use

Use exact rules whenever possible.

Use registry or scheduled-task prefix rules only for known software that deliberately generates changing names. If an entry is unfamiliar, inspect the command, path, registry data, or task action before creating a permanent rule for it.
