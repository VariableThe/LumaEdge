#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
configuration="${1:-release}"

cd "$project_dir"
swift build -c "$configuration"

binary_path="$(swift build -c "$configuration" --show-bin-path)/LumaEdgeApp"
app_path="$project_dir/build/LumaEdge.app"

if [[ ! -x "$binary_path" ]]; then
    print -u2 "LumaEdgeApp was not produced at $binary_path"
    exit 1
fi

mkdir -p "$app_path/Contents/MacOS"
cp "$binary_path" "$app_path/Contents/MacOS/LumaEdgeApp"
codesign --force --sign - --timestamp=none "$app_path"

print "Built $app_path"
