#!/bin/sh
# Собирает DOBROANDPOZITIV.app (arm64 + x86_64) в build/. Нужен только Xcode Command Line Tools.
set -eu
cd "$(dirname "$0")"

APP=build/DOBROANDPOZITIV.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" Sources/*.swift -o "build/DOBROANDPOZITIV-$arch"
done
lipo -create build/DOBROANDPOZITIV-arm64 build/DOBROANDPOZITIV-x86_64 -output "$APP/Contents/MacOS/DOBROANDPOZITIV"
cp Info.plist "$APP/Contents/Info.plist"

mkdir -p "$APP/Contents/Resources" build/AppIcon.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon.png --out "build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

# Подпись без сертификата: macOS запомнит выданный доступ за этой подписью.
codesign --force --sign - --identifier com.cybertatar.dobroandpozitiv "$APP"

ditto -c -k --keepParent "$APP" build/DOBROANDPOZITIV.zip

# Образ диска: окно с фоном, где приложение перетаскивают в «Программы».
python3 -m venv build/venv
build/venv/bin/pip install -q "dmgbuild>=1.6,<2"
tiffutil -cathidpicheck Resources/dmg-background.png Resources/dmg-background@2x.png -out build/dmg-background.tiff
build/venv/bin/dmgbuild -s dmg.py "Добро и позитив" build/DOBROANDPOZITIV.dmg
echo "Готово: $APP, build/DOBROANDPOZITIV.dmg"
