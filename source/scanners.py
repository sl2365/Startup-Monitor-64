from __future__ import annotations

import csv
import hashlib
import io
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

try:
    import winreg
except ImportError:  # Allows syntax checking on non-Windows systems.
    winreg = None  # type: ignore


@dataclass(frozen=True)
class RegistryTarget:
    hive_name: str
    subkey: str
    value_name: Optional[str] = None


REGISTRY_TARGETS: Dict[str, RegistryTarget] = {
    "HKCU_Run": RegistryTarget("HKCU", r"Software\Microsoft\Windows\CurrentVersion\Run"),
    "HKLM_Run": RegistryTarget("HKLM", r"Software\Microsoft\Windows\CurrentVersion\Run"),
    "HKCU_RunOnce": RegistryTarget("HKCU", r"Software\Microsoft\Windows\CurrentVersion\RunOnce"),
    "HKLM_RunOnce": RegistryTarget("HKLM", r"Software\Microsoft\Windows\CurrentVersion\RunOnce"),
    "HKCU_Explorer_UserShellFolders": RegistryTarget("HKCU", r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"),
    "HKCU_Explorer_ShellFolders": RegistryTarget("HKCU", r"Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"),
    "HKLM_Explorer_ShellFolders": RegistryTarget("HKLM", r"Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"),
    "HKLM_Explorer_UserShellFolders": RegistryTarget("HKLM", r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"),
    "HKLM_RunServicesOnce": RegistryTarget("HKLM", r"Software\Microsoft\Windows\CurrentVersion\RunServicesOnce"),
    "HKCU_RunServicesOnce": RegistryTarget("HKCU", r"Software\Microsoft\Windows\CurrentVersion\RunServicesOnce"),
    "HKLM_RunServices": RegistryTarget("HKLM", r"Software\Microsoft\Windows\CurrentVersion\RunServices"),
    "HKCU_RunServices": RegistryTarget("HKCU", r"Software\Microsoft\Windows\CurrentVersion\RunServices"),
    "HKLM_Policies_Explorer_Run": RegistryTarget("HKLM", r"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"),
    "HKCU_Policies_Explorer_Run": RegistryTarget("HKCU", r"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"),
    "HKLM_Winlogon_Userinit": RegistryTarget("HKLM", r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "Userinit"),
    "HKLM_Winlogon_Shell": RegistryTarget("HKLM", r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "Shell"),
    "HKCU_Windows": RegistryTarget("HKCU", r"Software\Microsoft\Windows\CurrentVersion\Windows"),
    "HKLM_SessionManager": RegistryTarget("HKLM", r"System\CurrentControlSet\Control\Session Manager"),
}


def stable_hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8", errors="replace")).hexdigest()[:16].upper()


def scan_folders(locations: Dict[str, str]) -> Dict[str, str]:
    results: Dict[str, str] = {}
    for template, enabled in locations.items():
        if enabled != "1":
            continue
        folder = Path(os.path.expandvars(template))
        if not folder.is_dir():
            continue
        try:
            for entry in folder.iterdir():
                if entry.is_file():
                    key = str(entry.resolve())
                    results[key] = stable_hash(key)
        except (OSError, PermissionError):
            continue
    return results


def _hive(name: str):
    if winreg is None:
        raise RuntimeError("Registry scanning is available only on Windows.")
    return winreg.HKEY_CURRENT_USER if name == "HKCU" else winreg.HKEY_LOCAL_MACHINE


def _registry_views() -> Iterable[int]:
    if winreg is None:
        return []
    return (winreg.KEY_WOW64_64KEY, winreg.KEY_WOW64_32KEY)


def _registry_target_from_location(
    location: str,
) -> Optional[RegistryTarget]:
    if location in REGISTRY_TARGETS:
        return REGISTRY_TARGETS[location]

    cleaned = location.strip()

    if cleaned.lower().startswith("computer\\"):
        cleaned = cleaned[9:]

    prefixes = (
        ("HKEY_CURRENT_USER\\", "HKCU"),
        ("HKEY_LOCAL_MACHINE\\", "HKLM"),
        ("HKCU\\", "HKCU"),
        ("HKLM\\", "HKLM"),
    )

    upper_cleaned = cleaned.upper()

    for prefix, hive_name in prefixes:
        if upper_cleaned.startswith(prefix):
            subkey = cleaned[len(prefix):].strip("\\")

            if not subkey:
                return None

            return RegistryTarget(
                hive_name=hive_name,
                subkey=subkey,
            )

    return None


def scan_registry(tokens: Dict[str, str]) -> Dict[str, str]:
    if winreg is None:
        return {}

    results: Dict[str, str] = {}

    for location, enabled in tokens.items():
        if enabled != "1":
            continue

        target = _registry_target_from_location(location)

        if target is None:
            continue

        for view in _registry_views():
            try:
                with winreg.OpenKey(
                    _hive(target.hive_name),
                    target.subkey,
                    0,
                    winreg.KEY_READ | view,
                ) as key:
                    if target.value_name is not None:
                        data, _kind = winreg.QueryValueEx(
                            key,
                            target.value_name,
                        )
                        full_key = (
                            f"{target.hive_name}\\"
                            f"{target.subkey}|"
                            f"{target.value_name}"
                        )
                        results[full_key] = stable_hash(
                            f"{full_key}|{data}"
                        )
                    else:
                        index = 0

                        while True:
                            try:
                                value_name, data, _kind = (
                                    winreg.EnumValue(key, index)
                                )
                            except OSError:
                                break

                            full_key = (
                                f"{target.hive_name}\\"
                                f"{target.subkey}|"
                                f"{value_name}"
                            )
                            results[full_key] = stable_hash(
                                f"{full_key}|{data}"
                            )
                            index += 1

                break
            except (
                FileNotFoundError,
                PermissionError,
                OSError,
            ):
                continue

    return results


def scan_tasks() -> Dict[str, str]:
    command = ["schtasks", "/query", "/fo", "CSV", "/v"]
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            timeout=120,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {}
    if completed.returncode != 0 or not completed.stdout.strip():
        return {}

    reader = csv.DictReader(io.StringIO(completed.stdout))
    results: Dict[str, str] = {}
    for row in reader:
        task_name = _first_value(row, "TaskName", "Task Name")
        task_command = _first_value(row, "Task To Run", "Actions", "Action")
        if task_name and task_command:
            results[task_name] = task_command
    return results


def _first_value(row: Dict[str, str], *names: str) -> str:
    lowered = {str(key).strip().lower(): (value or "").strip() for key, value in row.items()}
    for name in names:
        value = lowered.get(name.lower(), "")
        if value:
            return value
    return ""


def delete_registry_value(key_spec: str) -> bool:
    if winreg is None or "|" not in key_spec:
        return False
    path, value_name = key_spec.rsplit("|", 1)
    if "\\" not in path:
        return False
    hive_name, subkey = path.split("\\", 1)
    for view in _registry_views():
        try:
            with winreg.OpenKey(_hive(hive_name), subkey, 0, winreg.KEY_SET_VALUE | view) as key:
                winreg.DeleteValue(key, value_name)
            return True
        except (FileNotFoundError, PermissionError, OSError):
            continue
    return False


def delete_task(task_name: str) -> bool:
    try:
        completed = subprocess.run(
            ["schtasks", "/delete", "/tn", task_name, "/f"],
            capture_output=True,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            timeout=60,
            check=False,
        )
        return completed.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False
