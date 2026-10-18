#!/bin/sh
# Ставит или обновляет =Добро и позитив=:
#   curl -fsSL https://raw.githubusercontent.com/cybertatar/DOBROANDPOZITIV/main/install.sh | sh
set -eu

URL=https://github.com/cybertatar/DOBROANDPOZITIV/releases/download/latest/DOBROANDPOZITIV.zip
APP=/Applications/DOBROANDPOZITIV.app
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Скачиваю…"
curl -fsSL "$URL" -o "$TMP/app.zip"
ditto -x -k "$TMP/app.zip" "$TMP"

# Закрываем старую версию и сбрасываем выданный ей доступ: у новой сборки другая
# подпись, и старая галочка в «Универсальном доступе» перестаёт действовать.
pkill -x DOBROANDPOZITIV 2>/dev/null || true
tccutil reset Accessibility com.cybertatar.dobroandpozitiv >/dev/null 2>&1 || true

echo "Ставлю в «Программы»…"
rm -rf "$APP"
ditto "$TMP/DOBROANDPOZITIV.app" "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

open "$APP"
echo "Готово! Осталось включить DOBROANDPOZITIV в окне «Универсальный доступ», которое сейчас откроется."
