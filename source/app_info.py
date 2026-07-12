from __future__ import annotations

try:
    from build_info import BUILD_DATE
except ImportError:
    BUILD_DATE = "Development"

APP_NAME = "Startup Monitor 64"
APP_VERSION = "0.0.4.153"
APP_AUTHOR = "sl23"
APP_COMPANY = "sl23"
APP_DESCRIPTION = (
    "Monitors Windows startup locations for new or modified entries."
)
APP_COPYRIGHT = "Copyright (c) 2026 sl23"
APP_GITHUB_URL = "https://github.com/sl2365/Startup-Monitor-64"
APP_LICENSE = "MIT"