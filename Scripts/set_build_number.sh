#!/bin/sh
# Stamp CFBundleVersion (the build number) from the git commit count so every
# archive uploaded to App Store Connect gets a unique, monotonically increasing
# build number. Invoked by the "Set Build Number From Git" build phase; relies
# on the CONFIGURATION / ACTION / SRCROOT / TARGET_BUILD_DIR / INFOPLIST_PATH
# variables Xcode exports to build phases.
#
# Behaviour:
#   * Runs only for the Release configuration (the one that gets archived).
#   * Happy path: writes CFBundleVersion = `git rev-list --count HEAD` into the
#     packaged Info.plist, before code signing, so the signature stays valid.
#   * ARCHIVES (ACTION=install) FAIL rather than ship a wrong/stale build number
#     when the commit count can't be trusted: git unavailable, an empty/zero
#     count, or a shallow clone (which reports a misleadingly low count and is
#     the classic way to "accidentally upload build 1" — actions/checkout is
#     shallow by default).
#   * Ordinary, non-archive builds only WARN and leave the value unchanged, so
#     the local dev loop stays friendly.

if [ "${CONFIGURATION}" != "Release" ]; then
    exit 0
fi

is_archive=0
if [ "${ACTION}" = "install" ]; then
    is_archive=1
fi

# Fail the build for archives, warn-and-continue for everything else.
fail_or_warn() {
    if [ "$is_archive" = "1" ]; then
        echo "error: $1"
        exit 1
    fi
    echo "warning: $1 Leaving CFBundleVersion unchanged (non-archive build)."
    exit 0
}

build_number=$(git -C "${SRCROOT}" rev-list --count HEAD 2>/dev/null)
if [ -z "$build_number" ] || [ "$build_number" = "0" ]; then
    fail_or_warn "Could not derive a build number from git (\`git rev-list --count HEAD\` returned nothing). Ensure git is installed and the app is built from a git checkout."
fi

if [ "$(git -C "${SRCROOT}" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
    fail_or_warn "Refusing to trust the git commit count ($build_number) from a shallow clone — it can be far lower than the real count and collide with or undercut an existing App Store build. Use a full clone (e.g. actions/checkout with fetch-depth: 0)."
fi

plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
if [ ! -f "$plist" ]; then
    fail_or_warn "Expected the packaged Info.plist at '$plist' but it was not found; cannot set the build number."
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $build_number" "$plist"
echo "Set CFBundleVersion to $build_number (git commit count)"
