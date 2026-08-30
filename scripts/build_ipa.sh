#!/bin/bash
set -euo pipefail

rm -rf build/
mkdir -p build

echo "Build Started!"
echo

PROJECT_FILE=$(ls -d *.xcodeproj | head -n 1)
PROJECT_NAME=$(basename "$PROJECT_FILE" .xcodeproj)

echo "Found Project: $PROJECT_NAME"

TARGET_NAME=$(xcodebuild -list -project "$PROJECT_FILE" | grep -A 10 "Targets:" | tail -n +2 | xargs | cut -d ' ' -f 1)
SCHEME_NAME="$TARGET_NAME"

echo "Auto-generating scheme for Target: $SCHEME_NAME..."
xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME_NAME" -manageAutomaticSchemes >/dev/null 2>&1 || true

# 🟢 กำหนด Toolchain และ Flags สำหรับ Hikari Obfuscation
# (ถ้าหา Hikari Toolchain ไม่เจอในเครื่อง ให้สลับไปใช้ default toolchain เพื่อไม่ให้ build ล่ม)
HIKARI_TOOLCHAIN_PATH="$HOME/Library/Developer/Toolchains/Hikari.xctoolchain"
TOOLCHAIN_ARG=""
OBFUSCATION_FLAGS=""

if [ -d "$HIKARI_TOOLCHAIN_PATH" ]; then
  echo "🟢 Hikari Toolchain Detected! Enabling Obfuscation Flags..."
  TOOLCHAIN_ARG="TOOLCHAINS=com.hikari.llvm"
  OBFUSCATION_FLAGS="OTHER_CFLAGS=-mllvm -enable-strcry -mllvm -enable-cffobf -mllvm -enable-indbr -mllvm -enable-acdoc OTHER_CPLUSPLUSFLAGS=-mllvm -enable-strcry -mllvm -enable-cffobf -mllvm -enable-indbr -mllvm -enable-acdoc"
else
  echo "⚠️ Hikari Toolchain not found, using default Apple Clang..."
fi

# 1. สั่ง Archive (ใส่ TOOLCHAINS และ Obfuscation Flags เข้าไป)
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME_NAME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/$PROJECT_NAME.xcarchive" \
  $TOOLCHAIN_ARG \
  $OBFUSCATION_FLAGS \
  archive \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  AD_HOC_CODE_SIGNING_ALLOWED=YES

# 2. ดึงไฟล์ .app อัตโนมัติ (ไม่ว่า Target จะชื่อ 3105 หรือชื่ออื่น)
APP_PATH=$(find "$PWD/build/$PROJECT_NAME.xcarchive/Products/Applications" -maxdepth 1 -name "*.app" | head -n 1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "Error: Missing .app inside xcarchive"
  exit 1
fi

echo "Found App Bundle at: $APP_PATH"

# 3. จัดโฟลเดอร์ Payload
rm -rf "$PWD/build/Payload"
mkdir -p "$PWD/build/Payload"
cp -R "$APP_PATH" "$PWD/build/Payload/"

# 4. ทำ Pseudo-sign ด้วย ldid
APP_BINARY_NAME=$(basename "$APP_PATH" .app)
if command -v ldid >/dev/null 2>&1; then
  echo "Signing with ldid..."
  ldid -S "$PWD/build/Payload/$APP_BINARY_NAME.app/$APP_BINARY_NAME"
else
  echo "Warning: ldid not installed, skipping pseudo-signing."
fi

# 5. บีบอัดเป็น .ipa
(cd "$PWD/build" && /usr/bin/zip -qry "$PROJECT_NAME.ipa" Payload)

echo
echo "Build Successful!"
echo "IPA created at: build/$PROJECT_NAME.ipa"
exit 0
