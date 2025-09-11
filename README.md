# Startup-Monitor-64
Monitors system folders and registry entries for changes.

## Overview

This Windows tray application monitors system startup locations, scheduled tasks, and registry entries for changes or new items. It alerts the user to new startup entries, lets the user approve or deny them, and provides options for logging and deletion. All configuration and log files are stored in a dedicated `App` folder within the application's directory.

---

## Features

- **Monitors**:
  - User-specified startup folders (e.g. Startup menus).
  - Scheduled tasks (Windows Task Scheduler).
  - Registry locations (stubbed, expandable).
  - Locations can be enabled/disabled on a per-item basis.
- **Allows/Denies**:
  - New entries alert the user with a review GUI.
  - User can allow (approve) or deny (block/delete) new items.
  - Denied items are deleted after confirmation.
- **Persistence**:
  - Baseline snapshot on first run (never updated except on reset).
  - Tracks Allowed and Denied items separately for user decisions.
- **Logging**:
  - All actions are logged to `Log.ini`.
- **Tray Menu**:
  - Open settings
  - Exit

---

## Folder and File Structure

All files are created in:  
`[AppFolder]\App`

| File Name           | Purpose                                                                   |
|---------------------|---------------------------------------------------------------------------|
| Allowed.ini         | User-allowed startup/scheduled task items                                 |
| Denied.ini          | User-denied startup/scheduled task items                                  |
| Log.ini             | Log of all actions                                                        |
| Settings.ini        | App settings/configuration                                                |
| BaseStartup.ini     | Baseline snapshot of startup items at first run                           |
| BaseTasks.ini       | Baseline snapshot of scheduled tasks at first run                         |
| Locations.ini       | List of monitored locations (folders and registry keys)                   |

---

## Usage

1. **First Run**  
   - Creates the `App` folder and all required files with default values.
   - Takes baseline snapshots of startup folders and scheduled tasks.

2. **Monitoring**  
   - The app polls monitored locations at the interval set in Settings GUI: MonitorTime, default: 3000ms.
   - Finds new items, compares them to baseline and Allowed/Denied lists, reports to user.

3. **Review GUI**  
   - New or changed items open a review dialog with checkboxes:
     - **Checked**: Item will be added to Allowed.ini (approved)
     - **Unchecked**: Item will be added to Denied.ini (blocked/deleted)
   - Denied items are deleted after a single confirmation messagebox.
   - Export List: This exports a full list of items shown in the Review GUI.

4. **Tray Menu Functions**
   - Open settings
   - Exit

---

## Customising Monitored Locations

Edit `Locations.ini` to add or remove folders/registry keys to be monitored.  
- Folders: Under `[Folders]` section, one path per line, append `=1` to enable, `=0` to disable.
- Registry: Under `[Registry]` section, one key per line, append `=1` to enable.

Example:
```
[Folders]
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup=1
[Registry]
HKCU_RunOnce=1
```

---

# Settings GUI – Options & Functionality

Edit `Settings.ini` to adjust app behavior, or use the Settings window which covers all functionality.

## **Settings Overview**
## **Main Settings Options**

---

The Settings GUI allows users to configure monitoring behavior, baseline creation, logging preferences, review window layout, and manage advanced lists such as Locations, Allowed, and Denied.

---

## **Main Options**
The Settings GUI features several tabs that allow for detailed configuration and management of monitored startup items.

## **Tabs & Advanced Lists**

### **1. Options Tab**

| Option                            | Description                                                                          | Values / Range                |
|-----------------------------------|--------------------------------------------------------------------------------------|-------------------------------|
| **Monitor Interval**              | Controls how often the application performs monitoring scans.                        | 1000–60000 ms (1–60 sec)      |
| **Clear Log File Start**          | Whether to create a new log file on each startup.                                    | Checkbox (On/Off)             |
| **Persistent Baseline**           | Creates a baseline of existing startup items on first run to reduce false alerts.    | Checkbox (On/Off)             |
| **Monitor Scheduled Tasks**       | When enabled, scheduled tasks are included in the monitoring process.                | Checkbox (On/Off)             |
| **Monitor Registry Startup**      | Monitors registry keys for startup programs. Disable for folder monitoring only.     | Checkbox (On/Off)             |
| **Review Window Width**           | Sets the width of the review window.                                                 | 400–1600 pixels               |
| **Review Window Height**          | Sets the height of the review window.                                                | 200–900 pixels                |
| **Reset to Defaults**             | Restores all settings to their default values.                                       | Button                        |
| **Open Settings Folder**          | Opens the folder containing application settings for manual review or backup.        | Button                        |

---

### **2. Locations Tab**
- **Use Locations Tab** to tailor what areas of the system are monitored—add, remove, or edit to suit your needs. You can use this to monitor any folder or registry key for changes, other than startup.

- **Purpose:**  
  Manage the startup locations that are monitored for changes. These locations typically include registry keys, file paths, and scheduled tasks.
- **How to Use:**  
  - **List View:** See all locations currently being monitored. Use checkboxes to enable/disable that item. Changes saved immediately.
  - **Add Registry:** Add a new registry startup location to monitor. Use the "Open RegEdit" button, then use RegEdit to brwose to your location. Copy the desired path into the edit field, then click "Add Registry" button to add to the list.
  - **Remove:** Remove a location if you do not wish to monitor it. A confirmation message appears at the bottom of the window with OK/Cancel buttons.
  - **Edit:** Modify an existing location's settings. Click an existing entry to populate the Edit field. Edit the path, then click "Edit" button to save the changes.
- **Typical Locations:**  
  - Registry keys like `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`
  - Startup folders
  - Windows Scheduled Tasks

- **Default Locations:**
```
[Folders]
C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\
C:\Users\<Username>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup

[Registry]
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RunOnce
HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run
HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders
HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce
HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunServices
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RunServices
HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run
HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\Userinit
HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\Shell
HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Windows
HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager
```
---

### **3. Allowed Tab**

- **Purpose:**  
  Manage the list of startup items that are explicitly allowed. Items in this list will not trigger alerts or warnings.
- **How to Use:**  
  - **Remove:** Remove items that are no longer trusted. Select item in the list view, click "Remove" button. Review the confirmation at the bottom of the window and select OK/Cancel as desired.
  - **Refresh:** Refreshes list. Unlikely to be required as changes are applied immediately, but, just in case!
- **Use Case:**  
  For trusted programs you know and want to keep running at startup.

---

### **4. Denied Tab**

- **Purpose:**  
  Manage the list of startup items that are explicitly denied. Any item matching entries in this list will trigger alerts and may be blocked.
- **How to Use:**  
  - **Remove:** Remove entries if a program is no longer considered a threat. Select item in the list view, click "Remove" button. Review the confirmation at the bottom of the window and select OK/Cancel as desired.
  - **Refresh:** Refreshes list. Unlikely to be required as changes are applied immediately, but, just in case!
- **Use Case:**  
  For known threats, unwanted software, or items you want to prevent from running at startup.

---

### **5. Other Tabs**

Additional tabs for advanced settings, such as:
- **Baseline:**  View and manage the persistent baseline of startup items.  
  - **Use:** See which items were present during initial setup and adjust baseline as needed.
- **Log:**  View logging details, such as log file path and retention. Delete existing log to start afresh. You can select and use Ctrl+C to copy selected text.

---

## **Managing Tabs Effectively**

- **Use Allowed and Denied Tabs** to fine-tune which startup items are permitted or blocked. For example if a review was accidentally accepted or denied, you can amend here.
- **Review Baseline** periodically to ensure new legitimate items are included, and old ones are removed.
- **Consult Log Tab** for troubleshooting or audit purposes.

---

## **Typical Usage Flow**

1. **Configure monitoring frequency and targets** in Main Settings.
2. **Review Locations Tab**—add or remove monitored areas.
3. **Populate Allowed Tab** with trusted items to reduce unnecessary alerts.
4. **Populate Denied Tab** with unwanted or suspicious items for proactive blocking.
5. **Check Baseline and Log Tabs** for additional control and troubleshooting.
6. **Save and exit**—settings take effect immediately.

---

## **Notes**

- Invalid values prompt warnings and revert to previous/default settings.
- The GUI is fixed-size and cannot be resized by dragging.
- All changes are saved automatically unless otherwise specified.

---

For further support or questions, contact the repository maintainer.

---

## Extending Functionality

- **Registry Monitoring**: Stubbed; expand using AutoIt's RegEnum/RegRead functions.
- **Scheduled Task Deletion**: Expand `_DeleteItem` to use schtasks.exe or WMI if desired.
- **Settings GUI**: Developed for full configuration editing.

---

## Building & Running

1. Requires [AutoIt](https://www.autoitscript.com/site/autoit/) v3.3.16.1 (x64 only).
2. Place all `.au3` files in the same directory.
3. Run `StartupMonitor.au3`.

---

## Maintenance & Expansion

- Modular file structure for easy maintenance and extension.
- Add new modules or expand registry/task support as needed.
- All user settings and logs are kept within the `App` folder for portability.

---

## License

MIT

---
