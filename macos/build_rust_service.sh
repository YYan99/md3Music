#!/bin/bash
set -euo pipefail

# Xcode 会在此阶段结束后给外层应用签名。
export PATH="$HOME/.cargo/bin:$PATH"
export CARGO_TARGET_DIR="$PROJECT_TEMP_DIR/rust"
cd "$PROJECT_DIR/../kugou_api_server/rust"
libraries=()
for arch in $ARCHS; do
  case "$arch" in
    arm64) target=aarch64-apple-darwin ;;
    x86_64) target=x86_64-apple-darwin ;;
    *) echo "不支持的架构：$arch" >&2; exit 1 ;;
  esac
  cargo build --locked --release --target "$target"
  libraries+=("$CARGO_TARGET_DIR/$target/release/libkugou_server.dylib")
done

frameworks="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
library="$frameworks/libkugou_server.dylib"
mkdir -p "$frameworks"
lipo -create "${libraries[@]}" -output "$library"
install_name_tool -id @rpath/libkugou_server.dylib "$library"
codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$library"
