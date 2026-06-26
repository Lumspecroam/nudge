#!/bin/bash
#
# build-dmg.sh — Build a drag-to-install DMG for Nudge
#
# Produces Nudge-<version>.dmg with:
#   - Nudge.app (signed)
#   - /Applications shortcut (drag target)
#   - README.txt with install + uninstall instructions
#   - Custom background showing drag arrow
#
# Usage: ./build-dmg.sh [version]
#
set -euo pipefail

VERSION="${1:-1.0.3}"
APP_NAME="Nudge"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
RELEASE_BUILD="${PROJECT_ROOT}/build/Build/Products/Release"
APP_SOURCE="${RELEASE_BUILD}/${APP_BUNDLE}"

# Local self-signed certificate (present in keychain)
SIGN_IDENTITY="9DD9C402C2323D932F4A042D0ACA2B2EAA662443"

STAGING_DIR="$(mktemp -d -t nudge-dmg)"
DMG_STAGING="$(mktemp -d -t nudge-dmg-staging)"
DMG_RAW="${DMG_STAGING}/raw.dmg"
DMG_FINAL="${PROJECT_ROOT}/${DMG_NAME}"

# Remove existing final DMG to avoid hdiutil convert failure
rm -f "${DMG_FINAL}"

trap 'rm -rf "${STAGING_DIR}" "${DMG_STAGING}"' EXIT

# ---------- Pre-flight checks ----------
if [[ ! -d "${APP_SOURCE}" ]]; then
    echo "❌ Release build not found at: ${APP_SOURCE}"
    echo "   Run: xcodebuild -project Nudge.xcodeproj -scheme Nudge -configuration Release -derivedDataPath build build"
    exit 1
fi

echo "📦 Building ${DMG_NAME} ..."
echo "   App source: ${APP_SOURCE}"

# ---------- 1. Sign the app (ad-hoc / self-signed) ----------
echo "🔐 Signing ${APP_BUNDLE} ..."
codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_SOURCE}" 2>/dev/null \
    || codesign --force --deep --sign - "${APP_SOURCE}"
echo "   Signature: $(codesign -dvv "${APP_SOURCE}" 2>&1 | grep -E 'Signature|Identifier' | head -2 | tr '\n' ' ')"

# ---------- 2. Verify signature ----------
if ! codesign --verify --strict "${APP_SOURCE}" 2>/dev/null; then
    echo "⚠️  Signature verification failed (will still build DMG, but app may show Gatekeeper warning)"
fi

# ---------- 3. Prepare staging ----------
echo "🗂  Preparing DMG staging ..."
cp -R "${APP_SOURCE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# ---------- 4. Write README with install + uninstall instructions ----------
cat > "${STAGING_DIR}/README.txt" <<'EOF'
                          Nudge for macOS
                       Window Snapping, Refined

────────────────────────────────────────────────────────────────
INSTALLATION
────────────────────────────────────────────────────────────────

1. Drag the Nudge.app icon onto the Applications folder icon
   on the right side of this window.

2. Open Finder → Applications → Nudge (or use Spotlight).

3. On first launch, macOS will prompt you to grant Accessibility
   permission. Click "Open System Settings" → enable "Nudge"
   under Privacy & Security → Accessibility.

   Nudge needs this permission to move and resize windows.

────────────────────────────────────────────────────────────────
UNINSTALLATION
────────────────────────────────────────────────────────────────

1. Quit Nudge from the menu bar icon → Quit (or ⌘Q).

2. Drag /Applications/Nudge.app to Trash.

3. To remove all preferences and cache, run in Terminal:

      rm -rf ~/Library/Preferences/app.nudge.Nudge.plist
      rm -rf ~/Library/Containers/app.nudge.Nudge
      rm -f  ~/nudge-debug.log ~/nudge-debug.log.old

4. To clear Accessibility permission, run System Settings →
   Privacy & Security → Accessibility, and remove "Nudge"
   from the list.

────────────────────────────────────────────────────────────────
SYSTEM REQUIREMENTS
────────────────────────────────────────────────────────────────

  • macOS 11.0 (Big Sur) or later
  • Apple Silicon (arm64) or Intel (x86_64)
  • Accessibility permission (granted on first launch)

────────────────────────────────────────────────────────────────
SUPPORT
────────────────────────────────────────────────────────────────

  Source:  https://github.com/Lumspecroam/nudge
  Version: 1.0.3

────────────────────────────────────────────────────────────────
EOF

# ---------- 5. Create the DMG ----------
echo "💿 Creating DMG ..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDBZ \
    "${DMG_RAW}" 2>&1 | tail -3

# ---------- 6. Convert to read-only compressed final DMG ----------
hdiutil convert \
    "${DMG_RAW}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}" 2>&1 | tail -3

# ---------- 7. Sign the DMG itself ----------
echo "🔏 Signing DMG ..."
codesign --sign "${SIGN_IDENTITY}" "${DMG_FINAL}" 2>/dev/null \
    || codesign --sign - "${DMG_FINAL}" \
    || echo "   (DMG signing skipped — not critical for local distribution)"

# ---------- 8. Verify ----------
echo ""
echo "────────────────────────────────────────────"
echo "✅ DMG Build Complete"
echo "────────────────────────────────────────────"
echo "File:        ${DMG_FINAL}"
echo "Size:        $(du -h "${DMG_FINAL}" | cut -f1)"
echo "Checksum:    $(shasum -a 256 "${DMG_FINAL}" | awk '{print $1}')"
echo ""
echo "DMG contents:"
hdiutil attach "${DMG_FINAL}" -nobrowse -mountpoint /tmp/nudge-verify 2>/dev/null
ls -la /tmp/nudge-verify/
hdiutil detach /tmp/nudge-verify 2>/dev/null
echo ""
echo "App signature:"
codesign -dvv "${APP_SOURCE}" 2>&1 | grep -E 'Signature|Identifier|Format' | head -3
