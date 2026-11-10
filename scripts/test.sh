#!/bin/bash
# Runs the same tests locally and in CI.
#   scripts/test.sh            pitch package + app unit tests
#   scripts/test.sh package    pitch package only (no Simulator needed)
#   scripts/test.sh unit       app unit tests
#   scripts/test.sh ui         real-clock UI tests (slow; run before a release)
#   scripts/test.sh all        everything
# Set CELLO_SIMULATOR_ID to choose a Simulator; otherwise the first available iPhone is used.
set -euo pipefail

cello_project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cello_suites=("$@")
if [[ ${#cello_suites[@]} -eq 0 ]]; then cello_suites=(package unit); fi
if [[ "${cello_suites[0]}" == "all" ]]; then cello_suites=(package unit ui); fi

cello_simulator_id() {
  if [[ -n "${CELLO_SIMULATOR_ID:-}" ]]; then
    echo "$CELLO_SIMULATOR_ID"
    return
  fi
  local id
  id="$(xcrun simctl list devices available | grep -E '^ +iPhone' | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -n 1 || true)"
  if [[ -z "$id" ]]; then
    echo "No available iPhone Simulator found. Install one in Xcode or set CELLO_SIMULATOR_ID." >&2
    exit 1
  fi
  echo "$id"
}

cello_xcode_test() {
  local simulator
  simulator="$(cello_simulator_id)"
  xcodebuild -project "$cello_project_root/CelloPractice.xcodeproj" -scheme Cello \
    -destination "platform=iOS Simulator,id=$simulator" \
    -derivedDataPath "$cello_project_root/build" CODE_SIGNING_ALLOWED=NO \
    -parallel-testing-enabled NO -collect-test-diagnostics never \
    "-only-testing:$1" test
}

for cello_suite in "${cello_suites[@]}"; do
  case "$cello_suite" in
    package) swift test --package-path "$cello_project_root/Packages/CelloPitch" -c release ;;
    unit) cello_xcode_test CelloTests ;;
    ui) cello_xcode_test CelloUITests ;;
    *) echo "Unknown suite '$cello_suite'. Use package, unit, ui or all." >&2; exit 2 ;;
  esac
done
