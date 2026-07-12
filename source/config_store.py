from __future__ import annotations

import configparser
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Tuple


def application_directory() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class Paths:
    root: Path
    app: Path
    settings: Path
    locations: Path
    allowed: Path
    denied: Path
    log: Path
    base_startup: Path
    base_tasks: Path
    icon: Path

    @classmethod
    def create(cls) -> "Paths":
        root = application_directory()
        app = root / "App"
        source_icon = root / "source" / "StartupMonitor.ico"
        bundled_icon = Path(getattr(sys, "_MEIPASS", root)) / "StartupMonitor.ico"
        icon = source_icon if source_icon.exists() else bundled_icon
        return cls(
            root=root,
            app=app,
            settings=app / "Settings.ini",
            locations=app / "Locations.ini",
            allowed=app / "Allowed.ini",
            denied=app / "Denied.ini",
            log=app / "Log.ini",
            base_startup=app / "BaseStartup.ini",
            base_tasks=app / "BaseTasks.ini",
            icon=icon,
        )


DEFAULT_SETTINGS = {
    "Options": {
        "DefaultCheckReviewItems": "1",
        "ClearLogOnStart": "0",
        "MonitorTime": "3000",
        "MonitorTimeTasks": "60000",
        "PersistentBaseline": "1",
        "MonitorTasks": "1",
        "Registry": "1",
        "ShowReview": "1",
        "NotifyDeniedAgain": "1",
    },
    "GUI": {
        "ReviewWindowWidth": "700",
        "ReviewWindowHeight": "450",
        "Theme": "System",
    },
}

DEFAULT_LOCATIONS = {
    "Folders": {
        r"%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup": "1",
        r"%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup": "1",
    },
    "Registry": {
        "HKCU_Run": "1",
        "HKLM_Run": "1",
        "HKCU_RunOnce": "1",
        "HKLM_RunOnce": "1",
        "HKCU_Explorer_ShellFolders": "1",
        "HKLM_Explorer_ShellFolders": "1",
        "HKCU_Explorer_UserShellFolders": "1",
        "HKLM_Explorer_UserShellFolders": "1",
        "HKCU_RunServicesOnce": "1",
        "HKLM_RunServicesOnce": "1",
        "HKCU_RunServices": "1",
        "HKLM_RunServices": "1",
        "HKCU_Policies_Explorer_Run": "1",
        "HKLM_Policies_Explorer_Run": "1",
        "HKCU_Windows": "1",
        "HKLM_Winlogon_Userinit": "1",
        "HKLM_Winlogon_Shell": "1",
        "HKLM_SessionManager": "1",
    },
}


class ConfigStore:
    def __init__(self, paths: Paths) -> None:
        self.paths = paths
        self.ensure_structure()

    @staticmethod
    def _parser() -> configparser.ConfigParser:
        parser = configparser.ConfigParser(
            interpolation=None,
            strict=False,
            delimiters=("=",),
        )
        parser.optionxform = str
        return parser

    def ensure_structure(self) -> None:
        self.paths.app.mkdir(parents=True, exist_ok=True)
        if not self.paths.settings.exists():
            self._write_sections(self.paths.settings, DEFAULT_SETTINGS)
        if not self.paths.locations.exists():
            self._write_sections(self.paths.locations, DEFAULT_LOCATIONS)
        if not self.paths.allowed.exists():
            self._write_sections(self.paths.allowed, {"Allowed": {}})
        if not self.paths.denied.exists():
            self._write_sections(self.paths.denied, {"Denied": {}})
        if not self.paths.log.exists():
            self.paths.log.write_text("", encoding="utf-8")

    def _read(self, path: Path) -> configparser.ConfigParser:
        parser = self._parser()
        if path.exists():
            parser.read(path, encoding="utf-8")
        return parser

    def _write(self, path: Path, parser: configparser.ConfigParser) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_suffix(path.suffix + ".tmp")
        with temp.open("w", encoding="utf-8", newline="") as handle:
            parser.write(handle, space_around_delimiters=False)
        os.replace(temp, path)

    def _write_sections(self, path: Path, sections: Dict[str, Dict[str, str]]) -> None:
        parser = self._parser()
        for section, values in sections.items():
            parser[section] = values
        self._write(path, parser)

    def load_settings(self) -> Dict[str, str]:
        parser = self._read(self.paths.settings)
        changed = False
        for section, defaults in DEFAULT_SETTINGS.items():
            if not parser.has_section(section):
                parser.add_section(section)
                changed = True
            for key, value in defaults.items():
                if not parser.has_option(section, key):
                    parser.set(section, key, value)
                    changed = True
        if changed:
            self._write(self.paths.settings, parser)

        result: Dict[str, str] = {}
        for section in parser.sections():
            result.update(dict(parser.items(section)))
        result["MonitorTime"] = str(max(1500, min(60000, int(result.get("MonitorTime", "3000")))))
        result["MonitorTimeTasks"] = str(max(10000, min(3600000, int(result.get("MonitorTimeTasks", "60000")))))
        return result

    def save_settings(self, settings: Dict[str, str]) -> None:
        parser = self._read(self.paths.settings)
        for section in DEFAULT_SETTINGS:
            if not parser.has_section(section):
                parser.add_section(section)
        option_keys = set(DEFAULT_SETTINGS["Options"])
        gui_keys = set(DEFAULT_SETTINGS["GUI"])
        for key, value in settings.items():
            if key in option_keys:
                parser.set("Options", key, str(value))
            elif key in gui_keys:
                parser.set("GUI", key, str(value))
        self._write(self.paths.settings, parser)

    def load_locations(self) -> Tuple[Dict[str, str], Dict[str, str]]:
        parser = self._read(self.paths.locations)
        folders = dict(parser.items("Folders")) if parser.has_section("Folders") else {}
        registry = dict(parser.items("Registry")) if parser.has_section("Registry") else {}
        return folders, registry

    def save_locations(self, folders: Dict[str, str], registry: Dict[str, str]) -> None:
        self._write_sections(self.paths.locations, {"Folders": folders, "Registry": registry})

    def load_allowed_denied(self) -> Tuple[Dict[str, str], Dict[str, str]]:
        allowed_parser = self._read(self.paths.allowed)
        denied_parser = self._read(self.paths.denied)
        allowed = dict(allowed_parser.items("Allowed")) if allowed_parser.has_section("Allowed") else {}
        denied = dict(denied_parser.items("Denied")) if denied_parser.has_section("Denied") else {}
        return allowed, denied

    def save_allowed_denied(self, allowed: Dict[str, str], denied: Dict[str, str]) -> None:
        self._write_sections(self.paths.allowed, {"Allowed": allowed})
        self._write_sections(self.paths.denied, {"Denied": denied})

    def load_baselines(self) -> Tuple[Dict[str, str], Dict[str, str], Dict[str, str]]:
        startup = self._read(self.paths.base_startup)
        tasks = self._read(self.paths.base_tasks)
        folders = dict(startup.items("Folders")) if startup.has_section("Folders") else {}
        registry = dict(startup.items("Registry")) if startup.has_section("Registry") else {}
        task_items = dict(tasks.items("BaseTasks")) if tasks.has_section("BaseTasks") else {}
        return folders, registry, task_items

    def save_startup_baseline(self, folders: Dict[str, str], registry: Dict[str, str]) -> None:
        self._write_sections(self.paths.base_startup, {"Folders": folders, "Registry": registry})

    def save_task_baseline(self, tasks: Dict[str, str]) -> None:
        self._write_sections(self.paths.base_tasks, {"BaseTasks": tasks})
