# Startup Monitor 64 — Features and Changes Completed During the Conversion

## Core Conversion

- Converted the original AutoIt application to Python.
- Rebuilt the interface with PySide6.
- Preserved the existing Startup Monitor behaviour while modernising the implementation.
- Treated the Python version as the authoritative implementation, using the AutoIt version only as a visual and behavioural reference.
- Created a native 64-bit Windows build workflow using PyInstaller.

## Startup Monitoring

- Added monitoring of configured startup folders.
- Added monitoring of Windows Registry startup locations.
- Added monitoring of Windows scheduled tasks.
- Added configurable folder and Registry location management.
- Added support for enabling and disabling individual monitoring locations.
- Added support for adding custom startup folders.
- Added support for adding custom Registry paths.
- Added editing of existing monitored locations.
- Added removal of monitored locations with an in-window confirmation panel.
- Added opening Registry Editor directly from the Locations context menu.
- Added separate configurable scan intervals for normal startup locations and scheduled tasks.
- Added pause and resume monitoring controls.
- Added a visible **Monitoring Paused** status indicator.
- Ensured the Settings window updates when monitoring is paused or resumed.

## Baseline Management

- Added persistent startup baselines to reduce false alerts.
- Added separate baselines for:
  - startup-folder files;
  - Registry startup values;
  - scheduled tasks.
- Added a **Base Startup** tab showing:
  - item number;
  - name;
  - type;
  - location or path;
  - stored hash.
- Added a **Base Tasks** tab showing scheduled-task baseline entries.
- Added removal of selected baseline entries.
- Added confirmation panels before baseline removal.
- Added refresh actions for both baseline tabs.
- Added **Copy Path** actions.
- Added yellow **Location/Path** information panels.
- Added automatic path display when clicking or right-clicking a baseline row.
- Added automatic information-panel reset after refresh or removal.

## Allowed and Denied Lists

- Added dedicated **Allowed** and **Denied** tabs.
- Added stored fingerprint display for each entry.
- Added checkbox-based multi-selection.
- Added removal of one or more entries.
- Added singular and plural confirmation messages.
- Added confirmation and cancellation panels directly inside the tabs.
- Added refresh actions that reload the lists from disk.
- Added **Copy Path** actions.
- Added context menus containing **Remove**, **Refresh**, and **Copy Path**.
- Ensured Allowed and Denied changes are saved and immediately reloaded by the monitoring engine.
- Added log entries when Allowed or Denied items are removed.

## Review Window

- Added a review window for newly detected or modified startup entries.
- Added item information columns for:
  - Allow;
  - Name;
  - Type;
  - Status;
  - Path or Command.
- Added configurable default selection of review items.
- Added **Select All** and **Select None** controls.
- Added **Apply** and **Cancel** behaviour.
- Added configurable review-window width and height.
- Added minimum review-window sizing.
- Added always-on-top behaviour.
- Added duplicate-review suppression so the same item is not repeatedly queued.
- Added handling for pending review groups.
- Added optional repeat review of previously denied items.
- Added automatic denial and removal behaviour where configured.
- Added export of review results to an INI report.
- Included item names, types, statuses, paths, keys, fingerprints, and Allow decisions in exported reports.

## Selection and Context-Menu Behaviour

- Synchronised row selection with checkboxes in:
  - Allowed;
  - Denied;
  - Base Startup;
  - Base Tasks.
- Selecting rows now checks their action checkboxes.
- Checking or unchecking an action checkbox now updates row selection.
- Preserved multi-row selections when right-clicking an already selected row.
- Made right-clicking an unselected row select only that row.
- Prevented context menus from acting on stale selections.
- Synchronised selection behaviour across Locations and all action tables.
- Added consistent **Remove**, **Refresh**, and **Copy Path** context menus.
- Kept the Locations context menu specialised with **Edit**, **Add Folder**, **Add Registry Path**, and **Open RegEdit** actions.

## Settings and Defaults

- Added numeric validation for:
  - monitor interval;
  - scheduled-task scan interval;
  - review-window width;
  - review-window height.
- Added minimum and maximum values for each numeric option.
- Added input validators and clear warning messages.
- Added automatic focus and text selection when a value is invalid.
- Added a **Reset to Defaults** button.
- Reset to Defaults now restores:
  - numeric options;
  - checkbox options;
  - System theme;
  - default monitored startup folders;
  - default monitored Registry locations.
- Added a note explaining that Reset to Defaults restores Options and Locations.
- Clarified that reset changes are only saved when **Apply** is clicked.
- Closing Settings without Apply leaves the saved configuration unchanged.
- Added a minimum Settings-window width based on the tab-bar size.
- Changed Apply so it saves changes and closes the Settings window silently.
- Added a **Close** button that exits without applying unsaved changes.
- Added a **Settings Folder** button.

## Theme Support

- Added **Light** theme.
- Added **Dark** theme.
- Added **System** theme.
- Added theme selection to Settings.
- Added immediate theme application after Apply.
- Added support for Qt colour-scheme APIs where available.
- Added a fallback palette implementation for systems without those APIs.
- Added light-theme header styling.
- Preserved system palette restoration when switching back to System.

## Logging

- Added a dedicated **Log** tab.
- Added structured log columns for:
  - number;
  - timestamp;
  - event;
  - type;
  - key;
  - detail;
  - status.
- Added automatic log loading.
- Added automatic scrolling to the newest entry.
- Added **Delete Log**.
- Added confirmation before deleting the complete log.
- Added **Copy Log** to copy the complete log to the clipboard.
- Added handling for missing or empty log files.
- Added error reporting when the log cannot be read or deleted.
- Added configurable log-size limiting and trimming.
- Added optional clearing of the log when the application starts.

## Application Information

- Added a dedicated `app_info.py` module.
- Centralised:
  - application name;
  - version;
  - author;
  - company;
  - description;
  - copyright;
  - GitHub address;
  - licence;
  - build date.
- Added an **About** tab.
- Added version and build-date display.
- Added the current date.
- Added application description and feature summary.
- Added author information.
- Added a clickable GitHub link.
- Added MIT licence information.
- Added a Development build-date fallback when generated build information is unavailable.

## Windows Build and Executable Metadata

- Added `build_SM64.bat`.
- Added generation of build information during compilation.
- Added `make_version_info.py`.
- Added generation of `version_info.txt`.
- Added PyInstaller `--version-file` integration.
- Added Windows executable version metadata.
- Added product name, file description, company, copyright, and version information.
- Added UK English language metadata to the Windows version resource.
- Kept the test executable name configurable through `APP_NAME` in the build script.
- Added a repeatable build-and-test workflow.

## Reliability and Lifecycle

- Added single-instance enforcement using a Windows mutex.
- Prevented multiple copies of Startup Monitor from running simultaneously.
- Added clean application shutdown.
- Added timer and window cleanup.
- Improved handling of Review-window closure and cancellation.
- Prevented duplicate pending review items.
- Added safer file and configuration error handling.
- Added engine reloads after relevant Settings changes.
- Ensured baseline and Allowed/Denied changes are persisted before reloading.
- Improved runtime diagnostics during the conversion and corrected a temporary damaged `apply_changes()` section.

## Code Organisation and Maintainability

- Centralised numeric option metadata in `NUMERIC_OPTIONS`.
- Centralised checkbox option metadata in `CHECKBOX_OPTIONS`.
- Reused this metadata for:
  - UI construction;
  - validation;
  - default restoration.
- Added a shared confirmation-panel builder.
- Added a shared yellow path-information-panel builder.
- Added a shared checked-column value extractor.
- Added shared Allowed/Denied table population.
- Added shared action-table configuration.
- Added shared **Copy Path** handling.
- Added shared checkbox and selection signal wiring.
- Added a shared standard action context menu.
- Added a shared Base Startup/Base Tasks row builder.
- Added a shared Base Startup/Base Tasks table builder.
- Added shared Base path-display handling.
- Added shared path-information reset handling.
- Added a shared Remove-button row builder.
- Added shared Allowed/Denied tab construction.
- Added shared Allowed/Denied removal-request handling.
- Added shared Allowed/Denied removal-confirmation handling.
- Added shared Allowed/Denied cancellation handling.
- Removed confirmed unused imports.
- Removed an unused dictionary-table attribute.
- Removed an unused scanner import.
- Reduced repeated code while retaining the same layout and functionality.
