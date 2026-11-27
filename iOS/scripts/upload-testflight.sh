#!/bin/bash
set +x
set -euo pipefail

: "${ASC_KEY_ID:?Set ASC_KEY_ID to the App Store Connect team API key ID}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID to the App Store Connect issuer ID}"
: "${ASC_KEY_P8:?Set ASC_KEY_P8 to the full private key contents}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to the Apple Developer Team ID}"

ios_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_number="${BUILD_NUMBER:-$(date +%s)}"
build_dir="${BUILD_OUTPUT_DIR:-$ios_dir/build/$build_number}"
archive="$build_dir/PropertyScore.xcarchive"
bundle_id="${APP_BUNDLE_IDENTIFIER:-com.yujica.propertyscore}"

umask 077
credentials="$(mktemp -d "${TMPDIR:-/tmp}/propertyscore-signing.XXXXXXXX")"
trap 'rm -rf "$credentials"' EXIT
key="$credentials/AuthKey.p8"
printf '%s\n' "$ASC_KEY_P8" > "$key"
unset ASC_KEY_P8

export_options="$credentials/ExportOptions.plist"
/usr/bin/plutil -create xml1 "$export_options"
/usr/bin/plutil -insert method -string app-store-connect "$export_options"
/usr/bin/plutil -insert destination -string upload "$export_options"
/usr/bin/plutil -insert teamID -string "$APPLE_TEAM_ID" "$export_options"
/usr/bin/plutil -insert signingStyle -string automatic "$export_options"
/usr/bin/plutil -insert manageAppVersionAndBuildNumber -bool NO "$export_options"

mkdir -p "$build_dir"
auth=(-allowProvisioningUpdates -authenticationKeyPath "$key" -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

xcodebuild -project "$ios_dir/PropertyScore.xcodeproj" -scheme PropertyScore \
    -configuration Release -destination 'generic/platform=iOS' -archivePath "$archive" \
    "${auth[@]}" "APPLE_TEAM_ID=$APPLE_TEAM_ID" "APP_BUNDLE_IDENTIFIER=$bundle_id" \
    "CURRENT_PROJECT_VERSION=$build_number" archive

xcodebuild -exportArchive -archivePath "$archive" -exportPath "$build_dir/upload" \
    -exportOptionsPlist "$export_options" "${auth[@]}"
