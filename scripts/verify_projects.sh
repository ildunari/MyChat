#!/usr/bin/env bash
set -euo pipefail

# Inventory Xcode projects in this repo and print bundle IDs and display names.
# Safe: read-only. No builds, no simulator interaction.

shopt -s nullglob

echo "== Project inventory =="
found_any=false
for proj in *.xcodeproj; do
  found_any=true
  echo "\n— ${proj}"
  pbx="${proj}/project.pbxproj"
  if [[ ! -f "$pbx" ]]; then
    echo "  ! Missing project.pbxproj (project is incomplete)"
    continue
  fi
  # List targets
  echo "  Targets:"
  awk '/isa = PBXNativeTarget/ {in_target=1} in_target && /name = / {print "   • " $0; in_target=0}' "$pbx" | sed 's/.*name = \([^;]*\);.*/\1/' | sed 's/^/    - /'

  # Bundle IDs and Display Names
  echo "  Settings (Bundle IDs & Display Names):"
  # PRODUCT_BUNDLE_IDENTIFIER lines
  rg -n "PRODUCT_BUNDLE_IDENTIFIER|INFOPLIST_KEY_CFBundleDisplayName|INFOPLIST_FILE" -S "$pbx" | sed 's/^/    /'
done

if [[ "$found_any" == false ]]; then
  echo "No .xcodeproj found in $(pwd)" >&2
  exit 1
fi

cat <<EOF

Tip: If you intend to keep only one app on the simulator, standardize on a single bundle ID for Debug builds (e.g., com.example.mychat.dev) and give Dev builds a distinct display name (e.g., "MyChat Dev").
EOF

