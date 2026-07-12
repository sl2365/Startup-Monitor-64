from __future__ import annotations

import sys
from pathlib import Path

SOURCE_DIR = Path(__file__).resolve().parent

if str(SOURCE_DIR) not in sys.path:
    sys.path.insert(
        0,
        str(SOURCE_DIR),
    )

from app_info import (
    APP_COMPANY,
    APP_COPYRIGHT,
    APP_DESCRIPTION,
    APP_NAME,
    APP_VERSION,
)


def version_tuple(version_text: str) -> tuple[int, int, int, int]:
    parts = version_text.strip().split(".")

    if not 1 <= len(parts) <= 4:
        raise ValueError(
            "APP_VERSION must contain between one and four numeric parts."
        )

    numbers = []

    for part in parts:
        if not part.isdigit():
            raise ValueError(
                "APP_VERSION must contain only numbers separated by dots."
            )

        number = int(part)

        if not 0 <= number <= 65535:
            raise ValueError(
                "Each APP_VERSION component must be from 0 to 65535."
            )

        numbers.append(number)

    while len(numbers) < 4:
        numbers.append(0)

    return (
        numbers[0],
        numbers[1],
        numbers[2],
        numbers[3],
    )


def escape_resource_text(value: str) -> str:
    return value.replace(
        "\\",
        "\\\\",
    ).replace(
        "'",
        "\\'",
    )


def create_version_resource(
    output_path: Path,
    executable_name: str,
) -> None:
    version = version_tuple(APP_VERSION)
    version_tuple_text = ", ".join(
        str(part)
        for part in version
    )

    internal_name = Path(executable_name).stem

    resource_text = f"""VSVersionInfo(
    ffi=FixedFileInfo(
        filevers=({version_tuple_text}),
        prodvers=({version_tuple_text}),
        mask=0x3F,
        flags=0x0,
        OS=0x40004,
        fileType=0x1,
        subtype=0x0,
        date=(0, 0),
    ),
    kids=[
        StringFileInfo(
            [
                StringTable(
                    u'080904B0',
                    [
                        StringStruct(
                            u'CompanyName',
                            u'{escape_resource_text(APP_COMPANY)}',
                        ),
                        StringStruct(
                            u'FileDescription',
                            u'{escape_resource_text(APP_DESCRIPTION)}',
                        ),
                        StringStruct(
                            u'FileVersion',
                            u'{escape_resource_text(APP_VERSION)}',
                        ),
                        StringStruct(
                            u'InternalName',
                            u'{escape_resource_text(internal_name)}',
                        ),
                        StringStruct(
                            u'LegalCopyright',
                            u'{escape_resource_text(APP_COPYRIGHT)}',
                        ),
                        StringStruct(
                            u'OriginalFilename',
                            u'{escape_resource_text(executable_name)}',
                        ),
                        StringStruct(
                            u'ProductName',
                            u'{escape_resource_text(APP_NAME)}',
                        ),
                        StringStruct(
                            u'ProductVersion',
                            u'{escape_resource_text(APP_VERSION)}',
                        ),
                    ],
                ),
            ],
        ),
        VarFileInfo(
            [
                VarStruct(
                    u'Translation',
                    [2057, 1200],
                ),
            ],
        ),
    ],
)
"""

    output_path.write_text(
        resource_text,
        encoding="utf-8",
        newline="\n",
    )


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: make_version_info.py "
            "<output-file> <executable-name>"
        )
        return 1

    output_path = Path(sys.argv[1])
    executable_name = sys.argv[2]

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    try:
        create_version_resource(
            output_path,
            executable_name,
        )
    except (OSError, ValueError) as error:
        print(
            f"ERROR: Version resource generation failed: {error}"
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())