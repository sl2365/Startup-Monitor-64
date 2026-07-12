from __future__ import annotations

import ctypes
import os
import sys
import threading
import time
from pathlib import Path
from typing import Optional

from PySide6.QtCore import QObject, Signal
from PySide6.QtGui import QAction, QIcon
from PySide6.QtWidgets import QApplication, QMenu, QMessageBox, QSystemTrayIcon

from app_info import APP_NAME
from config_store import ConfigStore, Paths
from engine import MonitorEngine
from gui import ApplicationUI, apply_theme


SINGLE_INSTANCE_MUTEX = (
    "Local\\StartupMonitor64_sl23_SingleInstance"
)
ERROR_ALREADY_EXISTS = 183


def acquire_single_instance_mutex() -> Optional[int]:
    create_mutex = ctypes.windll.kernel32.CreateMutexW
    create_mutex.argtypes = [
        ctypes.c_void_p,
        ctypes.c_bool,
        ctypes.c_wchar_p,
    ]
    create_mutex.restype = ctypes.c_void_p

    handle = create_mutex(
        None,
        False,
        SINGLE_INSTANCE_MUTEX,
    )

    if not handle:
        raise ctypes.WinError()

    if (
        ctypes.windll.kernel32.GetLastError()
        == ERROR_ALREADY_EXISTS
    ):
        ctypes.windll.kernel32.CloseHandle(handle)
        return None

    return int(handle)


def release_single_instance_mutex(
    handle: Optional[int],
) -> None:
    if handle is None:
        return

    ctypes.windll.kernel32.CloseHandle(
        ctypes.c_void_p(handle)
    )


def is_admin() -> bool:
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def relaunch_as_admin() -> bool:
    if getattr(sys, "frozen", False):
        executable = sys.executable
        parameters = " ".join(f'"{arg}"' for arg in sys.argv[1:])
    else:
        executable = sys.executable
        parameters = " ".join([f'"{Path(__file__).resolve()}"', *[f'"{arg}"' for arg in sys.argv[1:]]])
    result = ctypes.windll.shell32.ShellExecuteW(None, "runas", executable, parameters, None, 1)
    return result > 32


class MonitorBridge(QObject):
    review_detected = Signal(object)


class StartupMonitorApp:
    def __init__(self, qt_app: QApplication) -> None:
        self.qt_app = qt_app
        self.paths = Paths.create()
        self.store = ConfigStore(self.paths)
        self.engine = MonitorEngine(
            self.store,
            self.paths,
        )

        apply_theme(
            self.qt_app,
            self.engine.settings.get(
                "Theme",
                "System",
            ),
        )

        self.stop_event = threading.Event()
        self.paused_event = threading.Event()

        self.ui = ApplicationUI(
            self.engine,
            self.store,
            self.paths,
            self.toggle_monitoring,
            self.is_monitoring_paused,
        )

        self.bridge = MonitorBridge()
        self.bridge.review_detected.connect(
            self.ui.enqueue_review
        )

        self.worker = threading.Thread(
            target=self._monitor_loop,
            name="StartupMonitorWorker",
            daemon=True,
        )

        self.tray: Optional[QSystemTrayIcon] = None
        self.pause_action: Optional[QAction] = None

    def run(self) -> int:
        self._start_tray()
        self.worker.start()
        return self.qt_app.exec()

    def _monitor_loop(self) -> None:
        while not self.stop_event.is_set():
            if self.paused_event.is_set():
                self.stop_event.wait(0.25)
                continue

            started = time.monotonic()

            try:
                items = self.engine.monitor_tick()

                if items:
                    self.bridge.review_detected.emit(items)
            except Exception as exc:
                self.engine.log(
                    "MONITOR_ERROR",
                    "engine",
                    type(exc).__name__,
                    str(exc),
                    "FAILED",
                )

            interval = (
                int(
                    self.engine.settings.get(
                        "MonitorTime",
                        "3000",
                    )
                )
                / 1000.0
            )
            elapsed = time.monotonic() - started

            self.stop_event.wait(
                max(
                    0.25,
                    interval - elapsed,
                )
            )

    def _start_tray(self) -> None:
        icon = QIcon(str(self.paths.icon)) if self.paths.icon.exists() else self.qt_app.style().standardIcon(self.qt_app.style().StandardPixmap.SP_ComputerIcon)
        self.qt_app.setWindowIcon(icon)

        self.tray = QSystemTrayIcon(icon, self.qt_app)
        self.tray.setToolTip(APP_NAME)

        menu = QMenu()

        settings_action = QAction("Settings", menu)
        settings_action.triggered.connect(
            self.ui.show_settings
        )
        menu.addAction(settings_action)

        open_folder_action = QAction(
            "Open App Folder",
            menu,
        )
        open_folder_action.triggered.connect(
            lambda: os.startfile(self.paths.app)
        )
        menu.addAction(open_folder_action)

        menu.addSeparator()

        self.pause_action = QAction(
            "Pause Monitoring",
            menu,
        )
        self.pause_action.triggered.connect(
            self.toggle_monitoring
        )
        menu.addAction(self.pause_action)

        menu.addSeparator()

        exit_action = QAction("Exit", menu)
        exit_action.triggered.connect(self.shutdown)
        menu.addAction(exit_action)

        self.tray.setContextMenu(menu)
        self.tray.activated.connect(self._tray_activated)
        self.tray.show()

    def _tray_activated(
        self,
        reason: QSystemTrayIcon.ActivationReason,
    ) -> None:
        if reason in (
            QSystemTrayIcon.ActivationReason.Trigger,
            QSystemTrayIcon.ActivationReason.DoubleClick,
        ):
            self.ui.show_settings()

    def is_monitoring_paused(self) -> bool:
        return self.paused_event.is_set()

    def toggle_monitoring(
        self,
        _checked: bool = False,
    ) -> None:
        if self.paused_event.is_set():
            self.paused_event.clear()
            paused = False
            action_text = "Pause Monitoring"
            tooltip = APP_NAME
            log_detail = "monitoring_resumed"
        else:
            self.paused_event.set()
            paused = True
            action_text = "Resume Monitoring"
            tooltip = f"{APP_NAME} - Monitoring Paused"
            log_detail = "monitoring_paused"

        if self.pause_action is not None:
            self.pause_action.setText(action_text)

        if self.tray is not None:
            self.tray.setToolTip(tooltip)

        self.ui.set_monitoring_paused(paused)

        self.engine.log(
            "MONITORING",
            "application",
            "pause_state",
            log_detail,
            "SUCCESS",
        )

    def shutdown(self) -> None:
        self.stop_event.set()

        if (
            self.worker.is_alive()
            and threading.current_thread() is not self.worker
        ):
            self.worker.join(timeout=5.0)

        if self.worker.is_alive():
            self.engine.log(
                "SHUTDOWN",
                "application",
                "worker_thread",
                "Monitoring worker did not stop within 5 seconds",
                "WARNING",
            )
        else:
            self.engine.log(
                "SHUTDOWN",
                "application",
                "worker_thread",
                "Monitoring worker stopped cleanly",
                "SUCCESS",
            )

        if self.tray is not None:
            self.tray.hide()

        self.qt_app.quit()


def main() -> int:
    if os.name != "nt":
        print("Startup Monitor requires Windows.")
        return 1

    if not is_admin():
        if relaunch_as_admin():
            return 0
        ctypes.windll.user32.MessageBoxW(None, "Administrator permission is required.", APP_NAME, 0x10)
        return 1

    mutex_handle = acquire_single_instance_mutex()

    if mutex_handle is None:
        ctypes.windll.user32.MessageBoxW(
            None,
            "Startup Monitor 64 is already running.",
            APP_NAME,
            0x40,
        )
        return 0

    qt_app = QApplication(sys.argv)
    qt_app.setQuitOnLastWindowClosed(False)
    qt_app.setApplicationName(APP_NAME)

    try:
        app = StartupMonitorApp(qt_app)
        return app.run()
    except Exception as exc:
        QMessageBox.critical(
            None,
            APP_NAME,
            (
                "Startup failed:\n\n"
                f"{type(exc).__name__}: {exc}"
            ),
        )
        return 1
    finally:
        release_single_instance_mutex(
            mutex_handle
        )


if __name__ == "__main__":
    raise SystemExit(main())
