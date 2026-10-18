#!/usr/bin/env bash
set -euo pipefail

APP_NAME="deskloop"
INSTALL_DIR="/usr/local/bin"

echo "==> Building ${APP_NAME} from source..."
swift build -c release

echo "==> Installing binary to ${INSTALL_DIR}/${APP_NAME}..."
if [ -w "${INSTALL_DIR}" ]; then
  cp .build/release/${APP_NAME} "${INSTALL_DIR}/${APP_NAME}"
else
  sudo cp .build/release/${APP_NAME} "${INSTALL_DIR}/${APP_NAME}"
fi

echo "==> Successfully installed ${APP_NAME}!"
echo "Run '${APP_NAME} --help' to get started."
