#!/bin/bash
set -euo pipefail

cello_device_id="${1:?Usage: scripts/run-on-iphone.sh DEVICE_ID (find it with xcrun devicectl list devices)}"
cello_project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cello_build_arguments=(
  -project "$cello_project_root/CelloPractice.xcodeproj"
  -scheme Cello -configuration Release
  -destination 'generic/platform=iOS'
  -derivedDataPath "$cello_project_root/build-device"
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration
)
if [[ -n "${CELLO_DEVELOPMENT_TEAM:-}" ]]; then
  cello_build_arguments+=("DEVELOPMENT_TEAM=$CELLO_DEVELOPMENT_TEAM")
fi
xcodebuild "${cello_build_arguments[@]}" build

xcrun devicectl device install app --device "$cello_device_id" \
  "$cello_project_root/build-device/Build/Products/Release-iphoneos/Cello.app"
xcrun devicectl device process launch --device "$cello_device_id" com.ronildo.cellopractice
