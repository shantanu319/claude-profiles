#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repository_dir="${script_dir:h}"
output_dir="$repository_dir/build"
output_app="$output_dir/Claude Profiles.app"
stage_dir="$(mktemp -d "${TMPDIR%/}/claude-profiles-build.XXXXXX")"
stage_app="$stage_dir/Claude Profiles.app"

cleanup() {
    /bin/rm -rf "$stage_dir"
}
trap cleanup EXIT

/usr/bin/swift build --package-path "$repository_dir" -c release --product ClaudeProfiles
binary_dir="$(/usr/bin/swift build --package-path "$repository_dir" -c release --show-bin-path)"

contents="$stage_app/Contents"
/bin/mkdir -p "$contents/MacOS" "$contents/Resources"
/usr/bin/ditto "$binary_dir/ClaudeProfiles" "$contents/MacOS/ClaudeProfiles"
/bin/chmod 755 "$contents/MacOS/ClaudeProfiles"
/usr/bin/ditto "$repository_dir/Resources/Info.plist" "$contents/Info.plist"

master_icon="$stage_dir/ClaudeProfiles.png"
iconset="$stage_dir/ClaudeProfiles.iconset"
/bin/mkdir -p "$iconset"
/usr/bin/swift "$repository_dir/Scripts/make-icon.swift" "$master_icon"

resize_icon() {
    /usr/bin/sips -z "$1" "$1" "$master_icon" --out "$iconset/$2" >/dev/null
}
resize_icon 16 icon_16x16.png
resize_icon 32 icon_16x16@2x.png
resize_icon 32 icon_32x32.png
resize_icon 64 icon_32x32@2x.png
resize_icon 128 icon_128x128.png
resize_icon 256 icon_128x128@2x.png
resize_icon 256 icon_256x256.png
resize_icon 512 icon_256x256@2x.png
resize_icon 512 icon_512x512.png
resize_icon 1024 icon_512x512@2x.png
/usr/bin/iconutil -c icns "$iconset" -o "$contents/Resources/ClaudeProfiles.icns"

/usr/bin/plutil -lint "$contents/Info.plist"
/usr/bin/codesign --force --deep --sign - "$stage_app"
/bin/mkdir -p "$output_dir"
if [[ -e "$output_app" ]]; then
    /bin/rm -rf "$output_app"
fi
/bin/mv "$stage_app" "$output_app"
print -r -- "$output_app"
