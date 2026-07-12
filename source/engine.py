from __future__ import annotations

import os
import threading
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Iterable, List

from config_store import ConfigStore, Paths
from scanners import delete_registry_value, delete_task, scan_folders, scan_registry, scan_tasks, stable_hash


@dataclass
class ReviewItem:
    key: str
    display_name: str
    item_type: str
    detail: str
    status: str
    item_hash: str
    allowed: bool


class MonitorEngine:
    def __init__(self, store: ConfigStore, paths: Paths) -> None:
        self.store = store
        self.paths = paths
        self.lock = threading.RLock()
        self.cancelled: Dict[str, datetime] = {}
        self.settings: Dict[str, str] = {}
        self.folders: Dict[str, str] = {}
        self.registry_tokens: Dict[str, str] = {}
        self.allowed: Dict[str, str] = {}
        self.denied: Dict[str, str] = {}
        self.base_folders: Dict[str, str] = {}
        self.base_registry: Dict[str, str] = {}
        self.base_tasks: Dict[str, str] = {}
        self.cached_tasks: Dict[str, str] = {}
        self.last_task_scan = datetime.min
        self.reload_all(create_baselines=True)
        self.initialise_logging()

    def reload_all(self, create_baselines: bool = False) -> None:
        with self.lock:
            self.settings = self.store.load_settings()
            self.folders, self.registry_tokens = self.store.load_locations()
            self.allowed, self.denied = self.store.load_allowed_denied()
            if create_baselines:
                self.create_baselines_if_needed()
            self.base_folders, self.base_registry, self.base_tasks = self.store.load_baselines()

    def create_baselines_if_needed(self) -> None:
        if self.settings.get("PersistentBaseline", "1") != "1":
            return
        if not self.paths.base_startup.exists():
            folders = scan_folders(self.folders)
            registry = scan_registry(self.registry_tokens) if self.settings.get("Registry", "1") == "1" else {}
            self.store.save_startup_baseline(folders, registry)
        if self.settings.get("MonitorTasks", "1") == "1" and not self.paths.base_tasks.exists():
            tasks = scan_tasks()
            task_hashes = {name: stable_hash(f"{name}|{command}") for name, command in tasks.items()}
            self.store.save_task_baseline(task_hashes)

    def initialise_logging(self) -> None:
        if self.settings.get("ClearLogOnStart", "0") == "1":
            self.paths.log.write_text(
                "",
                encoding="utf-8",
            )
            return

        if not self.paths.log.exists():
            return

        cutoff = datetime.now() - timedelta(days=30)
        kept: List[str] = []

        for line in self.paths.log.read_text(
            encoding="utf-8",
            errors="replace",
        ).splitlines():
            try:
                timestamp = datetime.strptime(
                    line[:19],
                    "%Y-%m-%d %H:%M:%S",
                )
            except ValueError:
                continue

            if timestamp >= cutoff:
                kept.append(line)

        self.paths.log.write_text(
            "\n".join(kept) + ("\n" if kept else ""),
            encoding="utf-8",
        )

        self._trim_log_to_size()

    def _trim_log_to_size(self) -> None:
        maximum_size = 1024 * 1024
        target_size = 750 * 1024

        if not self.paths.log.exists():
            return

        try:
            if self.paths.log.stat().st_size <= maximum_size:
                return

            lines = self.paths.log.read_bytes().splitlines(
                keepends=True
            )
        except OSError:
            return

        kept_lines: List[bytes] = []
        kept_size = 0

        for line in reversed(lines):
            line_size = len(line)

            if kept_size + line_size > target_size:
                break

            kept_lines.append(line)
            kept_size += line_size

        kept_lines.reverse()

        try:
            self.paths.log.write_bytes(
                b"".join(kept_lines)
            )
        except OSError:
            return

    def log(
        self,
        event: str,
        item_type: str,
        key: str,
        detail: str,
        status: str,
    ) -> None:
        timestamp = datetime.now().strftime(
            "%Y-%m-%d %H:%M:%S"
        )
        safe = [
            part.replace("\r", " ").replace("\n", " ")
            for part in (
                event,
                item_type,
                key,
                detail,
                status,
            )
        ]

        with self.lock:
            with self.paths.log.open(
                "a",
                encoding="utf-8",
            ) as handle:
                handle.write(
                    f"{timestamp} | {' | '.join(safe)}\n"
                )

            self._trim_log_to_size()

    def monitor_tick(self) -> List[ReviewItem]:
        with self.lock:
            self.allowed, self.denied = self.store.load_allowed_denied()
            self._clean_cancelled()
            current_files = scan_folders(self.folders)
            current_registry = scan_registry(self.registry_tokens) if self.settings.get("Registry", "1") == "1" else {}
            current_tasks = self._current_tasks()

            items: List[ReviewItem] = []
            for key, item_hash in current_files.items():
                self._process_item(items, key, Path(key).name, "file", key, item_hash, self.base_folders)
            for key, item_hash in current_registry.items():
                display = key.rsplit("|", 1)[-1] or "(Default)"
                self._process_item(items, key, display, "reg", key, item_hash, self.base_registry)
            for name, command in current_tasks.items():
                item_hash = stable_hash(f"{name}|{command}")
                self._process_item(items, name, name, "task", command, item_hash, self.base_tasks)

            if self.settings.get("ShowReview", "1") == "0":
                remaining: List[ReviewItem] = []
                for item in items:
                    if item.key in self.denied:
                        self.remove_item(item)
                    elif item.key not in self.allowed:
                        remaining.append(item)
                items = remaining
            return items

    def _current_tasks(self) -> Dict[str, str]:
        if self.settings.get("MonitorTasks", "1") != "1":
            return {}
        interval = int(self.settings.get("MonitorTimeTasks", "60000"))
        elapsed_ms = (datetime.now() - self.last_task_scan).total_seconds() * 1000
        if not self.cached_tasks or elapsed_ms >= interval:
            self.cached_tasks = scan_tasks()
            self.last_task_scan = datetime.now()
        return dict(self.cached_tasks)

    def _process_item(
        self,
        output: List[ReviewItem],
        key: str,
        display_name: str,
        item_type: str,
        detail: str,
        item_hash: str,
        baseline: Dict[str, str],
    ) -> None:
        if key in self.cancelled:
            return
        default_allowed = self.settings.get("DefaultCheckReviewItems", "1") == "1"

        if key in self.allowed:
            if self.allowed[key] == item_hash:
                return
            self.log("DETECT_MODIFIED", item_type, key, detail, "ALLOWED_ITEM_MODIFIED")
            output.append(ReviewItem(key, display_name, item_type, detail, "Modified", item_hash, True))
            return

        if key in self.denied:
            status = "Denied item reappeared" if self.denied[key] == item_hash else "Denied item recreated"
            event = "DETECT_DENIED_REAPPEARED" if self.denied[key] == item_hash else "DETECT_RECREATED"

            if self.settings.get("NotifyDeniedAgain", "1") != "1":
                item = ReviewItem(
                    key=key,
                    display_name=display_name,
                    item_type=item_type,
                    detail=detail,
                    status=status,
                    item_hash=item_hash,
                    allowed=False,
                )
                self.log(event, item_type, key, detail, "AUTO_DELETE")
                self.remove_item(item)
                return

            self.log(event, item_type, key, detail, status.upper().replace(" ", "_"))
            output.append(ReviewItem(key, display_name, item_type, detail, status, item_hash, False))
            return

        if key in baseline:
            if baseline[key] == item_hash:
                return
            self.log("DETECT_MODIFIED", item_type, key, detail, "BASELINE_ITEM_MODIFIED")
            output.append(ReviewItem(key, display_name, item_type, detail, "Modified", item_hash, default_allowed))
            return

        self.log("DETECT_NEW", item_type, key, detail, "NEW_ITEM")
        output.append(ReviewItem(key, display_name, item_type, detail, "New", item_hash, default_allowed))

    def commit_review(self, items: Iterable[ReviewItem]) -> None:
        with self.lock:
            for item in items:
                if item.allowed:
                    self.allowed[item.key] = item.item_hash
                    self.denied.pop(item.key, None)
                    self.log("REVIEW_ALLOW", item.item_type, item.key, item.detail, "SUCCESS")
                else:
                    self.denied[item.key] = item.item_hash
                    self.allowed.pop(item.key, None)
                    self.remove_item(item)
            self.store.save_allowed_denied(self.allowed, self.denied)

    def cancel_review(self, items: Iterable[ReviewItem]) -> None:
        expiry = datetime.now() + timedelta(minutes=60)
        with self.lock:
            for item in items:
                self.cancelled[item.key] = expiry
                self.log("REVIEW_CANCEL", item.item_type, item.key, item.detail, "SUPPRESSED_60_MINUTES")

    def _clean_cancelled(self) -> None:
        now = datetime.now()
        self.cancelled = {key: expiry for key, expiry in self.cancelled.items() if expiry > now}

    def remove_item(self, item: ReviewItem) -> bool:
        success = False
        if item.item_type == "file":
            try:
                path = Path(item.key)
                if path.exists():
                    path.unlink()
                success = not path.exists()
            except OSError:
                success = False
        elif item.item_type == "reg":
            success = delete_registry_value(item.key)
        elif item.item_type == "task":
            success = delete_task(item.key)
            if success:
                self.cached_tasks.pop(item.key, None)
        self.log(f"REMOVE_{item.item_type.upper()}", item.item_type, item.key, item.detail, "SUCCESS" if success else "FAILED")
        return success
