#!/bin/bash

set -e

# Regenerate the mobileprovision from base64
cd "$RUNNER_TEMP" || exit 1
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
echo -n "$MOBILEPROVISION" | base64 --decode --output CI.mobileprovision
cp CI.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles

# If second mobileprovision var is set, then decode and store
if [[ -n "$MOBILEPROVISION2" ]]; then
    echo -n "$MOBILEPROVISION2" | base64 --decode --output CI2.mobileprovision
    cp CI2.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles
fi

cp CI2.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles

# Regenerate the p12 from base64 and install in new temp keychain
KEYCHAIN_PATH=$RUNNER_TEMP/temp_resign
KEYCHAIN_PASS=$(echo "$(date)""$RANDOM" | base64)
echo -n "$CERT_P12" | base64 --decode --output cicert.p12
security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
security import cicert.p12 -P "$P12_PASS" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security list-keychain -d user -s "$KEYCHAIN_PATH"

# If second mobileprovisioning file detected, then resign with both
if [[ -n "$MOBILEPROVISION2" ]]; then
    fastlane sigh resign "$IPA_PATH" --keychain_path "$KEYCHAIN_PATH" --signing_identity "$SIGNING_IDENTITY" --provisioning_profile "CI.mobileprovision" -p "CI2.mobileprovision"
else
    astlane sigh resign "$IPA_PATH" --keychain_path "$KEYCHAIN_PATH" --signing_identity "$SIGNING_IDENTITY" --provisioning_profile "CI.mobileprovision"
fi

# Clean up
if [[ -n "$MOBILEPROVISION2"]]; then
rm ~/Library/MobileDevice/Provisioning\ Profiles/CI2.mobileprovision
rm ~/Library/MobileDevice/Provisioning\ Profiles/CI.mobileprovision
else 
rm ~/Library/MobileDevice/Provisioning\ Profiles/CI.mobileprovision
fi
