from __future__ import annotations

import configparser
import os
import subprocess
import winreg
from datetime import date
from pathlib import Path
from typing import Callable, Dict, List, Optional

from PySide6.QtCore import QEvent, QItemSelectionModel, QTimer, Qt
from PySide6.QtGui import (
    QCloseEvent,
    QColor,
    QIcon,
    QIntValidator,
    QPalette,
)
from PySide6.QtWidgets import (
    QAbstractItemView,
    QApplication,
    QButtonGroup,
    QStyle,
    QStyledItemDelegate,
    QStyleOptionViewItem,
    QCheckBox,
    QComboBox,
    QDialog,
    QFileDialog,
    QGridLayout,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QMenu,
    QMessageBox,
    QPushButton,
    QRadioButton,
    QTableWidget,
    QTableWidgetItem,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from app_info import (
    APP_AUTHOR,
    APP_GITHUB_URL,
    APP_LICENSE,
    APP_NAME,
    APP_VERSION,
    BUILD_DATE,
)
from config_store import (
    DEFAULT_LOCATIONS,
    ConfigStore,
    Paths,
)
from engine import (
    MonitorEngine,
    ReviewItem,
    RULE_FILE_NAME,
    RULE_REG_EXACT,
    RULE_REG_PREFIX,
    RULE_TASK_EXACT,
    RULE_TASK_PREFIX,
    RULE_VALUE,
)
from scanners import REGISTRY_TARGETS


NUMERIC_OPTIONS = (
    (
        "MonitorTime",
        "Monitor interval (ms)",
        "Monitor interval",
        "3000",
        1500,
        60000,
        "Range: 1500–60000 ms "
        "(1.5 seconds–60 seconds)",
    ),
    (
        "MonitorTimeTasks",
        "Task scan interval (ms)",
        "Task scan interval",
        "60000",
        10000,
        3600000,
        "Range: 10000–3600000 ms "
        "(10 seconds–1 hour)",
    ),
    (
        "ReviewWindowWidth",
        "Review window width",
        "Review window width",
        "700",
        400,
        1600,
        "Range: 400–1600 pixels",
    ),
    (
        "ReviewWindowHeight",
        "Review window height",
        "Review window height",
        "450",
        200,
        900,
        "Range: 200–900 pixels",
    ),
)

CHECKBOX_OPTIONS = (
    (
        "ClearLogOnStart",
        "Clear log on start",
        False,
        "Creates a new empty log file each time "
        "Startup Monitor starts.",
    ),
    (
        "PersistentBaseline",
        "Create persistent baseline",
        True,
        "Creates a baseline of existing startup "
        "items on the first run to reduce false alerts.",
    ),
    (
        "MonitorTasks",
        "Monitor scheduled tasks",
        True,
        "Includes Windows scheduled tasks in "
        "startup monitoring.",
    ),
    (
        "Registry",
        "Monitor Registry locations",
        True,
        "Monitors configured Registry startup "
        "locations for new or modified entries.",
    ),
    (
        "DefaultCheckReviewItems",
        "Review items selected by default",
        True,
        "New items shown in the Review window "
        "are selected for approval by default.",
    ),
    (
        "NotifyDeniedAgain",
        "Review denied items again",
        True,
        "Shows returning denied items in the Review "
        "window instead of deleting them automatically.",
    ),
)


def apply_theme(
    application: QApplication,
    theme_name: str,
) -> None:
    if not hasattr(
        application,
        "_startup_monitor_system_palette",
    ):
        application._startup_monitor_system_palette = QPalette(
            application.palette()
        )

    theme = theme_name.strip().lower()
    style_hints = application.styleHints()

    if hasattr(style_hints, "setColorScheme"):
        if theme == "light":
            style_hints.setColorScheme(
                Qt.ColorScheme.Light
            )
            application.setStyleSheet(
                "QHeaderView::section {"
                "background-color: #d2d2d2;"
                "color: #000000;"
                "}"
            )
        elif theme == "dark":
            style_hints.setColorScheme(
                Qt.ColorScheme.Dark
            )
            application.setStyleSheet("")
        else:
            style_hints.setColorScheme(
                Qt.ColorScheme.Unknown
            )
            application.setStyleSheet("")

        return

    if theme == "system":
        system_palette = getattr(
            application,
            "_startup_monitor_system_palette",
            None,
        )

        if system_palette is not None:
            application.setPalette(
                QPalette(system_palette)
            )

        application.setStyleSheet("")
        return

    palette = QPalette(
        getattr(
            application,
            "_startup_monitor_system_palette",
            application.palette(),
        )
    )

    if theme == "dark":
        palette.setColor(
            QPalette.ColorRole.Window,
            QColor(32, 32, 32),
        )
        palette.setColor(
            QPalette.ColorRole.WindowText,
            QColor(240, 240, 240),
        )
        palette.setColor(
            QPalette.ColorRole.Base,
            QColor(25, 25, 25),
        )
        palette.setColor(
            QPalette.ColorRole.AlternateBase,
            QColor(38, 38, 38),
        )
        palette.setColor(
            QPalette.ColorRole.Text,
            QColor(240, 240, 240),
        )
        palette.setColor(
            QPalette.ColorRole.Button,
            QColor(45, 45, 45),
        )
        palette.setColor(
            QPalette.ColorRole.ButtonText,
            QColor(240, 240, 240),
        )
        palette.setColor(
            QPalette.ColorRole.Highlight,
            QColor(0, 120, 215),
        )
        palette.setColor(
            QPalette.ColorRole.HighlightedText,
            QColor(255, 255, 255),
        )
    else:
        palette.setColor(
            QPalette.ColorRole.Window,
            QColor(235, 235, 235),
        )
        palette.setColor(
            QPalette.ColorRole.WindowText,
            QColor(0, 0, 0),
        )
        palette.setColor(
            QPalette.ColorRole.Base,
            QColor(250, 250, 250),
        )
        palette.setColor(
            QPalette.ColorRole.AlternateBase,
            QColor(240, 240, 240),
        )
        palette.setColor(
            QPalette.ColorRole.Text,
            QColor(0, 0, 0),
        )
        palette.setColor(
            QPalette.ColorRole.Button,
            QColor(220, 220, 220),
        )
        palette.setColor(
            QPalette.ColorRole.ButtonText,
            QColor(0, 0, 0),
        )
        palette.setColor(
            QPalette.ColorRole.Highlight,
            QColor(0, 120, 215),
        )
        palette.setColor(
            QPalette.ColorRole.HighlightedText,
            QColor(255, 255, 255),
        )

    application.setPalette(palette)
    application.setStyleSheet("")


def item_type_colour(
    item_type: str,
    palette: QPalette,
) -> QColor:
    is_dark = (
        palette
        .color(QPalette.ColorRole.Window)
        .lightness()
        < 128
    )

    normalised_type = item_type.strip().casefold()

    if normalised_type in ("file", "folder"):
        return QColor(
            "#6CB6FF"
            if is_dark
            else "#0067B8"
        )

    if normalised_type == "registry":
        return QColor(
            "#C79BFF"
            if is_dark
            else "#7A3DB8"
        )

    if normalised_type == "task":
        return QColor(
            "#75D98B"
            if is_dark
            else "#237A3B"
        )

    return palette.color(
        QPalette.ColorRole.Text
    )


class CenteredCheckBoxDelegate(QStyledItemDelegate):
    def paint(
        self,
        painter,
        option,
        index,
    ) -> None:
        style_option = QStyleOptionViewItem(option)
        self.initStyleOption(style_option, index)

        has_checkbox = bool(
            style_option.features
            & QStyleOptionViewItem.ViewItemFeature.HasCheckIndicator
        )

        if not has_checkbox:
            super().paint(
                painter,
                option,
                index,
            )
            return

        check_state = style_option.checkState

        style_option.features &= (
            ~QStyleOptionViewItem.ViewItemFeature.HasCheckIndicator
        )

        style = (
            style_option.widget.style()
            if style_option.widget is not None
            else QApplication.style()
        )

        style.drawControl(
            QStyle.ControlElement.CE_ItemViewItem,
            style_option,
            painter,
            style_option.widget,
        )

        indicator_option = QStyleOptionViewItem(option)
        self.initStyleOption(
            indicator_option,
            index,
        )
        indicator_option.checkState = check_state

        indicator_rect = style.subElementRect(
            QStyle.SubElement.SE_ItemViewItemCheckIndicator,
            indicator_option,
            style_option.widget,
        )
        indicator_rect.moveCenter(option.rect.center())
        indicator_option.rect = indicator_rect

        style.drawPrimitive(
            QStyle.PrimitiveElement.PE_IndicatorItemViewItemCheck,
            indicator_option,
            painter,
            style_option.widget,
        )

    def editorEvent(
        self,
        event,
        model,
        option,
        index,
    ) -> bool:
        if not (
            index.flags()
            & Qt.ItemFlag.ItemIsUserCheckable
        ):
            return super().editorEvent(
                event,
                model,
                option,
                index,
            )

        style_option = QStyleOptionViewItem(option)
        self.initStyleOption(
            style_option,
            index,
        )

        style = (
            style_option.widget.style()
            if style_option.widget is not None
            else QApplication.style()
        )

        indicator_rect = style.subElementRect(
            QStyle.SubElement.SE_ItemViewItemCheckIndicator,
            style_option,
            style_option.widget,
        )
        indicator_rect.moveCenter(option.rect.center())

        if (
            event.type()
            == QEvent.Type.MouseButtonPress
        ):
            return indicator_rect.contains(
                event.position().toPoint()
            )

        if (
            event.type()
            != QEvent.Type.MouseButtonRelease
        ):
            return super().editorEvent(
                event,
                model,
                option,
                index,
            )

        if not indicator_rect.contains(
            event.position().toPoint()
        ):
            return False

        current_state = index.data(
            Qt.ItemDataRole.CheckStateRole
        )

        is_checked = (
            current_state == Qt.CheckState.Checked
            or current_state
            == Qt.CheckState.Checked.value
        )

        new_state = (
            Qt.CheckState.Unchecked.value
            if is_checked
            else Qt.CheckState.Checked.value
        )

        return model.setData(
            index,
            new_state,
            Qt.ItemDataRole.CheckStateRole,
        )


def _capture_table_sort_state(
    table: QTableWidget,
):
    header = table.horizontalHeader()

    return (
        table.isSortingEnabled(),
        header.sortIndicatorSection(),
        header.sortIndicatorOrder(),
    )


def _restore_table_sort_state(
    table: QTableWidget,
    sorting_enabled: bool,
    sort_column: int,
    sort_order,
) -> None:
    if not sorting_enabled:
        return

    table.setSortingEnabled(True)

    if sort_column >= 0:
        table.sortItems(
            sort_column,
            sort_order,
        )


class ReviewDialog(QDialog):
    def __init__(
        self,
        items: List[ReviewItem],
        on_apply: Callable[[List[ReviewItem]], None],
        on_cancel: Callable[[List[ReviewItem]], None],
        width: int,
        height: int,
    ) -> None:
        super().__init__()
        self.items = items
        self.on_apply = on_apply
        self.on_cancel = on_cancel
        self.completed = False

        self.setWindowTitle("Startup Monitor - Review")
        self.resize(max(600, width), max(320, height))
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, True)

        layout = QVBoxLayout(self)
        title = QLabel("New or changed startup items were detected.")
        title.setStyleSheet("font-weight: bold; font-size: 11pt;")
        layout.addWidget(title)
        layout.addWidget(QLabel("Tick an item to allow it. Unticked items will be denied and removed."))

        self.table = QTableWidget(len(items), 5)
        self.table.setHorizontalHeaderLabels(["Allow", "Name", "Type", "Status", "Path / Command"])
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.table.verticalHeader().setVisible(False)
        self.table.horizontalHeader().setStretchLastSection(True)

        for row, item in enumerate(items):
            allow_cell = QTableWidgetItem()
            allow_cell.setFlags(Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsUserCheckable | Qt.ItemFlag.ItemIsSelectable)
            allow_cell.setCheckState(Qt.CheckState.Checked if item.allowed else Qt.CheckState.Unchecked)
            self.table.setItem(row, 0, allow_cell)
            self.table.setItem(row, 1, QTableWidgetItem(item.display_name))

            normalised_type = item.item_type.strip().casefold()

            if normalised_type in ("reg", "registry"):
                display_type = "Registry"
            elif normalised_type == "file":
                display_type = "File"
            elif normalised_type == "folder":
                display_type = "Folder"
            elif normalised_type == "task":
                display_type = "Task"
            else:
                display_type = item.item_type.strip().title()

            type_item = QTableWidgetItem(display_type)
            type_item.setForeground(
                item_type_colour(
                    display_type,
                    self.table.palette(),
                )
            )
            self.table.setItem(row, 2, type_item)

            self.table.setItem(row, 3, QTableWidgetItem(item.status))
            self.table.setItem(row, 4, QTableWidgetItem(item.detail))

        self.table.resizeColumnsToContents()
        self.table.setSortingEnabled(True)
        layout.addWidget(self.table)

        buttons = QHBoxLayout()

        select_all_button = QPushButton("Select All")
        select_all_button.clicked.connect(self.select_all_items)
        buttons.addWidget(select_all_button)

        select_none_button = QPushButton("Select None")
        select_none_button.clicked.connect(self.select_no_items)
        buttons.addWidget(select_none_button)

        export_button = QPushButton("Export")
        export_button.clicked.connect(self.export_report)
        buttons.addWidget(export_button)

        buttons.addStretch()

        cancel_button = QPushButton("Cancel")
        cancel_button.clicked.connect(self.cancel_review)
        buttons.addWidget(cancel_button)

        apply_button = QPushButton("Apply")
        apply_button.clicked.connect(self.apply_review)
        buttons.addWidget(apply_button)

        layout.addLayout(buttons)

    def select_all_items(self) -> None:
        for row in range(self.table.rowCount()):
            cell = self.table.item(row, 0)

            if cell is not None:
                cell.setCheckState(Qt.CheckState.Checked)

    def select_no_items(self) -> None:
        for row in range(self.table.rowCount()):
            cell = self.table.item(row, 0)

            if cell is not None:
                cell.setCheckState(Qt.CheckState.Unchecked)

    def export_report(self) -> None:
        filename, _selected_filter = QFileDialog.getSaveFileName(
            self,
            "Export Review Report",
            "StartupMonitor_Review.ini",
            "INI files (*.ini);;All files (*.*)",
        )

        if not filename:
            return

        if not filename.lower().endswith(".ini"):
            filename += ".ini"

        parser = configparser.ConfigParser(
            interpolation=None,
            delimiters=("=",),
        )
        parser.optionxform = str

        parser["Report"] = {
            "ItemCount": str(len(self.items)),
        }

        for number, item in enumerate(self.items, start=1):
            cell = self.table.item(number - 1, 0)
            allowed = (
                cell is not None
                and cell.checkState() == Qt.CheckState.Checked
            )

            section = f"Item_{number:03d}"
            parser[section] = {
                "Allow": "1" if allowed else "0",
                "Name": item.display_name.replace(
                    "\r",
                    " ",
                ).replace(
                    "\n",
                    " ",
                ),
                "Type": item.item_type.replace(
                    "\r",
                    " ",
                ).replace(
                    "\n",
                    " ",
                ),
                "Status": item.status.replace(
                    "\r",
                    " ",
                ).replace(
                    "\n",
                    " ",
                ),
                "PathOrCommand": item.detail.replace(
                    "\r",
                    " ",
                ).replace(
                    "\n",
                    " ",
                ),
                "Key": item.key.replace(
                    "\r",
                    " ",
                ).replace(
                    "\n",
                    " ",
                ),
                "Fingerprint": item.item_hash,
            }

        try:
            with Path(filename).open(
                "w",
                encoding="utf-8",
                newline="",
            ) as handle:
                parser.write(
                    handle,
                    space_around_delimiters=False,
                )
        except OSError as error:
            QMessageBox.critical(
                self,
                "Export Failed",
                f"The report could not be exported.\n\n{error}",
            )
            return

        QMessageBox.information(
            self,
            "Startup Monitor",
            f"Review report exported successfully.\n\n{filename}",
        )

    def apply_review(self) -> None:
        for row, item in enumerate(self.items):
            cell = self.table.item(row, 0)
            item.allowed = (
                cell is not None
                and cell.checkState() == Qt.CheckState.Checked
            )

        self.completed = True
        self.on_apply(self.items)
        self.accept()

    def cancel_review(self) -> None:
        self.completed = True
        self.on_cancel(self.items)
        self.reject()

    def closeEvent(self, event: QCloseEvent) -> None:
        if not self.completed:
            self.completed = True
            self.on_cancel(self.items)
        event.accept()


class SettingsWindow(QDialog):
    def __init__(
        self,
        engine: MonitorEngine,
        store: ConfigStore,
        paths: Paths,
        on_saved: Callable[[], None],
        on_toggle_monitoring: Callable[[], None],
        is_monitoring_paused: Callable[[], bool],
    ) -> None:
        super().__init__()
        self.engine = engine
        self.store = store
        self.paths = paths
        self.on_saved = on_saved
        self.on_toggle_monitoring = on_toggle_monitoring
        self.is_monitoring_paused = is_monitoring_paused

        self.setWindowTitle("Startup Monitor - Settings")
        self.resize(920, 640)
        self.setAttribute(
            Qt.WidgetAttribute.WA_DeleteOnClose,
            True,
        )

        self.settings = dict(engine.settings)
        self.folders = dict(engine.folders)
        self.registry_tokens = dict(engine.registry_tokens)
        self.allowed = dict(engine.allowed)
        self.denied = dict(engine.denied)
        self.context_selected_rows: Dict[int, List[int]] = {}

        main_layout = QVBoxLayout(self)
        tabs = QTabWidget()
        main_layout.addWidget(tabs)

        self._build_options(tabs)
        self._build_locations(tabs)
        self._build_allowed_tab(tabs)
        self._build_denied_tab(tabs)
        self._build_base_startup_tab(tabs)
        self._build_base_tasks_tab(tabs)
        self._build_log_tab(tabs)
        self._build_about_tab(tabs)

        self.log_file_signature = (
            self._log_file_signature()
        )

        self.log_refresh_timer = QTimer(self)
        self.log_refresh_timer.setInterval(1000)
        self.log_refresh_timer.timeout.connect(
            self._refresh_log_if_changed
        )
        self.log_refresh_timer.start()

        layout_margins = main_layout.contentsMargins()
        minimum_tab_width = (
            tabs.tabBar().sizeHint().width()
            + layout_margins.left()
            + layout_margins.right()
            + 20
        )

        self.setMinimumWidth(minimum_tab_width)

        footer = QHBoxLayout()

        open_button = QPushButton("Settings Folder")
        open_button.clicked.connect(self.open_app_folder)
        footer.addWidget(open_button)

        self.monitoring_button = QPushButton()
        self.monitoring_button.clicked.connect(
            lambda: self.on_toggle_monitoring()
        )
        footer.addWidget(self.monitoring_button)

        self.monitoring_status_label = QLabel(
            "Monitoring Paused"
        )
        self.monitoring_status_label.setStyleSheet(
            "QLabel {"
            "color: palette(highlight);"
            "font-weight: bold;"
            "}"
        )
        footer.addWidget(self.monitoring_status_label)

        self.set_monitoring_paused(
            self.is_monitoring_paused()
        )

        footer.addStretch()

        close_button = QPushButton("Close")
        close_button.clicked.connect(self.close)
        footer.addWidget(close_button)

        apply_button = QPushButton("Apply")
        apply_button.clicked.connect(self.apply_changes)
        footer.addWidget(apply_button)

        main_layout.addLayout(footer)

    def _build_options(self, tabs: QTabWidget) -> None:
        tab = QWidget()
        layout = QGridLayout(tab)
        layout.setContentsMargins(18, 18, 18, 18)
        layout.setHorizontalSpacing(18)
        layout.setVerticalSpacing(12)
        layout.setColumnStretch(2, 1)

        self.option_edits: Dict[str, QLineEdit] = {}
        self.option_checks: Dict[str, QCheckBox] = {}

        row = 0

        for (
            key,
            label_text,
            _validation_label,
            default,
            minimum,
            maximum,
            description_text,
        ) in NUMERIC_OPTIONS:
            label = QLabel(label_text)

            edit = QLineEdit(
                self.settings.get(key, default)
            )
            edit.setFixedWidth(85)
            edit.setMaxLength(7)
            edit.setValidator(
                QIntValidator(
                    minimum,
                    maximum,
                    edit,
                )
            )

            description = QLabel(description_text)
            description.setWordWrap(True)

            self.option_edits[key] = edit

            layout.addWidget(label, row, 0)
            layout.addWidget(edit, row, 1)
            layout.addWidget(description, row, 2)

            row += 1

        row += 1

        for (
            key,
            label_text,
            default_checked,
            description_text,
        ) in CHECKBOX_OPTIONS:
            label = QLabel(label_text)

            check = QCheckBox()
            check.setChecked(
                self.settings.get(
                    key,
                    "1" if default_checked else "0",
                )
                == "1"
            )

            description = QLabel(description_text)
            description.setWordWrap(True)

            self.option_checks[key] = check

            layout.addWidget(label, row, 0)
            layout.addWidget(
                check,
                row,
                1,
                Qt.AlignmentFlag.AlignLeft,
            )
            layout.addWidget(description, row, 2)

            row += 1

        theme_label = QLabel("Theme")

        theme_widget = QWidget()
        theme_layout = QHBoxLayout(theme_widget)
        theme_layout.setContentsMargins(0, 0, 0, 0)
        theme_layout.setSpacing(18)

        self.theme_group = QButtonGroup(self)
        self.theme_buttons: Dict[str, QRadioButton] = {}

        selected_theme = self.settings.get(
            "Theme",
            "System",
        ).strip().title()

        if selected_theme not in (
            "Light",
            "Dark",
            "System",
        ):
            selected_theme = "System"

        for theme_name in (
            "Light",
            "Dark",
            "System",
        ):
            button = QRadioButton(theme_name)
            button.setChecked(
                theme_name == selected_theme
            )

            self.theme_group.addButton(button)
            self.theme_buttons[theme_name] = button
            theme_layout.addWidget(button)

        theme_layout.addStretch()

        layout.addWidget(theme_label, row, 0)
        layout.addWidget(
            theme_widget,
            row,
            1,
            1,
            2,
        )

        row += 1

        reset_button = QPushButton("Reset to Defaults")
        reset_button.clicked.connect(
            self.reset_options_to_defaults
        )

        reset_description = QLabel(
            "Restores all Options and the default Locations. "
            "Changes are saved only when Apply is clicked."
        )
        reset_description.setWordWrap(True)

        layout.addWidget(
            reset_button,
            row,
            0,
            1,
            2,
            Qt.AlignmentFlag.AlignLeft,
        )
        layout.addWidget(
            reset_description,
            row,
            2,
        )

        row += 1
        layout.setRowStretch(row, 1)

        tabs.addTab(tab, "Options")

    def reset_options_to_defaults(self) -> None:
        for (
            key,
            _label_text,
            _validation_label,
            default,
            _minimum,
            _maximum,
            _description_text,
        ) in NUMERIC_OPTIONS:
            edit = self.option_edits.get(key)

            if edit is not None:
                edit.setText(default)

        for (
            key,
            _label_text,
            default_checked,
            _description_text,
        ) in CHECKBOX_OPTIONS:
            check = self.option_checks.get(key)

            if check is not None:
                check.setChecked(default_checked)

        system_button = self.theme_buttons.get("System")

        if system_button is not None:
            system_button.setChecked(True)

        self.folders.clear()
        self.folders.update(
            DEFAULT_LOCATIONS["Folders"]
        )

        self.registry_tokens.clear()
        self.registry_tokens.update(
            DEFAULT_LOCATIONS["Registry"]
        )

        self.cancel_remove_locations()
        self._refresh_location_table()

    def _configure_action_table(
        self,
        table: QTableWidget,
    ) -> None:
        table.setSelectionBehavior(
            QAbstractItemView.SelectionBehavior.SelectRows
        )
        table.setSelectionMode(
            QAbstractItemView.SelectionMode.ExtendedSelection
        )
        table.setEditTriggers(
            QAbstractItemView.EditTrigger.NoEditTriggers
        )
        table.verticalHeader().setVisible(False)
        table.setContextMenuPolicy(
            Qt.ContextMenuPolicy.CustomContextMenu
        )
        table.viewport().installEventFilter(self)

    def _connect_checkbox_selection_sync(
        self,
        table: QTableWidget,
    ) -> None:
        table.itemSelectionChanged.connect(
            lambda: self._sync_action_checkboxes_from_selection(
                table
            )
        )
        table.itemClicked.connect(
            lambda item: self._sync_action_selection_from_checkbox(
                table,
                item,
            )
        )

    @staticmethod
    def _checked_column_values(
        table: QTableWidget,
        value_column: int,
    ) -> List[str]:
        values: List[str] = []

        for row in range(table.rowCount()):
            select_item = table.item(row, 0)
            value_item = table.item(
                row,
                value_column,
            )

            if select_item is None or value_item is None:
                continue

            if (
                select_item.checkState()
                == Qt.CheckState.Checked
            ):
                values.append(value_item.text())

        return values

    @staticmethod
    def _sync_action_checkboxes_from_selection(
        table: QTableWidget,
    ) -> None:
        selected_rows = {
            index.row()
            for index in table.selectionModel().selectedRows()
        }

        (
            sorting_enabled,
            sort_column,
            sort_order,
        ) = _capture_table_sort_state(table)

        table.setSortingEnabled(False)
        table.blockSignals(True)

        try:
            for row in range(table.rowCount()):
                select_item = table.item(row, 0)

                if select_item is None:
                    continue

                select_item.setCheckState(
                    Qt.CheckState.Checked
                    if row in selected_rows
                    else Qt.CheckState.Unchecked
                )
        finally:
            table.blockSignals(False)
            _restore_table_sort_state(
                table,
                sorting_enabled,
                sort_column,
                sort_order,
            )

    @staticmethod
    def _sync_action_selection_from_checkbox(
        table: QTableWidget,
        item: QTableWidgetItem,
    ) -> None:
        if item.column() != 0:
            return

        selection_model = table.selectionModel()
        model_index = table.model().index(item.row(), 0)

        operation = (
            QItemSelectionModel.SelectionFlag.Select
            if item.checkState() == Qt.CheckState.Checked
            else QItemSelectionModel.SelectionFlag.Deselect
        )

        selection_model.select(
            model_index,
            operation
            | QItemSelectionModel.SelectionFlag.Rows,
        )

    def eventFilter(self, watched, event) -> bool:
        if (
            event.type() == QEvent.Type.Resize
            and watched
            is getattr(
                self,
                "about_tab",
                None,
            )
        ):
            self._position_about_icon()

        if (
            event.type() == QEvent.Type.MouseButtonPress
            and event.button() == Qt.MouseButton.RightButton
        ):
            tables = (
                self.location_table,
                self.allowed_table,
                self.denied_table,
                self.base_startup_table,
                self.base_tasks_table,
            )

            for table in tables:
                if watched is not table.viewport():
                    continue

                clicked_index = table.indexAt(
                    event.position().toPoint()
                )
                selected_rows = [
                    index.row()
                    for index in table.selectionModel().selectedRows()
                ]

                if (
                    clicked_index.isValid()
                    and clicked_index.row() in selected_rows
                ):
                    self.context_selected_rows[id(table)] = (
                        selected_rows
                    )
                else:
                    self.context_selected_rows[id(table)] = []

                break

        return super().eventFilter(watched, event)

    def _prepare_action_context_selection(
        self,
        table: QTableWidget,
        clicked_index,
    ) -> None:
        if not clicked_index.isValid():
            self.context_selected_rows.pop(id(table), None)
            return

        saved_rows = self.context_selected_rows.pop(
            id(table),
            [],
        )

        selection_model = table.selectionModel()
        table.blockSignals(True)

        try:
            table.clearSelection()

            rows_to_select = (
                saved_rows
                if saved_rows
                else [clicked_index.row()]
            )

            for row in rows_to_select:
                model_index = table.model().index(row, 0)
                selection_model.select(
                    model_index,
                    QItemSelectionModel.SelectionFlag.Select
                    | QItemSelectionModel.SelectionFlag.Rows,
                )

            selection_model.setCurrentIndex(
                clicked_index,
                QItemSelectionModel.SelectionFlag.NoUpdate,
            )
        finally:
            table.blockSignals(False)

    def _build_locations(self, tabs: QTabWidget) -> None:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        self.location_table = QTableWidget(0, 3)
        self.location_table.setHorizontalHeaderLabels(
            ["Enabled", "Location Path", "Type"]
        )
        self._configure_action_table(
            self.location_table
        )
        self.location_table.horizontalHeader().setStretchLastSection(
            False
        )
        self.location_table.setColumnWidth(0, 75)
        self.location_table.setColumnWidth(1, 610)
        self.location_table.setColumnWidth(2, 100)

        self.location_table.customContextMenuRequested.connect(
            self.show_locations_context_menu
        )
        self.location_table.itemDoubleClicked.connect(
            lambda _item: self.edit_selected_location()
        )

        layout.addWidget(self.location_table)
        self._refresh_location_table()
        self.location_table.setSortingEnabled(True)

        buttons = QHBoxLayout()

        add_folder_button = QPushButton("Add Folder")
        add_folder_button.clicked.connect(self.add_folder)
        buttons.addWidget(add_folder_button)

        add_registry_button = QPushButton("Add Registry Path")
        add_registry_button.clicked.connect(self.add_registry_path)
        buttons.addWidget(add_registry_button)

        toggle_button = QPushButton("Enable / Disable")
        toggle_button.clicked.connect(self.toggle_selected_locations)
        buttons.addWidget(toggle_button)

        remove_button = QPushButton("Remove")
        remove_button.clicked.connect(self.request_remove_locations)
        buttons.addWidget(remove_button)

        buttons.addStretch()
        layout.addLayout(buttons)

        (
            self.location_confirmation,
            self.location_confirmation_label,
        ) = self._create_confirmation_panel(
            self.confirm_remove_locations,
            self.cancel_remove_locations,
        )
        layout.addWidget(self.location_confirmation)

        self.pending_location_removals: List[tuple[str, str]] = []

        tabs.addTab(tab, "Locations")

    @staticmethod
    def _create_remove_button_row(
        remove_callback: Callable[[], None],
        add_callback: Optional[
            Callable[[], None]
        ] = None,
    ) -> QHBoxLayout:
        buttons = QHBoxLayout()

        if add_callback is not None:
            add_button = QPushButton("Add")
            add_button.clicked.connect(
                add_callback
            )
            buttons.addWidget(add_button)

        remove_button = QPushButton("Remove")
        remove_button.clicked.connect(
            remove_callback
        )
        buttons.addWidget(remove_button)

        buttons.addStretch()

        return buttons

    def _create_decision_tab(
        self,
        add_callback: Callable[[], None],
        remove_callback: Callable[[], None],
        confirm_callback: Callable[[], None],
        cancel_callback: Callable[[], None],
        context_menu_callback: Callable,
    ) -> tuple[
        QWidget,
        QTableWidget,
        QWidget,
        QLabel,
    ]:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        table = QTableWidget(0, 5)
        table.setHorizontalHeaderLabels(
            [
                "Select",
                "#",
                "Type",
                "Item / Path",
                "Saved fingerprint",
            ]
        )

        self._configure_action_table(table)

        table.horizontalHeader().setStretchLastSection(
            True
        )
        table.setColumnWidth(0, 45)
        table.setColumnWidth(1, 45)
        table.setColumnWidth(2, 85)
        table.setColumnWidth(3, 525)

        table.customContextMenuRequested.connect(
            context_menu_callback
        )

        layout.addWidget(table)
        layout.addLayout(
            self._create_remove_button_row(
                remove_callback,
                add_callback,
            )
        )

        confirmation, confirmation_label = (
            self._create_confirmation_panel(
                confirm_callback,
                cancel_callback,
            )
        )
        layout.addWidget(confirmation)

        return (
            tab,
            table,
            confirmation,
            confirmation_label,
        )

    def _add_decision_rule(
        self,
        list_name: str,
        values: Dict[str, str],
        populate_callback: Callable[[], None],
        log_action: str,
    ) -> None:
        dialog = QDialog(self)
        dialog.setWindowTitle(
            f"Add {list_name} Rule"
        )
        dialog.setMinimumWidth(620)

        layout = QVBoxLayout(dialog)
        layout.setSpacing(12)

        warning = QLabel(
            "<b>WARNING:</b> Rules apply automatically to "
            "future detections.<br><br>"
            "Allowed rules can suppress security review of "
            "matching items. Denied rules can cause matching "
            "items to be removed depending on your Denied "
            "notification and Review settings.<br><br>"
            "Only create a rule when you understand exactly "
            "what it will match."
        )
        warning.setWordWrap(True)

        warning_is_dark = (
            dialog.palette()
            .color(QPalette.ColorRole.Window)
            .lightness()
            < 128
        )

        if warning_is_dark:
            warning.setStyleSheet(
                "QLabel {"
                "background-color: #1E1600;"
                "color: #fff3cd;"
                "border: 1px solid #fff3cd;"
                "border-radius: 4px;"
                "padding: 10px;"
                "}"
            )
        else:
            warning.setStyleSheet(
                "QLabel {"
                "background-color: #fff3cd;"
                "color: #664d03;"
                "border: 1px solid #ffecb5;"
                "border-radius: 4px;"
                "padding: 10px;"
                "}"
            )

        layout.addWidget(warning)

        type_label = QLabel("Rule type:")
        layout.addWidget(type_label)

        rule_type = QComboBox()
        rule_type.addItems(
            [
                "File name equals",
                "Registry value equals",
                "Registry value name starts with",
                "Scheduled task name equals",
                "Scheduled task name starts with",
            ]
        )
        layout.addWidget(rule_type)

        description = QLabel()
        description.setWordWrap(True)
        layout.addWidget(description)

        field_layout = QGridLayout()

        primary_label = QLabel()
        primary_edit = QLineEdit()

        secondary_label = QLabel()
        secondary_edit = QLineEdit()

        secondary_label.setMinimumHeight(
            primary_edit.sizeHint().height()
        )
        secondary_edit.setMinimumHeight(
            primary_edit.sizeHint().height()
        )

        field_layout.addWidget(
            primary_label,
            0,
            0,
        )
        field_layout.addWidget(
            primary_edit,
            0,
            1,
        )
        field_layout.addWidget(
            secondary_label,
            1,
            0,
        )
        field_layout.addWidget(
            secondary_edit,
            1,
            1,
        )

        field_layout.setRowMinimumHeight(
            1,
            primary_edit.sizeHint().height(),
        )

        field_layout.setColumnStretch(
            1,
            1,
        )

        layout.addLayout(field_layout)

        example = QLabel()
        example.setWordWrap(True)
        example.setStyleSheet(
            "QLabel {"
            "color: palette(text);"
            "font-size: 9pt;"
            "margin-top: 4px;"
            "}"
        )
        layout.addWidget(example)

        buttons = QHBoxLayout()
        buttons.addStretch()

        cancel_button = QPushButton("Cancel")
        add_button = QPushButton("Add")

        buttons.addWidget(cancel_button)
        buttons.addWidget(add_button)

        layout.addLayout(buttons)

        def update_rule_fields() -> None:
            selected = rule_type.currentText()

            primary_edit.clear()
            secondary_edit.clear()

            if selected == "File name equals":
                description.setText(
                    "Matches files only. The filename must "
                    "match exactly, although matching is not "
                    "case-sensitive."
                )
                primary_label.setText(
                    "Exact filename:"
                )
                primary_edit.setPlaceholderText(
                    "Dropbox.exe"
                )

                secondary_label.setText("")
                secondary_edit.clear()
                secondary_edit.setPlaceholderText("")
                secondary_edit.setEnabled(False)

                example.setText(
                    "Example: Dropbox.exe\n"
                    "Does not match DropboxHelper.exe or "
                    "MyDropbox.exe."
                )

            elif selected == "Registry value equals":
                description.setText(
                    "Matches one exact registry value inside "
                    "one exact registry key. Changes to that "
                    "value's data will still match this rule."
                )
                primary_label.setText(
                    "Registry key:"
                )
                primary_edit.setPlaceholderText(
                    "HKLM\\System\\CurrentControlSet\\"
                    "Control\\Session Manager"
                )

                secondary_label.setText(
                    "Exact value name:"
                )
                secondary_edit.setPlaceholderText(
                    "PendingFileRenameOperations"
                )
                secondary_edit.setEnabled(True)

                example.setText(
                    "Recommended for a known registry value "
                    "whose contents legitimately change."
                )

            elif (
                selected
                == "Registry value name starts with"
            ):
                description.setText(
                    "Matches registry value names beginning "
                    "with the specified text, but ONLY inside "
                    "the exact registry key entered below."
                )
                primary_label.setText(
                    "Registry key:"
                )
                primary_edit.setPlaceholderText(
                    "HKLM\\Software\\Microsoft\\Windows\\"
                    "CurrentVersion\\RunOnce"
                )

                secondary_label.setText(
                    "Value name starts with:"
                )
                secondary_edit.setPlaceholderText(
                    "msedge_cleanup_"
                )
                secondary_edit.setEnabled(True)

                example.setText(
                    "Example: msedge_cleanup_ matches changing "
                    "Edge cleanup value names only within the "
                    "registry key specified above."
                )

            elif (
                selected
                == "Scheduled task name equals"
            ):
                description.setText(
                    "Matches one exact scheduled-task name."
                )
                primary_label.setText(
                    "Exact task name:"
                )
                primary_edit.setPlaceholderText(
                    "\\Microsoft\\Windows\\ExampleTask"
                )

                secondary_label.setText("")
                secondary_edit.clear()
                secondary_edit.setPlaceholderText("")
                secondary_edit.setEnabled(False)

                example.setText(
                    "Use this when the scheduled-task name "
                    "does not change."
                )

            else:
                description.setText(
                    "Matches scheduled-task names beginning "
                    "with the specified text. Use the narrowest "
                    "prefix possible."
                )
                primary_label.setText(
                    "Task name starts with:"
                )
                primary_edit.setPlaceholderText(
                    "\\Microsoft\\Windows\\Example"
                )

                secondary_label.setText("")
                secondary_edit.clear()
                secondary_edit.setPlaceholderText("")
                secondary_edit.setEnabled(False)

                example.setText(
                    "Avoid broad task-name prefixes."
                )

        def create_rule() -> None:
            selected = rule_type.currentText()

            primary = primary_edit.text().strip()
            secondary = secondary_edit.text().strip()

            rule_key = ""

            if selected == "File name equals":
                if (
                    not primary
                    or "\\" in primary
                    or "/" in primary
                    or "=" in primary
                ):
                    QMessageBox.warning(
                        dialog,
                        "Invalid File Rule",
                        (
                            "Enter a filename only, for example:\n\n"
                            "Dropbox.exe\n\n"
                            "Do not enter a path or use '='."
                        ),
                    )
                    return

                rule_key = (
                    RULE_FILE_NAME
                    + primary
                )

            elif selected in (
                "Registry value equals",
                "Registry value name starts with",
            ):
                registry_path = primary.rstrip(
                    "\\"
                )

                normalised_path = (
                    registry_path.upper()
                )

                if (
                    not registry_path
                    or "|" in registry_path
                    or "=" in registry_path
                    or not normalised_path.startswith(
                        (
                            "HKLM\\",
                            "HKCU\\",
                        )
                    )
                ):
                    QMessageBox.warning(
                        dialog,
                        "Invalid Registry Rule",
                        (
                            "Enter an exact HKLM or HKCU "
                            "registry key.\n\n"
                            "Do not include a value name, "
                            "'|', or '='."
                        ),
                    )
                    return

                if (
                    not secondary
                    or "|" in secondary
                    or "=" in secondary
                ):
                    QMessageBox.warning(
                        dialog,
                        "Invalid Registry Rule",
                        (
                            "Enter a non-empty registry "
                            "value name or prefix.\n\n"
                            "Do not use '|' or '='."
                        ),
                    )
                    return

                if (
                    selected
                    == "Registry value equals"
                ):
                    rule_key = (
                        RULE_REG_EXACT
                        + registry_path
                        + "|"
                        + secondary
                    )
                else:
                    rule_key = (
                        RULE_REG_PREFIX
                        + registry_path
                        + "|"
                        + secondary
                    )

            elif (
                selected
                == "Scheduled task name equals"
            ):
                if (
                    not primary
                    or "=" in primary
                ):
                    QMessageBox.warning(
                        dialog,
                        "Invalid Task Rule",
                        (
                            "Enter a non-empty task name.\n\n"
                            "Do not use '='."
                        ),
                    )
                    return

                rule_key = (
                    RULE_TASK_EXACT
                    + primary
                )

            else:
                if (
                    not primary
                    or "=" in primary
                ):
                    QMessageBox.warning(
                        dialog,
                        "Invalid Task Rule",
                        (
                            "Enter a non-empty task-name "
                            "prefix.\n\n"
                            "Do not use '='."
                        ),
                    )
                    return

                rule_key = (
                    RULE_TASK_PREFIX
                    + primary
                )

            existing_key = next(
                (
                    key
                    for key in values
                    if key.casefold()
                    == rule_key.casefold()
                ),
                None,
            )

            if existing_key is not None:
                QMessageBox.information(
                    dialog,
                    "Startup Monitor",
                    (
                        "That rule already exists in the "
                        f"{list_name} list."
                    ),
                )
                return

            opposite_values = (
                self.denied
                if list_name == "Allowed"
                else self.allowed
            )

            opposite_name = (
                "Denied"
                if list_name == "Allowed"
                else "Allowed"
            )

            opposite_key = next(
                (
                    key
                    for key in opposite_values
                    if key.casefold()
                    == rule_key.casefold()
                ),
                None,
            )

            if opposite_key is not None:
                QMessageBox.warning(
                    dialog,
                    "Conflicting Rule",
                    (
                        "The same rule already exists in the "
                        f"{opposite_name} list.\n\n"
                        "Remove that rule first."
                    ),
                )
                return

            values[rule_key] = RULE_VALUE

            self.store.save_allowed_denied(
                self.allowed,
                self.denied,
            )
            self.engine.reload_all(
                create_baselines=False
            )
            self.engine.log(
                "SETTINGS",
                "gui",
                log_action,
                rule_key,
                "SUCCESS",
            )

            populate_callback()
            dialog.accept()

        rule_type.currentTextChanged.connect(
            update_rule_fields
        )
        cancel_button.clicked.connect(
            dialog.reject
        )
        add_button.clicked.connect(
            create_rule
        )
        primary_edit.returnPressed.connect(
            create_rule
        )
        secondary_edit.returnPressed.connect(
            create_rule
        )

        update_rule_fields()

        dialog.exec()

    def add_allowed_rule(self) -> None:
        self._add_decision_rule(
            "Allowed",
            self.allowed,
            self._populate_allowed_table,
            "allowed_rule_add",
        )

    def _build_allowed_tab(self, tabs: QTabWidget) -> None:
        (
            tab,
            self.allowed_table,
            self.allowed_confirmation,
            self.allowed_confirmation_label,
        ) = self._create_decision_tab(
            self.add_allowed_rule,
            self.remove_checked_allowed,
            self.confirm_remove_allowed,
            self.cancel_remove_allowed,
            self.show_allowed_context_menu,
        )

        self._populate_allowed_table()
        self.allowed_table.setSortingEnabled(True)
        self.pending_allowed_removals: List[str] = []

        tabs.addTab(tab, "Allowed")

    @staticmethod
    def _populate_decision_table(
        table: QTableWidget,
        values: Dict[str, str],
    ) -> None:
        (
            sorting_enabled,
            sort_column,
            sort_order,
        ) = _capture_table_sort_state(table)

        table.setSortingEnabled(False)
        table.setRowCount(0)

        for number, (key, value) in enumerate(
            values.items(),
            start=1,
        ):
            row = table.rowCount()
            table.insertRow(row)

            select_item = QTableWidgetItem()
            select_item.setFlags(
                Qt.ItemFlag.ItemIsEnabled
                | Qt.ItemFlag.ItemIsSelectable
                | Qt.ItemFlag.ItemIsUserCheckable
            )
            select_item.setCheckState(
                Qt.CheckState.Unchecked
            )

            number_item = QTableWidgetItem()
            number_item.setData(
                Qt.ItemDataRole.EditRole,
                number,
            )
            number_item.setTextAlignment(
                Qt.AlignmentFlag.AlignCenter
            )

            if key.startswith(RULE_FILE_NAME):
                item_type = "File"
            elif (
                key.startswith(RULE_REG_EXACT)
                or key.startswith(RULE_REG_PREFIX)
            ):
                item_type = "Registry"
            elif (
                key.startswith(RULE_TASK_EXACT)
                or key.startswith(RULE_TASK_PREFIX)
            ):
                item_type = "Task"
            elif "|" in key:
                item_type = "Registry"
            elif key.startswith("\\") and not key.startswith("\\\\"):
                item_type = "Task"
            else:
                item_type = "File"

            type_item = QTableWidgetItem(item_type)
            type_item.setForeground(
                item_type_colour(
                    item_type,
                    table.palette(),
                )
            )

            table.setItem(
                row,
                0,
                select_item,
            )
            table.setItem(
                row,
                1,
                number_item,
            )
            table.setItem(
                row,
                2,
                type_item,
            )
            table.setItem(
                row,
                3,
                QTableWidgetItem(key),
            )
            table.setItem(
                row,
                4,
                QTableWidgetItem(value),
            )

        table.resizeRowsToContents()
        table.horizontalHeader().setStretchLastSection(
            True
        )

        _restore_table_sort_state(
            table,
            sorting_enabled,
            sort_column,
            sort_order,
        )

    def _populate_allowed_table(self) -> None:
        self._populate_decision_table(
            self.allowed_table,
            self.allowed,
        )

    def _request_decision_removal(
        self,
        table: QTableWidget,
        list_name: str,
        confirmation: QWidget,
        confirmation_label: QLabel,
    ) -> Optional[List[str]]:
        keys = self._checked_column_values(
            table,
            3,
        )

        if not keys:
            QMessageBox.information(
                self,
                "Startup Monitor",
                f"Tick one or more {list_name} items to remove.",
            )
            return None

        if len(keys) == 1:
            confirmation_label.setText(
                "Confirm removal of this entry from "
                f"the {list_name} list?\n"
                f"{keys[0]}"
            )
        else:
            confirmation_label.setText(
                "Confirm removal of these "
                f"{len(keys)} entries from "
                f"the {list_name} list?"
            )

        confirmation.setVisible(True)

        return keys

    def _confirm_decision_removal(
        self,
        keys: List[str],
        values: Dict[str, str],
        confirmation: QWidget,
        populate_callback: Callable[[], None],
        log_action: str,
    ) -> None:
        if not keys:
            confirmation.setVisible(False)
            return

        for key in keys:
            values.pop(key, None)

        self.store.save_allowed_denied(
            self.allowed,
            self.denied,
        )
        self.engine.reload_all(
            create_baselines=False
        )
        self.engine.log(
            "SETTINGS",
            "gui",
            log_action,
            f"{len(keys)} item(s) removed",
            "SUCCESS",
        )

        confirmation.setVisible(False)
        populate_callback()

    @staticmethod
    def _cancel_decision_removal(
        confirmation: QWidget,
    ) -> None:
        confirmation.setVisible(False)

    def _checked_allowed_keys(self) -> List[str]:
        return self._checked_column_values(
            self.allowed_table,
            3,
        )

    def remove_checked_allowed(self) -> None:
        keys = self._request_decision_removal(
            self.allowed_table,
            "Allowed",
            self.allowed_confirmation,
            self.allowed_confirmation_label,
        )

        if keys is not None:
            self.pending_allowed_removals = keys

    def confirm_remove_allowed(self) -> None:
        keys = list(
            self.pending_allowed_removals
        )

        self._confirm_decision_removal(
            keys,
            self.allowed,
            self.allowed_confirmation,
            self._populate_allowed_table,
            "allowed_remove",
        )

        self.pending_allowed_removals = []

    def cancel_remove_allowed(self) -> None:
        self.pending_allowed_removals = []
        self._cancel_decision_removal(
            self.allowed_confirmation
        )

    def refresh_allowed(self) -> None:
        loaded_allowed, _loaded_denied = (
            self.store.load_allowed_denied()
        )

        self.allowed.clear()
        self.allowed.update(loaded_allowed)
        self._populate_allowed_table()

    def _copy_table_value(
        self,
        table: QTableWidget,
        value_column: int,
        no_selection_message: str,
    ) -> None:
        row = table.currentRow()

        if row < 0:
            QMessageBox.information(
                self,
                "Startup Monitor",
                no_selection_message,
            )
            return

        value_item = table.item(
            row,
            value_column,
        )

        if value_item is None:
            return

        QApplication.clipboard().setText(
            value_item.text()
        )

    def copy_allowed_path(self) -> None:
        self._copy_table_value(
            self.allowed_table,
            3,
            "Select an Allowed item first.",
        )

    def _open_file_location(
        self,
        path_text: str,
        folder_only: bool = False,
    ) -> None:
        expanded_path = os.path.expandvars(path_text)
        path = Path(expanded_path)

        target = (
            path
            if folder_only
            else path.parent
        )

        try:
            os.startfile(str(target))
        except OSError as error:
            QMessageBox.critical(
                self,
                "Startup Monitor",
                f"The location could not be opened.\n\n{error}",
            )

    def _open_registry_location(
        self,
        registry_path: str,
    ) -> None:
        registry_path = registry_path.split(
            "|",
            1,
        )[0].rstrip("\\")

        target = REGISTRY_TARGETS.get(registry_path)

        if target is not None:
            registry_path = (
                f"{target.hive_name}\\{target.subkey}"
            )

        upper_path = registry_path.upper()

        if upper_path == "HKLM":
            registry_path = "HKEY_LOCAL_MACHINE"
        elif upper_path.startswith("HKLM\\"):
            registry_path = (
                "HKEY_LOCAL_MACHINE\\"
                + registry_path[5:]
            )
        elif upper_path == "HKCU":
            registry_path = "HKEY_CURRENT_USER"
        elif upper_path.startswith("HKCU\\"):
            registry_path = (
                "HKEY_CURRENT_USER\\"
                + registry_path[5:]
            )
        elif not upper_path.startswith(
            (
                "HKEY_LOCAL_MACHINE",
                "HKEY_CURRENT_USER",
            )
        ):
            QMessageBox.information(
                self,
                "Startup Monitor",
                "This item does not contain a registry "
                "location that can be opened.",
            )
            return

        try:
            with winreg.CreateKey(
                winreg.HKEY_CURRENT_USER,
                (
                    "Software\\Microsoft\\Windows\\"
                    "CurrentVersion\\Applets\\Regedit"
                ),
            ) as key:
                winreg.SetValueEx(
                    key,
                    "LastKey",
                    0,
                    winreg.REG_SZ,
                    "Computer\\" + registry_path,
                )

            subprocess.Popen(["regedit.exe"])
        except OSError as error:
            QMessageBox.critical(
                self,
                "Startup Monitor",
                f"RegEdit could not be opened.\n\n{error}",
            )

    def _open_task_scheduler(self) -> None:
        try:
            subprocess.Popen(
                [
                    "mmc.exe",
                    "taskschd.msc",
                ]
            )
        except OSError as error:
            QMessageBox.critical(
                self,
                "Startup Monitor",
                f"Task Scheduler could not be opened.\n\n{error}",
            )

    def go_to_allowed_item(self) -> None:
        row = self.allowed_table.currentRow()

        if row < 0:
            return

        type_item = self.allowed_table.item(row, 2)
        key_item = self.allowed_table.item(row, 3)

        if type_item is None or key_item is None:
            return

        item_type = type_item.text()
        target = key_item.text()

        if item_type == "File":
            if target.startswith(RULE_FILE_NAME):
                QMessageBox.information(
                    self,
                    "Startup Monitor",
                    (
                        "This Allowed rule contains only a "
                        "filename, not a folder path, so there "
                        "is no specific location to open."
                    ),
                )
                return

            self._open_file_location(target)

        elif item_type == "Registry":
            if target.startswith(RULE_REG_EXACT):
                target = target[len(RULE_REG_EXACT):]
            elif target.startswith(RULE_REG_PREFIX):
                target = target[len(RULE_REG_PREFIX):]

            self._open_registry_location(target)

        elif item_type == "Task":
            self._open_task_scheduler()

    def go_to_base_startup_item(self) -> None:
        row = self.base_startup_table.currentRow()

        if row < 0:
            return

        type_item = self.base_startup_table.item(row, 3)
        path_item = self.base_startup_table.item(row, 4)

        if type_item is None or path_item is None:
            return

        if type_item.text() == "File":
            self._open_file_location(path_item.text())

        elif type_item.text() == "Registry":
            self._open_registry_location(path_item.text())

    def go_to_base_task_item(self) -> None:
        if self.base_tasks_table.currentRow() < 0:
            return

        self._open_task_scheduler()

    def _show_standard_action_context_menu(
        self,
        table: QTableWidget,
        position,
        remove_callback: Callable[[], None],
        refresh_callback: Callable[[], None],
        copy_callback: Callable[[], None],
        clicked_callback: Optional[
            Callable[[QTableWidgetItem], None]
        ] = None,
        go_to_callback: Optional[
            Callable[[], None]
        ] = None,
    ) -> None:
        clicked_index = table.indexAt(position)

        self._prepare_action_context_selection(
            table,
            clicked_index,
        )

        if (
            clicked_callback is not None
            and clicked_index.isValid()
        ):
            clicked_item = table.item(
                clicked_index.row(),
                clicked_index.column(),
            )

            if clicked_item is not None:
                clicked_callback(clicked_item)

        menu = QMenu(self)

        remove_action = menu.addAction("Remove")
        refresh_action = menu.addAction("Refresh")
        copy_action = menu.addAction("Copy Path")

        go_to_action = None

        if go_to_callback is not None:
            menu.addSeparator()
            go_to_action = menu.addAction("Go to...")

        remove_action.setEnabled(clicked_index.isValid())
        copy_action.setEnabled(clicked_index.isValid())

        if go_to_action is not None:
            go_to_action.setEnabled(clicked_index.isValid())

        selected_action = menu.exec(
            table.viewport().mapToGlobal(position)
        )

        if selected_action == remove_action:
            if table is not self.location_table:
                self._sync_action_checkboxes_from_selection(
                    table
                )

            remove_callback()

        elif selected_action == refresh_action:
            refresh_callback()

        elif selected_action == copy_action:
            copy_callback()

        elif (
            go_to_action is not None
            and selected_action == go_to_action
        ):
            go_to_callback()

    def show_allowed_context_menu(self, position) -> None:
        self._show_standard_action_context_menu(
            self.allowed_table,
            position,
            self.remove_checked_allowed,
            self.refresh_allowed,
            self.copy_allowed_path,
            go_to_callback=self.go_to_allowed_item,
        )

    def add_denied_rule(self) -> None:
        self._add_decision_rule(
            "Denied",
            self.denied,
            self._populate_denied_table,
            "denied_rule_add",
        )

    def _build_denied_tab(self, tabs: QTabWidget) -> None:
        (
            tab,
            self.denied_table,
            self.denied_confirmation,
            self.denied_confirmation_label,
        ) = self._create_decision_tab(
            self.add_denied_rule,
            self.remove_checked_denied,
            self.confirm_remove_denied,
            self.cancel_remove_denied,
            self.show_denied_context_menu,
        )

        self._populate_denied_table()
        self.denied_table.setSortingEnabled(True)
        self.pending_denied_removals: List[str] = []

        tabs.addTab(tab, "Denied")

    def _populate_denied_table(self) -> None:
        self._populate_decision_table(
            self.denied_table,
            self.denied,
        )

    def _checked_denied_keys(self) -> List[str]:
        return self._checked_column_values(
            self.denied_table,
            3,
        )

    def remove_checked_denied(self) -> None:
        keys = self._request_decision_removal(
            self.denied_table,
            "Denied",
            self.denied_confirmation,
            self.denied_confirmation_label,
        )

        if keys is not None:
            self.pending_denied_removals = keys

    def confirm_remove_denied(self) -> None:
        keys = list(
            self.pending_denied_removals
        )

        self._confirm_decision_removal(
            keys,
            self.denied,
            self.denied_confirmation,
            self._populate_denied_table,
            "denied_remove",
        )

        self.pending_denied_removals = []

    def cancel_remove_denied(self) -> None:
        self.pending_denied_removals = []
        self._cancel_decision_removal(
            self.denied_confirmation
        )

    def refresh_denied(self) -> None:
        _loaded_allowed, loaded_denied = (
            self.store.load_allowed_denied()
        )

        self.denied.clear()
        self.denied.update(loaded_denied)
        self._populate_denied_table()

    def copy_denied_path(self) -> None:
        self._copy_table_value(
            self.denied_table,
            3,
            "Select a Denied item first.",
        )

    def show_denied_context_menu(self, position) -> None:
        self._show_standard_action_context_menu(
            self.denied_table,
            position,
            self.remove_checked_denied,
            self.refresh_denied,
            self.copy_denied_path,
        )

    def refresh_decision_lists(self) -> None:
        self.allowed.clear()
        self.allowed.update(self.engine.allowed)

        self.denied.clear()
        self.denied.update(self.engine.denied)

        self._populate_allowed_table()
        self._populate_denied_table()

    def _create_base_table(
        self,
        context_menu_callback: Callable,
        path_callback: Callable[
            [QTableWidgetItem],
            None,
        ],
    ) -> QTableWidget:
        table = QTableWidget(0, 6)
        table.setHorizontalHeaderLabels(
            [
                "Select",
                "#",
                "Name",
                "Type",
                "Location / Path",
                "Hash",
            ]
        )

        self._configure_action_table(table)

        table.horizontalHeader().setStretchLastSection(
            True
        )

        table.setColumnWidth(0, 45)
        table.setColumnWidth(1, 45)
        table.setColumnWidth(2, 180)
        table.setColumnWidth(3, 55)
        table.setColumnWidth(4, 415)

        table.customContextMenuRequested.connect(
            context_menu_callback
        )
        table.itemClicked.connect(
            path_callback
        )

        return table

    def _build_base_startup_tab(
        self,
        tabs: QTabWidget,
    ) -> None:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        self.base_startup_table = (
            self._create_base_table(
                self.show_base_startup_context_menu,
                self.show_base_startup_path,
            )
        )

        layout.addWidget(self.base_startup_table)
        self._populate_base_startup_table()
        self.base_startup_table.setSortingEnabled(True)

        layout.addLayout(
            self._create_remove_button_row(
                self.remove_checked_base_startup
            )
        )

        self.base_startup_information = (
            self._create_path_information_panel()
        )
        layout.addWidget(self.base_startup_information)

        (
            self.base_startup_confirmation,
            self.base_startup_confirmation_label,
        ) = self._create_confirmation_panel(
            self.confirm_remove_base_startup,
            self.cancel_remove_base_startup,
        )
        layout.addWidget(self.base_startup_confirmation)

        self.pending_base_startup_removals: List[
            tuple[str, str]
        ] = []

        tabs.addTab(tab, "Base Startup")

    def _populate_base_startup_table(self) -> None:
        (
            sorting_enabled,
            sort_column,
            sort_order,
        ) = _capture_table_sort_state(
            self.base_startup_table
        )

        self.base_startup_table.setSortingEnabled(False)
        self.base_startup_table.setRowCount(0)
        number = 1

        for key, value in self.engine.base_folders.items():
            self._add_base_table_row(
                self.base_startup_table,
                number,
                Path(key).name or key,
                "File",
                key,
                value,
                "folder",
            )
            number += 1

        for key, value in self.engine.base_registry.items():
            value_name = (
                key.rsplit("|", 1)[-1]
                if "|" in key
                else key
            )

            self._add_base_table_row(
                self.base_startup_table,
                number,
                value_name or "(Default)",
                "Registry",
                key,
                value,
                "registry",
            )
            number += 1

        self.base_startup_table.resizeRowsToContents()

        _restore_table_sort_state(
            self.base_startup_table,
            sorting_enabled,
            sort_column,
            sort_order,
        )

    @staticmethod
    def _add_base_table_row(
        table: QTableWidget,
        number: int,
        name: str,
        item_type: str,
        path: str,
        item_hash: str,
        source: Optional[str] = None,
    ) -> None:
        row = table.rowCount()
        table.insertRow(row)

        select_item = QTableWidgetItem()
        select_item.setFlags(
            Qt.ItemFlag.ItemIsEnabled
            | Qt.ItemFlag.ItemIsSelectable
            | Qt.ItemFlag.ItemIsUserCheckable
        )
        select_item.setCheckState(
            Qt.CheckState.Unchecked
        )

        number_item = QTableWidgetItem()
        number_item.setData(
            Qt.ItemDataRole.EditRole,
            number,
        )
        number_item.setTextAlignment(
            Qt.AlignmentFlag.AlignCenter
        )

        path_item = QTableWidgetItem(path)

        if source is not None:
            path_item.setData(
                Qt.ItemDataRole.UserRole,
                source,
            )

        table.setItem(
            row,
            0,
            select_item,
        )
        table.setItem(
            row,
            1,
            number_item,
        )
        table.setItem(
            row,
            2,
            QTableWidgetItem(name),
        )

        type_item = QTableWidgetItem(item_type)
        type_item.setForeground(
            item_type_colour(
                item_type,
                table.palette(),
            )
        )

        table.setItem(
            row,
            3,
            type_item,
        )
        table.setItem(
            row,
            4,
            path_item,
        )
        table.setItem(
            row,
            5,
            QTableWidgetItem(item_hash),
        )

    def _checked_base_startup_items(
        self,
    ) -> List[tuple[str, str]]:
        items: List[tuple[str, str]] = []

        for row in range(self.base_startup_table.rowCount()):
            select_item = self.base_startup_table.item(row, 0)
            path_item = self.base_startup_table.item(row, 4)

            if select_item is None or path_item is None:
                continue

            if select_item.checkState() != Qt.CheckState.Checked:
                continue

            source = path_item.data(
                Qt.ItemDataRole.UserRole
            )

            items.append(
                (
                    path_item.text(),
                    str(source),
                )
            )

        return items

    @staticmethod
    def _reset_path_information(
        information: QLabel,
    ) -> None:
        information.setText(
            "Location/Path:"
        )

    @staticmethod
    def _show_table_path(
        table: QTableWidget,
        information: QLabel,
        item: QTableWidgetItem,
    ) -> None:
        path_item = table.item(
            item.row(),
            4,
        )

        if path_item is None:
            return

        information.setText(
            f"Location/Path: {path_item.text()}"
        )

    def show_base_startup_path(
        self,
        item: QTableWidgetItem,
    ) -> None:
        self._show_table_path(
            self.base_startup_table,
            self.base_startup_information,
            item,
        )

    def remove_checked_base_startup(self) -> None:
        items = self._checked_base_startup_items()

        if not items:
            QMessageBox.information(
                self,
                "Startup Monitor",
                "Tick one or more Base Startup items to remove.",
            )
            return

        self.pending_base_startup_removals = items

        if len(items) == 1:
            self.base_startup_confirmation_label.setText(
                "Confirm removal of this entry from "
                "the Base Startup list?\n"
                f"{items[0][0]}"
            )
        else:
            self.base_startup_confirmation_label.setText(
                "Confirm removal of these "
                f"{len(items)} entries from "
                "the Base Startup list?"
            )

        self.base_startup_confirmation.setVisible(True)

    def confirm_remove_base_startup(self) -> None:
        items = list(
            self.pending_base_startup_removals
        )

        if not items:
            self.base_startup_confirmation.setVisible(False)
            return

        for key, source in items:
            if source == "folder":
                self.engine.base_folders.pop(key, None)
            elif source == "registry":
                self.engine.base_registry.pop(key, None)

        self.store.save_startup_baseline(
            self.engine.base_folders,
            self.engine.base_registry,
        )
        self.engine.reload_all(create_baselines=False)
        self.engine.log(
            "SETTINGS",
            "gui",
            "base_startup_remove",
            f"{len(items)} item(s) removed",
            "SUCCESS",
        )

        self.pending_base_startup_removals = []
        self.base_startup_confirmation.setVisible(False)
        self._reset_path_information(
            self.base_startup_information
        )
        self._populate_base_startup_table()

    def cancel_remove_base_startup(self) -> None:
        self.pending_base_startup_removals = []
        self.base_startup_confirmation.setVisible(False)

    def refresh_base_startup(self) -> None:
        (
            base_folders,
            base_registry,
            _base_tasks,
        ) = self.store.load_baselines()

        self.engine.base_folders.clear()
        self.engine.base_folders.update(base_folders)

        self.engine.base_registry.clear()
        self.engine.base_registry.update(base_registry)

        self.cancel_remove_base_startup()
        self._reset_path_information(
            self.base_startup_information
        )
        self._populate_base_startup_table()

    def copy_base_startup_path(self) -> None:
        self._copy_table_value(
            self.base_startup_table,
            4,
            "Select a Base Startup item first.",
        )

    def show_base_startup_context_menu(
        self,
        position,
    ) -> None:
        self._show_standard_action_context_menu(
            self.base_startup_table,
            position,
            self.remove_checked_base_startup,
            self.refresh_base_startup,
            self.copy_base_startup_path,
            self.show_base_startup_path,
            self.go_to_base_startup_item,
        )

    def _build_base_tasks_tab(
        self,
        tabs: QTabWidget,
    ) -> None:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        self.base_tasks_table = (
            self._create_base_table(
                self.show_base_tasks_context_menu,
                self.show_base_task_path,
            )
        )

        layout.addWidget(self.base_tasks_table)
        self._populate_base_tasks_table()
        self.base_tasks_table.setSortingEnabled(True)

        layout.addLayout(
            self._create_remove_button_row(
                self.remove_checked_base_tasks
            )
        )

        self.base_tasks_information = (
            self._create_path_information_panel()
        )
        layout.addWidget(self.base_tasks_information)

        (
            self.base_tasks_confirmation,
            self.base_tasks_confirmation_label,
        ) = self._create_confirmation_panel(
            self.confirm_remove_base_tasks,
            self.cancel_remove_base_tasks,
        )
        layout.addWidget(self.base_tasks_confirmation)

        self.pending_base_task_removals: List[str] = []

        tabs.addTab(tab, "Base Tasks")

    def _populate_base_tasks_table(self) -> None:
        (
            sorting_enabled,
            sort_column,
            sort_order,
        ) = _capture_table_sort_state(
            self.base_tasks_table
        )

        self.base_tasks_table.setSortingEnabled(False)
        self.base_tasks_table.setRowCount(0)

        for number, (key, value) in enumerate(
            self.engine.base_tasks.items(),
            start=1,
        ):
            task_name = key.rstrip("\\").rsplit(
                "\\",
                1,
            )[-1]

            self._add_base_table_row(
                self.base_tasks_table,
                number,
                task_name or key,
                "Task",
                key,
                value,
            )

        self.base_tasks_table.resizeRowsToContents()

        _restore_table_sort_state(
            self.base_tasks_table,
            sorting_enabled,
            sort_column,
            sort_order,
        )

    def _checked_base_task_keys(self) -> List[str]:
        return self._checked_column_values(
            self.base_tasks_table,
            4,
        )

    def show_base_task_path(
        self,
        item: QTableWidgetItem,
    ) -> None:
        self._show_table_path(
            self.base_tasks_table,
            self.base_tasks_information,
            item,
        )

    def remove_checked_base_tasks(self) -> None:
        keys = self._checked_base_task_keys()

        if not keys:
            QMessageBox.information(
                self,
                "Startup Monitor",
                "Tick one or more Base Tasks to remove.",
            )
            return

        self.pending_base_task_removals = keys

        if len(keys) == 1:
            self.base_tasks_confirmation_label.setText(
                "Confirm removal of this task from "
                "the Base Tasks list?\n"
                f"{keys[0]}"
            )
        else:
            self.base_tasks_confirmation_label.setText(
                "Confirm removal of these "
                f"{len(keys)} tasks from "
                "the Base Tasks list?"
            )

        self.base_tasks_confirmation.setVisible(True)

    def confirm_remove_base_tasks(self) -> None:
        keys = list(self.pending_base_task_removals)

        if not keys:
            self.base_tasks_confirmation.setVisible(False)
            return

        for key in keys:
            self.engine.base_tasks.pop(key, None)

        self.store.save_task_baseline(
            self.engine.base_tasks
        )
        self.engine.reload_all(create_baselines=False)
        self.engine.log(
            "SETTINGS",
            "gui",
            "base_tasks_remove",
            f"{len(keys)} item(s) removed",
            "SUCCESS",
        )

        self.pending_base_task_removals = []
        self.base_tasks_confirmation.setVisible(False)
        self._reset_path_information(
            self.base_tasks_information
        )
        self._populate_base_tasks_table()

    def cancel_remove_base_tasks(self) -> None:
        self.pending_base_task_removals = []
        self.base_tasks_confirmation.setVisible(False)

    def refresh_base_tasks(self) -> None:
        (
            _base_folders,
            _base_registry,
            base_tasks,
        ) = self.store.load_baselines()

        self.engine.base_tasks.clear()
        self.engine.base_tasks.update(base_tasks)

        self.cancel_remove_base_tasks()
        self._reset_path_information(
            self.base_tasks_information
        )
        self._populate_base_tasks_table()

    def copy_base_task_path(self) -> None:
        self._copy_table_value(
            self.base_tasks_table,
            4,
            "Select a Base Task first.",
        )

    def show_base_tasks_context_menu(
        self,
        position,
    ) -> None:
        self._show_standard_action_context_menu(
            self.base_tasks_table,
            position,
            self.remove_checked_base_tasks,
            self.refresh_base_tasks,
            self.copy_base_task_path,
            self.show_base_task_path,
            self.go_to_base_task_item,
        )

    def _build_log_tab(self, tabs: QTabWidget) -> None:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        self.log_table = QTableWidget(0, 7)
        self.log_table.setHorizontalHeaderLabels(
            [
                "#",
                "Timestamp",
                "Event",
                "Type",
                "Key",
                "Detail",
                "Status",
            ]
        )
        self.log_table.setSelectionBehavior(
            QAbstractItemView.SelectionBehavior.SelectRows
        )
        self.log_table.setSelectionMode(
            QAbstractItemView.SelectionMode.ExtendedSelection
        )
        self.log_table.setEditTriggers(
            QAbstractItemView.EditTrigger.NoEditTriggers
        )
        self.log_table.verticalHeader().setVisible(False)
        self.log_table.horizontalHeader().setStretchLastSection(
            False
        )

        self.log_table.setColumnWidth(0, 45)
        self.log_table.setColumnWidth(1, 120)
        self.log_table.setColumnWidth(2, 110)
        self.log_table.setColumnWidth(3, 75)
        self.log_table.setColumnWidth(4, 170)
        self.log_table.setColumnWidth(5, 300)
        self.log_table.setColumnWidth(6, 90)

        self.log_table.itemClicked.connect(
            self.show_log_details
        )

        layout.addWidget(self.log_table)

        self.log_information = (
            self._create_path_information_panel()
        )
        self.log_information.setTextFormat(
            Qt.TextFormat.PlainText
        )
        self.log_information.setTextInteractionFlags(
            Qt.TextInteractionFlag.TextSelectableByMouse
        )
        self.log_information.setText(
            "Log Details:\n"
            "Select a log entry to view its full details."
        )
        self.log_information.setMinimumHeight(48)
        self.log_information.setMaximumHeight(60)

        self.log_table.setSortingEnabled(True)
        self.log_table.sortItems(
            0,
            Qt.SortOrder.DescendingOrder,
        )
        self.refresh_log_table()
        self.log_table.scrollToTop()

        buttons = QHBoxLayout()

        delete_button = QPushButton("Delete Log")
        delete_button.clicked.connect(self.delete_log)
        buttons.addWidget(delete_button)

        copy_button = QPushButton("Copy Log")
        copy_button.clicked.connect(self.copy_log)
        buttons.addWidget(copy_button)

        buttons.addStretch()

        self.log_information_close_button = QPushButton(
            "Close"
        )
        self.log_information_close_button.clicked.connect(
            self.close_log_details
        )
        self.log_information_close_button.setVisible(False)
        buttons.addWidget(
            self.log_information_close_button
        )

        layout.addLayout(buttons)
        layout.addWidget(self.log_information)

        tabs.addTab(tab, "Log")

    def close_log_details(self) -> None:
        self.log_information.setText(
            "Log Details:\n"
            "Select a log entry to view its full details."
        )
        self.log_information.setMinimumHeight(48)
        self.log_information.setMaximumHeight(60)
        self.log_information_close_button.setVisible(False)

    def show_log_details(
        self,
        item: QTableWidgetItem,
    ) -> None:
        row = item.row()

        def cell_text(column: int) -> str:
            cell = self.log_table.item(
                row,
                column,
            )

            if cell is None:
                return ""

            return cell.text()

        timestamp = cell_text(1)
        event = cell_text(2)
        item_type = cell_text(3)
        key = cell_text(4)
        detail = cell_text(5)
        status = cell_text(6)

        self.log_information.setMinimumHeight(100)
        self.log_information.setMaximumHeight(16777215)
        self.log_information.setText(
            "Log Details:\n\n"
            f"Timestamp: {timestamp}\n"
            f"Event: {event}\n"
            f"Type: {item_type}\n"
            f"Status: {status}\n\n"
            f"Key:\n{key}\n\n"
            f"Detail:\n{detail}"
        )

        self.log_information_close_button.setVisible(True)

    def _log_event_colour(
        self,
        event: str,
    ) -> QColor:
        is_dark = (
            self.palette()
            .color(QPalette.ColorRole.Window)
            .lightness()
            < 128
        )

        event_upper = event.upper()

        if (
            "ERROR" in event_upper
            or "FAILED" in event_upper
            or "DENIED" in event_upper
            or "DELETE" in event_upper
            or "REMOVE" in event_upper
        ):
            return QColor(
                "#ff8080"
                if is_dark
                else "#a00000"
            )

        if (
            "MODIFIED" in event_upper
            or "RECREATED" in event_upper
            or "WARNING" in event_upper
        ):
            return QColor(
                "#ffc966"
                if is_dark
                else "#9a5b00"
            )

        if (
            "NEW" in event_upper
            or "DETECT" in event_upper
        ):
            return QColor(
                "#82c7ff"
                if is_dark
                else "#005fa8"
            )

        if (
            "SETTINGS" in event_upper
            or "CONFIG" in event_upper
        ):
            return QColor(
                "#d6a1ff"
                if is_dark
                else "#6f2da8"
            )

        if "REVIEW_ALLOW" in event_upper:
            return QColor(
                "#8ed9b6"
                if is_dark
                else "#176b48"
            )

        if "SHUTDOWN" in event_upper:
            return QColor(
                "#a9c7e8"
                if is_dark
                else "#416987"
            )

        if (
            "MONITOR" in event_upper
            or "STARTUP" in event_upper
            or "BASELINE" in event_upper
        ):
            return QColor(
                "#8ed9b6"
                if is_dark
                else "#176b48"
            )

        return self.palette().color(
            QPalette.ColorRole.Text
        )

    def _log_type_colour(
        self,
        item_type: str,
    ) -> QColor:
        is_dark = (
            self.palette()
            .color(QPalette.ColorRole.Window)
            .lightness()
            < 128
        )

        normalised_type = item_type.strip().casefold()

        if normalised_type == "gui":
            return QColor(
                "#5ED6D6"
                if is_dark
                else "#007C7C"
            )

        if normalised_type == "application":
            return QColor(
                "#FFB86C"
                if is_dark
                else "#A85A00"
            )

        return item_type_colour(
            item_type,
            self.log_table.palette(),
        )

    def _log_file_signature(
        self,
    ) -> Optional[tuple[int, int]]:
        try:
            file_stat = self.paths.log.stat()
        except OSError:
            return None

        return (
            file_stat.st_mtime_ns,
            file_stat.st_size,
        )

    def _refresh_log_if_changed(self) -> None:
        current_signature = self._log_file_signature()

        if current_signature == self.log_file_signature:
            return

        self.log_file_signature = current_signature

        self.refresh_log_table(
            preserve_view=True
        )

    def refresh_log_table(
        self,
        preserve_view: bool = False,
    ) -> None:
        (
            sorting_enabled,
            sort_column,
            sort_order,
        ) = _capture_table_sort_state(
            self.log_table
        )

        scroll_bar = self.log_table.verticalScrollBar()
        previous_scroll_value = scroll_bar.value()
        previous_at_top = (
            previous_scroll_value
            <= scroll_bar.minimum()
        )
        previous_at_bottom = (
            previous_scroll_value
            >= scroll_bar.maximum()
        )

        self.log_table.setSortingEnabled(False)
        self.log_table.setRowCount(0)

        if not self.paths.log.exists():
            _restore_table_sort_state(
                self.log_table,
                sorting_enabled,
                sort_column,
                sort_order,
            )
            return

        try:
            lines = self.paths.log.read_text(
                encoding="utf-8",
                errors="replace",
            ).splitlines()
        except OSError as error:
            QMessageBox.critical(
                self,
                "Startup Monitor",
                f"The log file could not be read.\n\n{error}",
            )
            _restore_table_sort_state(
                self.log_table,
                sorting_enabled,
                sort_column,
                sort_order,
            )
            return

        for number, line in enumerate(lines, start=1):
            if not line.strip():
                continue

            parts = line.split(" | ", 5)

            if len(parts) == 6:
                timestamp, event, item_type, key, detail, status = (
                    parts
                )
            else:
                timestamp = ""
                event = ""
                item_type = ""
                key = ""
                detail = line
                status = ""

            normalised_type = item_type.strip().casefold()

            if normalised_type in ("reg", "registry"):
                item_type = "Registry"
            elif normalised_type == "file":
                item_type = "File"
            elif normalised_type == "folder":
                item_type = "Folder"
            elif normalised_type == "task":
                item_type = "Task"
            elif normalised_type == "gui":
                item_type = "Gui"
            elif normalised_type == "application":
                item_type = "Application"
            elif item_type:
                item_type = item_type.strip().capitalize()

            row = self.log_table.rowCount()
            self.log_table.insertRow(row)

            number_item = QTableWidgetItem()
            number_item.setData(
                Qt.ItemDataRole.EditRole,
                number,
            )
            number_item.setTextAlignment(
                Qt.AlignmentFlag.AlignCenter
            )

            self.log_table.setItem(row, 0, number_item)

            timestamp_item = QTableWidgetItem(timestamp)
            timestamp_item.setTextAlignment(
                Qt.AlignmentFlag.AlignCenter
            )

            self.log_table.setItem(
                row,
                1,
                timestamp_item,
            )

            event_item = QTableWidgetItem(event)
            event_item.setForeground(
                self._log_event_colour(event)
            )

            self.log_table.setItem(
                row,
                2,
                event_item,
            )

            type_colour = self._log_type_colour(
                item_type
            )

            type_item = QTableWidgetItem(item_type)
            type_item.setForeground(type_colour)

            self.log_table.setItem(
                row,
                3,
                type_item,
            )
            self.log_table.setItem(
                row,
                4,
                QTableWidgetItem(key),
            )
            self.log_table.setItem(
                row,
                5,
                QTableWidgetItem(detail),
            )

            status_item = QTableWidgetItem(status)

            if item_type in ("Gui", "Application"):
                status_item.setForeground(type_colour)
            else:
                status_item.setForeground(
                    self._log_event_colour(event)
                )

            self.log_table.setItem(
                row,
                6,
                status_item,
            )

        self.log_table.resizeRowsToContents()

        _restore_table_sort_state(
            self.log_table,
            sorting_enabled,
            sort_column,
            sort_order,
        )

        if self.log_table.rowCount() > 0:
            if preserve_view:
                if previous_at_top:
                    self.log_table.scrollToTop()
                elif previous_at_bottom:
                    self.log_table.scrollToBottom()
                else:
                    scroll_bar.setValue(
                        min(
                            previous_scroll_value,
                            scroll_bar.maximum(),
                        )
                    )
            else:
                self.log_table.scrollToBottom()

    def delete_log(self) -> None:
        if not self.paths.log.exists():
            QMessageBox.information(
                self,
                "Startup Monitor",
                "The log file is already empty.",
            )
            self.refresh_log_table()
            return

        selected_button = QMessageBox.question(
            self,
            "Delete Log",
            "Delete the entire Startup Monitor log?",
            QMessageBox.StandardButton.Yes
            | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )

        if selected_button != QMessageBox.StandardButton.Yes:
            return

        try:
            self.paths.log.unlink()
        except OSError as error:
            QMessageBox.critical(
                self,
                "Startup Monitor",
                f"The log file could not be deleted.\n\n{error}",
            )
            return

        self.refresh_log_table()

    def copy_log(self) -> None:
        if not self.paths.log.exists():
            QMessageBox.information(
                self,
                "Startup Monitor",
                "There is no log content to copy.",
            )
            return

        try:
            log_text = self.paths.log.read_text(
                encoding="utf-8",
                errors="replace",
            )
        except OSError as error:
            QMessageBox.critical(
                self,
                "Startup Monitor",
                f"The log file could not be read.\n\n{error}",
            )
            return

        if not log_text:
            QMessageBox.information(
                self,
                "Startup Monitor",
                "There is no log content to copy.",
            )
            return

        QApplication.clipboard().setText(log_text)

        QMessageBox.information(
            self,
            "Startup Monitor",
            "The complete log has been copied to the clipboard.",
        )

    def _position_about_icon(self) -> None:
        if not hasattr(
            self,
            "about_icon_label",
        ):
            return

        if not hasattr(
            self,
            "about_tab",
        ):
            return

        margin = 18

        self.about_icon_label.move(
            self.about_tab.width()
            - self.about_icon_label.width()
            - margin,
            margin,
        )
        self.about_icon_label.raise_()

    def _build_about_tab(self, tabs: QTabWidget) -> None:
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(18, 18, 18, 18)
        layout.setSpacing(14)

        self.about_tab = tab
        self.about_tab.installEventFilter(self)

        self.about_icon_label = QLabel(tab)
        self.about_icon_label.setFixedSize(
            96,
            96,
        )
        self.about_icon_label.setAlignment(
            Qt.AlignmentFlag.AlignCenter
        )

        if self.paths.icon.exists():
            self.about_icon_label.setPixmap(
                QIcon(
                    str(self.paths.icon)
                ).pixmap(
                    96,
                    96,
                )
            )

        self.about_icon_label.show()
        self.about_icon_label.raise_()

        title = QLabel(APP_NAME)
        title.setStyleSheet(
            "font-size: 17pt;"
            "font-weight: bold;"
        )
        layout.addWidget(title)

        QTimer.singleShot(
            0,
            self._position_about_icon,
        )

        information = QLabel(
            f"Version: {APP_VERSION}<br>"
            f"Build Date: {BUILD_DATE}<br>"
            f"Today's Date: {date.today().isoformat()}"
        )
        information.setTextFormat(Qt.TextFormat.RichText)
        layout.addWidget(information)

        layout.addSpacing(16)

        description_title = QLabel("Description:")
        description_title.setStyleSheet(
            "font-weight: bold;"
            "font-size: 10pt;"
        )
        layout.addWidget(description_title)

        description = QLabel(
            "Monitors Windows startup locations for new or modified "
            "entries. Provides real-time detection of startup "
            "modifications including files, registry entries, and "
            "scheduled tasks. Maintains a baseline of existing items "
            "to reduce false alerts."
        )
        description.setWordWrap(True)
        layout.addWidget(description)

        layout.addSpacing(14)

        features_title = QLabel("Features:")
        features_title.setStyleSheet(
            "font-weight: bold;"
            "font-size: 10pt;"
        )
        layout.addWidget(features_title)

        features = QLabel(
            "• Real-time monitoring of startup locations<br>"
            "• File, registry, and scheduled task detection<br>"
            "• Baseline management to reduce false alerts<br>"
            "• Automatic removal of denied items<br>"
            "• Configurable monitoring intervals<br>"
            "• Comprehensive logging and reporting"
        )
        features.setTextFormat(Qt.TextFormat.RichText)
        layout.addWidget(features)

        layout.addStretch()

        author = QLabel(f"Author: {APP_AUTHOR}")
        layout.addWidget(author)

        github = QLabel(
            f'GitHub: <a href="{APP_GITHUB_URL}">'
            f"{APP_GITHUB_URL}</a>"
        )
        github.setTextFormat(Qt.TextFormat.RichText)
        github.setOpenExternalLinks(True)
        github.setTextInteractionFlags(
            Qt.TextInteractionFlag.TextBrowserInteraction
        )
        layout.addWidget(github)

        license_label = QLabel(f"License: {APP_LICENSE}")
        layout.addWidget(license_label)

        tabs.addTab(tab, "About")

    def _refresh_location_table(self) -> None:
        (
            sorting_enabled,
            sort_column,
            sort_order,
        ) = _capture_table_sort_state(
            self.location_table
        )

        self.location_table.setSortingEnabled(False)
        self.location_table.setRowCount(0)

        for path, enabled in self.folders.items():
            self._add_location_row(path, "Folder", enabled)

        for location, enabled in self.registry_tokens.items():
            self._add_location_row(location, "Registry", enabled)

        self.location_table.resizeRowsToContents()

        _restore_table_sort_state(
            self.location_table,
            sorting_enabled,
            sort_column,
            sort_order,
        )

    def _add_location_row(
        self,
        location: str,
        location_type: str,
        enabled: str,
    ) -> None:
        row = self.location_table.rowCount()
        self.location_table.insertRow(row)

        enabled_item = QTableWidgetItem()
        enabled_item.setFlags(
            Qt.ItemFlag.ItemIsEnabled
            | Qt.ItemFlag.ItemIsSelectable
            | Qt.ItemFlag.ItemIsUserCheckable
        )
        enabled_item.setCheckState(
            Qt.CheckState.Checked
            if enabled == "1"
            else Qt.CheckState.Unchecked
        )

        location_item = QTableWidgetItem(location)
        location_item.setData(Qt.ItemDataRole.UserRole, location)

        type_item = QTableWidgetItem(location_type)
        type_item.setForeground(
            item_type_colour(
                location_type,
                self.location_table.palette(),
            )
        )

        self.location_table.setItem(row, 0, enabled_item)
        self.location_table.setItem(row, 1, location_item)
        self.location_table.setItem(row, 2, type_item)

    def _selected_location_rows(self) -> List[int]:
        return sorted(
            {
                index.row()
                for index in self.location_table.selectionModel().selectedRows()
            }
        )

    def add_folder(self) -> None:
        selected = QFileDialog.getExistingDirectory(
            self,
            "Select folder",
        )

        if not selected:
            return

        selected = str(Path(selected))

        if selected in self.folders:
            QMessageBox.information(
                self,
                "Startup Monitor",
                "That folder is already in the Locations list.",
            )
            return

        self.folders[selected] = "1"
        self._refresh_location_table()

    def add_registry_path(self) -> None:
        value, accepted = QInputDialog.getText(
            self,
            "Add Registry Path",
            (
                "Enter a Registry key path.\n\n"
                "Examples:\n"
                "HKCU\\Software\\Vendor\\Product\n"
                "HKEY_LOCAL_MACHINE\\Software\\Vendor\\Product"
            ),
        )

        if not accepted:
            return

        value = value.strip()

        if not value:
            return

        if value.lower().startswith("computer\\"):
            value = value[9:]

        if value in self.registry_tokens:
            QMessageBox.information(
                self,
                "Startup Monitor",
                "That Registry path is already in the Locations list.",
            )
            return

        upper_value = value.upper()

        valid_prefixes = (
            "HKCU\\",
            "HKLM\\",
            "HKEY_CURRENT_USER\\",
            "HKEY_LOCAL_MACHINE\\",
        )

        if not upper_value.startswith(valid_prefixes):
            QMessageBox.warning(
                self,
                "Invalid Registry Path",
                (
                    "The Registry path must begin with one of:\n\n"
                    "HKCU\\\n"
                    "HKLM\\\n"
                    "HKEY_CURRENT_USER\\\n"
                    "HKEY_LOCAL_MACHINE\\"
                ),
            )
            return

        self.registry_tokens[value] = "1"
        self._refresh_location_table()

    def edit_selected_location(self) -> None:
        rows = self._selected_location_rows()

        if len(rows) != 1:
            QMessageBox.information(
                self,
                "Startup Monitor",
                "Select one location to edit.",
            )
            return

        row = rows[0]
        location_item = self.location_table.item(row, 1)
        type_item = self.location_table.item(row, 2)

        if location_item is None or type_item is None:
            return

        old_location = location_item.text()
        location_type = type_item.text()

        new_location, accepted = QInputDialog.getText(
            self,
            f"Edit {location_type} Location",
            "Location:",
            text=old_location,
        )

        if not accepted:
            return

        new_location = new_location.strip()

        if not new_location or new_location == old_location:
            return

        if location_type == "Folder":
            if new_location in self.folders:
                QMessageBox.information(
                    self,
                    "Startup Monitor",
                    "That folder is already in the Locations list.",
                )
                return

            enabled = self.folders.pop(old_location, "1")
            self.folders[new_location] = enabled
        else:
            if new_location in self.registry_tokens:
                QMessageBox.information(
                    self,
                    "Startup Monitor",
                    "That Registry path is already in the Locations list.",
                )
                return

            enabled = self.registry_tokens.pop(old_location, "1")
            self.registry_tokens[new_location] = enabled

        self._refresh_location_table()

    def toggle_selected_locations(self) -> None:
        rows = self._selected_location_rows()

        if not rows:
            QMessageBox.information(
                self,
                "Startup Monitor",
                "Select one or more locations first.",
            )
            return

        all_checked = all(
            self.location_table.item(row, 0) is not None
            and self.location_table.item(row, 0).checkState()
            == Qt.CheckState.Checked
            for row in rows
        )

        new_state = (
            Qt.CheckState.Unchecked
            if all_checked
            else Qt.CheckState.Checked
        )

        for row in rows:
            enabled_item = self.location_table.item(row, 0)

            if enabled_item is not None:
                enabled_item.setCheckState(new_state)

        self._sync_locations_from_table()

    def request_remove_locations(self) -> None:
        rows = self._selected_location_rows()

        if not rows:
            QMessageBox.information(
                self,
                "Startup Monitor",
                "Select one or more locations to remove.",
            )
            return

        pending: List[tuple[str, str]] = []

        for row in rows:
            location_item = self.location_table.item(row, 1)
            type_item = self.location_table.item(row, 2)

            if location_item is None or type_item is None:
                continue

            pending.append(
                (
                    location_item.text(),
                    type_item.text(),
                )
            )

        if not pending:
            return

        self.pending_location_removals = pending

        if len(pending) == 1:
            location, location_type = pending[0]
            self.location_confirmation_label.setText(
                f"Are you sure you want to remove this "
                f"{location_type.lower()} location?\n{location}"
            )
        else:
            self.location_confirmation_label.setText(
                f"Are you sure you want to remove these "
                f"{len(pending)} locations?"
            )

        self.location_confirmation.setVisible(True)

    def confirm_remove_locations(self) -> None:
        for location, location_type in self.pending_location_removals:
            if location_type == "Folder":
                self.folders.pop(location, None)
            else:
                self.registry_tokens.pop(location, None)

        self.pending_location_removals = []
        self.location_confirmation.setVisible(False)
        self._refresh_location_table()

    def cancel_remove_locations(self) -> None:
        self.pending_location_removals = []
        self.location_confirmation.setVisible(False)

    def refresh_locations(self) -> None:
        self.folders.clear()
        self.registry_tokens.clear()

        loaded_folders, loaded_registry = self.store.load_locations()

        self.folders.update(loaded_folders)
        self.registry_tokens.update(loaded_registry)

        self.cancel_remove_locations()
        self._refresh_location_table()

    def show_locations_context_menu(self, position) -> None:
        clicked_index = self.location_table.indexAt(position)

        self._prepare_action_context_selection(
            self.location_table,
            clicked_index,
        )

        menu = QMenu(self)

        edit_action = menu.addAction("Edit")
        remove_action = menu.addAction("Remove")
        menu.addSeparator()

        refresh_action = menu.addAction("Refresh")
        menu.addSeparator()

        add_folder_action = menu.addAction("Add Folder")
        add_registry_action = menu.addAction("Add Registry Path")
        menu.addSeparator()

        go_to_action = menu.addAction("Go to...")

        edit_action.setEnabled(clicked_index.isValid())
        remove_action.setEnabled(clicked_index.isValid())
        go_to_action.setEnabled(clicked_index.isValid())

        selected_action = menu.exec(
            self.location_table.viewport().mapToGlobal(position)
        )

        if selected_action == edit_action:
            if not clicked_index.isValid():
                return

            self.location_table.clearSelection()
            self.location_table.selectRow(clicked_index.row())
            self.location_table.setCurrentCell(
                clicked_index.row(),
                clicked_index.column(),
            )
            self.edit_selected_location()

        elif selected_action == remove_action:
            if not clicked_index.isValid():
                return

            self.request_remove_locations()

        elif selected_action == refresh_action:
            self.refresh_locations()

        elif selected_action == add_folder_action:
            self.add_folder()

        elif selected_action == add_registry_action:
            self.add_registry_path()

        elif selected_action == go_to_action:
            if not clicked_index.isValid():
                return

            row = clicked_index.row()
            location_item = self.location_table.item(row, 1)
            type_item = self.location_table.item(row, 2)

            if location_item is None or type_item is None:
                return

            if type_item.text() == "Folder":
                self._open_file_location(
                    location_item.text(),
                    folder_only=True,
                )
            elif type_item.text() == "Registry":
                self._open_registry_location(
                    location_item.text()
                )

    def _sync_locations_from_table(self) -> None:
        folders: Dict[str, str] = {}
        registry: Dict[str, str] = {}

        for row in range(self.location_table.rowCount()):
            enabled_item = self.location_table.item(row, 0)
            location_item = self.location_table.item(row, 1)
            type_item = self.location_table.item(row, 2)

            if (
                enabled_item is None
                or location_item is None
                or type_item is None
            ):
                continue

            enabled = (
                "1"
                if enabled_item.checkState() == Qt.CheckState.Checked
                else "0"
            )

            location = location_item.text()
            location_type = type_item.text()

            if location_type == "Folder":
                folders[location] = enabled
            else:
                registry[location] = enabled

        self.folders.clear()
        self.folders.update(folders)

        self.registry_tokens.clear()
        self.registry_tokens.update(registry)

    def open_app_folder(self) -> None:
        os.startfile(self.paths.app)  # type: ignore[attr-defined]

    def set_monitoring_paused(
        self,
        paused: bool,
    ) -> None:
        self.monitoring_button.setText(
            "Resume Monitoring"
            if paused
            else "Pause Monitoring"
        )
        self.monitoring_status_label.setVisible(
            paused
        )

    def _create_path_information_panel(
        self,
    ) -> QLabel:
        information = QLabel()
        information.setWordWrap(True)
        information.setMinimumHeight(48)

        information_is_dark = (
            self.palette()
            .color(QPalette.ColorRole.Window)
            .lightness()
            < 128
        )

        if information_is_dark:
            information.setStyleSheet(
                "QLabel {"
                "background-color: #211E17;"
                "border: 1px solid #fff8d5;"
                "border-radius: 6px;"
                "color: #fff8d5;"
                "font-weight: bold;"
                "padding: 8px;"
                "}"
            )
        else:
            information.setStyleSheet(
                "QLabel {"
                "background-color: #fff8d5;"
                "border: 1px solid #e4d58a;"
                "border-radius: 6px;"
                "color: #766700;"
                "font-weight: bold;"
                "padding: 8px;"
                "}"
            )

        information.setText(
            "Location/Path:"
        )

        return information

    def _create_confirmation_panel(
        self,
        confirm_callback: Callable[[], None],
        cancel_callback: Callable[[], None],
    ) -> tuple[QWidget, QLabel]:
        panel = QWidget()
        confirmation_layout = QHBoxLayout(panel)
        confirmation_layout.setContentsMargins(8, 6, 8, 6)

        confirmation_is_dark = (
            self.palette()
            .color(QPalette.ColorRole.Window)
            .lightness()
            < 128
        )

        panel.setObjectName(
            "removeConfirmationPanel"
        )

        if confirmation_is_dark:
            panel.setStyleSheet(
                "QWidget#removeConfirmationPanel {"
                "background-color: #2D0B0B;"
                "border: 1px solid #f7dada;"
                "border-radius: 6px;"
                "}"
                "QWidget#removeConfirmationPanel QLabel {"
                "border: none;"
                "background: transparent;"
                "font-weight: bold;"
                "color: #f7dada;"
                "}"
            )
        else:
            panel.setStyleSheet(
                "QWidget#removeConfirmationPanel {"
                "background-color: #f7dada;"
                "border: 1px solid #d9a7a7;"
                "border-radius: 6px;"
                "}"
                "QWidget#removeConfirmationPanel QLabel {"
                "border: none;"
                "background: transparent;"
                "font-weight: bold;"
                "color: #8b2424;"
                "}"
            )

        label = QLabel()
        label.setWordWrap(True)
        confirmation_layout.addWidget(label, 1)

        confirm_button = QPushButton("OK")
        confirm_button.clicked.connect(confirm_callback)
        confirmation_layout.addWidget(confirm_button)

        cancel_button = QPushButton("Cancel")
        cancel_button.clicked.connect(cancel_callback)
        confirmation_layout.addWidget(cancel_button)

        panel.setVisible(False)

        return panel, label

    def apply_changes(self) -> None:
        validated_values: Dict[str, int] = {}

        for (
            key,
            _label_text,
            label,
            _default,
            minimum,
            maximum,
            _description_text,
        ) in NUMERIC_OPTIONS:
            edit = self.option_edits[key]
            text = edit.text().strip()

            if (
                not text
                or not edit.hasAcceptableInput()
            ):
                QMessageBox.warning(
                    self,
                    "Invalid Setting",
                    (
                        f"{label} must be a whole number "
                        f"from {minimum} to {maximum}."
                    ),
                )
                edit.setFocus()
                edit.selectAll()
                return

            try:
                value = int(text)
            except ValueError:
                QMessageBox.warning(
                    self,
                    "Invalid Setting",
                    (
                        f"{label} must be a whole number "
                        f"from {minimum} to {maximum}."
                    ),
                )
                edit.setFocus()
                edit.selectAll()
                return

            if not minimum <= value <= maximum:
                QMessageBox.warning(
                    self,
                    "Invalid Setting",
                    (
                        f"{label} must be a whole number "
                        f"from {minimum} to {maximum}."
                    ),
                )
                edit.setFocus()
                edit.selectAll()
                return

            validated_values[key] = value

        monitor = validated_values["MonitorTime"]
        task_monitor = validated_values[
            "MonitorTimeTasks"
        ]
        width = validated_values[
            "ReviewWindowWidth"
        ]
        height = validated_values[
            "ReviewWindowHeight"
        ]

        selected_theme = "System"

        for theme_name, button in (
            self.theme_buttons.items()
        ):
            if button.isChecked():
                selected_theme = theme_name
                break

        updated = {
            "MonitorTime": str(monitor),
            "MonitorTimeTasks": str(task_monitor),
            "ReviewWindowWidth": str(width),
            "ReviewWindowHeight": str(height),
            "ShowReview": "1",
            "Theme": selected_theme,
        }

        for key, check in self.option_checks.items():
            updated[key] = (
                "1"
                if check.isChecked()
                else "0"
            )

        self._sync_locations_from_table()

        self.store.save_settings(updated)
        self.store.save_locations(
            self.folders,
            self.registry_tokens,
        )
        self.store.save_allowed_denied(
            self.allowed,
            self.denied,
        )
        self.engine.log(
            "SETTINGS",
            "gui",
            "apply",
            "settings_applied",
            "SUCCESS",
        )
        self.engine.reload_all(
            create_baselines=False
        )

        application = QApplication.instance()

        if isinstance(application, QApplication):
            apply_theme(
                application,
                selected_theme,
            )

        self.on_saved()
        self.accept()


class ApplicationUI:
    def __init__(
        self,
        engine: MonitorEngine,
        store: ConfigStore,
        paths: Paths,
        on_toggle_monitoring: Callable[[], None],
        is_monitoring_paused: Callable[[], bool],
    ) -> None:
        self.engine = engine
        self.store = store
        self.paths = paths
        self.on_toggle_monitoring = on_toggle_monitoring
        self.is_monitoring_paused = is_monitoring_paused
        self.review_open = False
        self.settings_window: Optional[SettingsWindow] = None
        self.pending_reviews: List[List[ReviewItem]] = []
        self.current_review: Optional[ReviewDialog] = None
        self.recently_handled_keys: set[str] = set()

    def enqueue_review(self, items: object) -> None:
        if not isinstance(items, list) or not items:
            return

        existing_keys = set(self.recently_handled_keys)

        if self.current_review is not None:
            existing_keys.update(item.key for item in self.current_review.items)

        for pending_group in self.pending_reviews:
            existing_keys.update(item.key for item in pending_group)

        new_items = [
            item
            for item in items
            if isinstance(item, ReviewItem) and item.key not in existing_keys
        ]

        if not new_items:
            return

        self.pending_reviews.append(new_items)
        self._show_next_review()

    def _show_next_review(self) -> None:
        if self.review_open or not self.pending_reviews:
            return

        items = self.pending_reviews.pop(0)

        items = [
            item
            for item in items
            if item.key not in self.recently_handled_keys
        ]

        if not items:
            self._show_next_review()
            return

        self.review_open = True
        width = int(self.engine.settings.get("ReviewWindowWidth", "700"))
        height = int(self.engine.settings.get("ReviewWindowHeight", "450"))
        self.current_review = ReviewDialog(items, self._apply_review, self._cancel_review, width, height)
        self.current_review.show()
        self.current_review.raise_()
        self.current_review.activateWindow()

    def _apply_review(self, items: List[ReviewItem]) -> None:
        handled_keys = {item.key for item in items}
        self.recently_handled_keys.update(handled_keys)

        self.pending_reviews = [
            [
                pending_item
                for pending_item in pending_group
                if pending_item.key not in handled_keys
            ]
            for pending_group in self.pending_reviews
        ]
        self.pending_reviews = [
            pending_group
            for pending_group in self.pending_reviews
            if pending_group
        ]

        self.engine.commit_review(items)

        if self.settings_window is not None and self.settings_window.isVisible():
            self.settings_window.refresh_decision_lists()

        self.review_open = False
        self.current_review = None

        for key in handled_keys:
            QTimer.singleShot(
                5000,
                lambda handled_key=key: self.recently_handled_keys.discard(handled_key),
            )

    def _cancel_review(self, items: List[ReviewItem]) -> None:
        handled_keys = {item.key for item in items}
        self.recently_handled_keys.update(handled_keys)

        self.pending_reviews = [
            [
                pending_item
                for pending_item in pending_group
                if pending_item.key not in handled_keys
            ]
            for pending_group in self.pending_reviews
        ]
        self.pending_reviews = [
            pending_group
            for pending_group in self.pending_reviews
            if pending_group
        ]

        self.engine.cancel_review(items)
        self.review_open = False
        self.current_review = None

        for key in handled_keys:
            QTimer.singleShot(
                5000,
                lambda handled_key=key: self.recently_handled_keys.discard(handled_key),
            )

    def show_settings(self) -> None:
        if (
            self.settings_window is not None
            and self.settings_window.isVisible()
        ):
            self.settings_window.set_monitoring_paused(
                self.is_monitoring_paused()
            )
            self.settings_window.raise_()
            self.settings_window.activateWindow()
            return

        self.settings_window = SettingsWindow(
            self.engine,
            self.store,
            self.paths,
            self._settings_saved,
            self.on_toggle_monitoring,
            self.is_monitoring_paused,
        )
        self.settings_window.destroyed.connect(
            self._settings_window_destroyed
        )
        self.settings_window.show()
        self.settings_window.raise_()
        self.settings_window.activateWindow()

    def _settings_window_destroyed(
        self,
        _object=None,
    ) -> None:
        self.settings_window = None

    def set_monitoring_paused(
        self,
        paused: bool,
    ) -> None:
        if (
            self.settings_window is not None
            and self.settings_window.isVisible()
        ):
            self.settings_window.set_monitoring_paused(
                paused
            )

    def _settings_saved(self) -> None:
        return
