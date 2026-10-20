"""Keep the addon's translation files in step with Locale/enUS.lua.

    python Tools/sync-locales.py          rewrite every locale file from enUS.lua, keeping translations
    python Tools/sync-locales.py --check  change nothing; fail if a file is out of step or a translation is broken

English is the source. Each other locale file lists every English key in the same groups and order;
an untranslated key is a commented line holding the English text, so the game falls back to English.
"""

import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALE_DIR = os.path.join(ROOT, "Locale")
SOURCE = os.path.join(LOCALE_DIR, "enUS.lua")
LOCALES = ["deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]

# Either quote style: enUS.lua single-quotes text that contains double quotes.
STRING = r'''(?:"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')'''
ENTRY = re.compile(r"^L\[(" + STRING + r")\]\s*=\s*(" + STRING + r")", re.M)
SOURCE_ENTRY = re.compile(r"^L\[(" + STRING + r")\]\s*=\s*\n?\s*(" + STRING + r")", re.M)
# Lua format specifiers, as string.format reads them; "%%" is a literal percent sign.
PLACEHOLDER = re.compile(r"%(?:%|[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqsaA])")
# The line in enUS.lua that publishes the table, such as "LB.L = L"; the entries follow it.
PUBLISH = re.compile(r"^\w+\.L = L$", re.M)

HEADER = 'if GetLocale() ~= "{code}" then\n\treturn\nend\n\nlocal L = select(2, ...).L\n'


def read(path):
    with open(path, "rb") as handle:
        return handle.read().decode("utf-8-sig").replace("\r\n", "\n")


def write(path, text):
    with open(path, "wb") as handle:
        handle.write(text.replace("\n", "\r\n").encode("utf-8"))


def source_layout():
    """The English file after its setup code, as ("comment" | "blank" | "entry", data) items."""
    text = read(SOURCE)
    publish = PUBLISH.search(text)

    if not publish:
        raise SystemExit("enUS.lua: no line publishing the table, such as ADDON.L = L")

    body = text[publish.end():]
    items, position = [], 0

    while position < len(body):
        match = SOURCE_ENTRY.match(body, position)

        if match:
            items.append(("entry", (match.group(1), match.group(2))))
            position = match.end()
            newline = body.find("\n", position)
            position = len(body) if newline < 0 else newline + 1
            continue

        newline = body.find("\n", position)
        line = body[position:] if newline < 0 else body[position:newline]
        position = len(body) if newline < 0 else newline + 1
        stripped = line.strip()

        if stripped.startswith("--"):
            items.append(("comment", stripped))
        elif stripped == "":
            items.append(("blank", None))
        else:
            raise SystemExit("enUS.lua: cannot read line: " + line)

    while items and items[0][0] == "blank":
        items.pop(0)

    while items and items[-1][0] == "blank":
        items.pop()

    return items


def translations(path):
    """Uncommented L["key"] = "value" lines already in a locale file, and any key given twice."""
    found, duplicates = {}, []

    if not os.path.exists(path):
        return found, duplicates

    for match in ENTRY.finditer(read(path)):
        key, value = match.group(1), match.group(2)

        if key in found:
            duplicates.append(key)

        found[key] = value

    return found, duplicates


def render(code, items, done):
    lines = HEADER.format(code=code).split("\n")

    for kind, data in items:
        if kind == "comment":
            lines.append(data)
        elif kind == "blank":
            lines.append("")
        else:
            key, english = data

            if key in done:
                lines.append("L[{}] = {}".format(key, done[key]))
            else:
                lines.append("-- L[{}] = {}".format(key, english))

    return "\n".join(lines).rstrip("\n") + "\n"


def problems(code, items, done, duplicates):
    english = {data[0]: data[1] for kind, data in items if kind == "entry"}
    found = []

    for key in duplicates:
        found.append("{}: {} is translated twice".format(code, key))

    for key, value in done.items():
        if key not in english:
            found.append("{}: {} is not an English key (removed or misspelt)".format(code, key))
            continue

        wanted = PLACEHOLDER.findall(english[key])
        given = PLACEHOLDER.findall(value)

        if wanted != given:
            found.append("{}: {} must keep the placeholders {} in that order, found {}".format(
                code, key, " ".join(wanted) or "(none)", " ".join(given) or "(none)"))

        if value.count("|c") != english[key].count("|c") or value.count("|r") != english[key].count("|r"):
            found.append("{}: {} must keep its colour codes (|c...|r)".format(code, key))

    return found


def luac():
    explicit = os.environ.get("LUAC")

    if explicit:
        return explicit

    for name in ("luac5.1", "luac"):
        path = shutil.which(name)

        if path:
            return path

    fallback = r"C:\Program Files (x86)\Lua\5.1\luac.exe"

    return fallback if os.path.exists(fallback) else None


def main():
    check = "--check" in sys.argv[1:]
    items = source_layout()
    failures = []

    for code in LOCALES:
        path = os.path.join(LOCALE_DIR, code + ".lua")
        done, duplicates = translations(path)
        failures += problems(code, items, done, duplicates)

        english = {data[0] for kind, data in items if kind == "entry"}
        wanted = render(code, items, {key: value for key, value in done.items() if key in english})
        current = read(path) if os.path.exists(path) else None

        if current == wanted:
            continue

        if check:
            failures.append("{}: out of step with enUS.lua; run python Tools/sync-locales.py".format(code))
        else:
            write(path, wanted)
            print("updated " + code)

    compiler = luac()

    if compiler:
        for code in ["enUS"] + LOCALES:
            path = os.path.join(LOCALE_DIR, code + ".lua")
            result = subprocess.run([compiler, "-p", path], capture_output=True, text=True)

            if result.returncode != 0:
                failures.append("{}: does not parse: {}".format(code, (result.stderr or result.stdout).strip()))
    else:
        print("note: no luac found, so the files were not parse-checked (set LUAC to its path)")

    for failure in failures:
        print(failure)

    if failures:
        sys.exit(1)

    print("locales: {} languages in step with enUS.lua".format(len(LOCALES)))


if __name__ == "__main__":
    main()
