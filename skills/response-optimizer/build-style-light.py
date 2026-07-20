#!/usr/bin/env python3
"""Собирает style-light.md из _shared/communication-style.md.

Источник правды — communication-style.md. Куски, которые должны попасть
в лёгкую версию, помечены там маркерами:

    <!-- light:ИмяСекции -->
    ...содержимое...
    <!-- /light -->

Скрипт вытаскивает помеченные блоки, группирует по имени секции и пишет
style-light.md, который хук UserPromptSubmit подаёт на каждый ввод.
Правки вносить в communication-style.md, не в style-light.md — он перезаписывается.

Запуск: python3 build-style-light.py [--check]
  --check — не писать файл, только сказать, актуален ли он (код 1, если устарел)
"""

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / "_shared" / "communication-style.md"
DST = HERE / "style-light.md"

# Порядок секций в выжимке; секции не из списка идут в конец в порядке появления
ORDER = ["Zero-slop", "Язык", "Approve", "Артефакты для людей"]

HEADER = """# Стиль коммуникации — лёгкая версия

Собрано скриптом `build-style-light.py` из `_shared/communication-style.md` —
правки вносить туда, этот файл перезаписывается. Применяй молча.
"""

BLOCK = re.compile(
    r"<!--\s*light:(?P<name>[^>]+?)\s*-->\n(?P<body>.*?)\n<!--\s*/light\s*-->",
    re.DOTALL,
)


def collect(text):
    sections = {}
    for m in BLOCK.finditer(text):
        name = m.group("name").strip()
        sections.setdefault(name, []).append(m.group("body").strip())
    return sections


def render(sections):
    names = [n for n in ORDER if n in sections]
    names += [n for n in sections if n not in ORDER]
    parts = [HEADER]
    for name in names:
        parts.append(f"## {name}\n\n" + "\n\n".join(sections[name]) + "\n")
    return "\n".join(parts)


def main():
    if not SRC.exists():
        sys.exit(f"нет источника: {SRC}")

    sections = collect(SRC.read_text(encoding="utf-8"))
    if not sections:
        sys.exit(f"в {SRC.name} не найдено ни одного блока <!-- light:... -->")

    out = render(sections)
    current = DST.read_text(encoding="utf-8") if DST.exists() else None

    if "--check" in sys.argv:
        if current == out:
            print(f"актуален: {DST.name}")
            return
        sys.exit(f"устарел: {DST.name} — пересобрать build-style-light.py")

    if current == out:
        return  # молча: хук вызывает скрипт на каждом старте сессии

    DST.write_text(out, encoding="utf-8")
    print(f"пересобран {DST.name}: {len(sections)} секций, {len(out)} байт", file=sys.stderr)


if __name__ == "__main__":
    main()
