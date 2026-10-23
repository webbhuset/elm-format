#!/bin/sh
# Writes generated/Build_elm_format.hs, the version `--version` prints, the
# same way the Shakefile does: `git describe` over the release tags. For the
# builds that do not go through Shake, such as the release workflow's.
#
# Needs the tags: a shallow checkout describes every build as a bare commit
# (CI must use actions/checkout with fetch-depth: 0).

set -eu

cd "$(dirname "$0")/.."

version=$(git describe --tags --abbrev=8 --match 'v[0-9]*' --match '[0-9]*' --always)
mkdir -p generated
printf 'module Build_elm_format where\n\ngitDescribe :: String\ngitDescribe = "%s"\n' "$version" > generated/Build_elm_format.hs
echo "Stamped $version"
