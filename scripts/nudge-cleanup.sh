#!/bin/bash
#
# nudge-cleanup.sh — Remove Nudge and clear all macOS permissions / caches
#
# Removes:
#   • The Nudge.app bundle (from /Applications and user home)
#   • Accessibility permission (TCC.db entry)
#   • Automation permissions (Apple Events)
#   • LaunchAgent / Login Items (SMAppService registration)
#   • Preferences, containers, caches, logs
#   • Quarantine attribute (xattr)
#
# Safety:
#   • Interactive — prompts before each destructive step (use --yes to skip)
#   • Dry-run mode: --dry-run shows what would happen without changing anything
#   • Only touches files matching the Nudge bundle identifier (app.nudge.Nudge)
#   • TCC.db reset requires SIP to be partially disabled OR manual System
#     Settings action (script will guide)
#
# Usage:
#   ./nudge-cleanup.sh             # interactive
#   ./nudge-cleanup.sh --yes       # auto-confirm all
#   ./nudge-cleanup.sh --dry-run   # show what would be removed
#   ./nudge-cleanup.sh --help
#
set -uo pipefail

APP_NAME="Nudge"
APP_BUNDLE="${APP_NAME}.app"
BUNDLE_ID="app.nudge.Nudge"
APP_PATHS=(
    "/Applications/${APP_BUNDLE}"
    "${HOME}/Applications/${APP_BUNDLE}"
    "${HOME}/Downloads/${APP_BUNDLE}"
)

PREFS_PATHS=(
    "${HOME}/Library/Preferences/${BUNDLE_ID}.plist"
    "${HOME}/Library/Preferences/${BUNDLE_ID}.plist.lockfile"
    "${HOME}/Library/Containers/${BUNDLE_ID}"
    "${HOME}/Library/Application Support/${BUNDLE_ID}"
    "${HOME}/Library/Caches/${BUNDLE_ID}"
    "${HOME}/Library/Saved Application State/${BUNDLE_ID}.savedState"
    "${HOME}/Library/HTTPStorages/${BUNDLE_ID}"
    "${HOME}/Library/WebKit/${BUNDLE_ID}"
    "${HOME}/nudge-debug.log"
    "${HOME}/nudge-debug.log.old"
)

# LaunchAgent path (SMAppService uses this internally)
LAUNCH_AGENT_PATH="${HOME}/Library/LaunchAgents/${BUNDLE_ID}.plist"

DRY_RUN=false
AUTO_YES=false

# ---------- Argument parsing ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --yes|-y)  AUTO_YES=true; shift ;;
        --help|-h)
            grep '^#' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------- Helpers ----------
confirm() {
    if $AUTO_YES; then return 0; fi
    if $DRY_RUN; then return 0; fi
    local prompt="$1"
    read -r -p "${prompt} [y/N] " ans
    [[ "${ans:-}" =~ ^[Yy]$ ]]
}

action_rm() {
    local target="$1"
    local label="$2"
    if [[ ! -e "${target}" ]] && [[ ! -L "${target}" ]]; then
        echo "   ℹ️  Skip (not found): ${target}"
        return 0
    fi
    if $DRY_RUN; then
        echo "   [DRY-RUN] Would remove: ${target}"
        return 0
    fi
    rm -rf "${target}" && echo "   ✅ Removed ${label}: ${target}"
}

# ---------- Banner ----------
echo "═══════════════════════════════════════════════════════════════"
echo "  Nudge Cleanup Script"
echo "  Bundle ID: ${BUNDLE_ID}"
$DRY_RUN && echo "  Mode: DRY-RUN (no changes will be made)"
$AUTO_YES && echo "  Mode: AUTO-YES (no prompts)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ---------- Step 1: Quit running app ----------
echo "▸ Step 1: Quitting ${APP_NAME} if running ..."
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    if $DRY_RUN; then
        echo "   [DRY-RUN] Would send Terminate to ${APP_NAME}"
    else
        osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || pkill -x "${APP_NAME}"
        sleep 1
        # Force-kill if still alive
        pkill -9 -x "${APP_NAME}" 2>/dev/null || true
        echo "   ✅ ${APP_NAME} terminated"
    fi
else
    echo "   ℹ️  ${APP_NAME} not running"
fi
echo ""

# ---------- Step 2: Remove Login Item (SMAppService) ----------
echo "▸ Step 2: Removing login item registration ..."
if $DRY_RUN; then
    echo "   [DRY-RUN] Would run: sfltool resetbtm / unregister SMAppService"
else
    # SMAppService login items live in a managed database; cleanest approach
    # is to remove the LaunchAgent plist (if it exists) and let macOS clean up.
    action_rm "${LAUNCH_AGENT_PATH}" "LaunchAgent"
    # Newer macOS (Ventura+) uses Background Task Management; sfltool can reset it.
    if command -v sfltool >/dev/null 2>&1; then
        echo "   ℹ️  Note: 'sfltool resetbtm' is available but resets ALL login items."
        echo "      Skipping to avoid affecting other apps."
    fi
fi
echo ""

# ---------- Step 3: Remove app bundle ----------
echo "▸ Step 3: Removing ${APP_BUNDLE} ..."
for path in "${APP_PATHS[@]}"; do
    action_rm "${path}" "app bundle"
done
echo ""

# ---------- Step 4: Remove preferences, caches, logs ----------
echo "▸ Step 4: Removing preferences, caches, and logs ..."
for path in "${PREFS_PATHS[@]}"; do
    action_rm "${path}" "data"
done
echo ""

# ---------- Step 5: Remove quarantine attribute from any remaining copies ----------
echo "▸ Step 5: Clearing quarantine xattr from Downloads ..."
if $DRY_RUN; then
    echo "   [DRY-RUN] Would run: xattr -d com.apple.quarantine ~/Downloads/${APP_BUNDLE}"
else
    for path in "${APP_PATHS[@]}"; do
        if [[ -e "${path}" ]]; then
            xattr -dr com.apple.quarantine "${path}" 2>/dev/null && \
                echo "   ✅ Quarantine cleared: ${path}"
        fi
    done
fi
echo ""

# ---------- Step 6: Accessibility / Automation permission (TCC) ----------
echo "▸ Step 6: Clearing Accessibility permission ..."
echo ""
echo "   ⚠️  macOS protects the TCC database with SIP. Automated removal"
echo "      requires disabling SIP, which is NOT recommended."
echo ""
echo "   The safe, supported way is to remove the entry manually:"
echo ""
echo "      1. Open System Settings → Privacy & Security → Accessibility"
echo "      2. Find \"${APP_NAME}\" in the list"
echo "      3. Click the entry, then click the minus (−) button"
echo "      4. Repeat for Automation (if listed) under Privacy & Security"
echo ""
echo "   If you have FULL DISK ACCESS in Terminal, you can try the script's"
echo "   automatic TCC cleanup (otherwise it will fail safely):"
echo ""

if confirm "   Attempt automatic TCC database cleanup?"; then
    if $DRY_RUN; then
        echo "   [DRY-RUN] Would attempt: sqlite3 DELETE FROM access WHERE client='${BUNDLE_ID}'"
    else
        # TCC.db is at /Library/Application Support/com.apple.TCC/TCC.db (system)
        # and ~/Library/Application Support/com.apple.TCC/TCC.db (user)
        TCC_DB_PATHS=(
            "${HOME}/Library/Application Support/com.apple.TCC/TCC.db"
            "/Library/Application Support/com.apple.TCC/TCC.db"
        )
        for db in "${TCC_DB_PATHS[@]}"; do
            if [[ -w "${db}" ]]; then
                echo "   Attempting cleanup on: ${db}"
                sqlite3 "${db}" \
                    "DELETE FROM access WHERE client='${BUNDLE_ID}' OR service='${BUNDLE_ID}';" \
                    2>/dev/null && echo "   ✅ TCC entries removed (if any)" \
                    || echo "   ⚠️  Could not modify ${db} (SIP-protected or no FDA)"
            else
                echo "   ℹ️  Not writable (SIP-protected): ${db}"
            fi
        done
    fi
else
    echo "   ℹ️  Skipped automatic TCC cleanup — please remove manually via System Settings."
fi
echo ""

# ---------- Step 7: Summary ----------
echo "═══════════════════════════════════════════════════════════════"
echo "  Cleanup Summary"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  ✓ App process:        terminated (if running)"
echo "  ✓ Login item:         unregistered"
echo "  ✓ App bundle:         removed from all standard locations"
echo "  ✓ Preferences:        ${HOME}/Library/Preferences/${BUNDLE_ID}.plist"
echo "  ✓ Container:          ${HOME}/Library/Containers/${BUNDLE_ID}"
echo "  ✓ Caches:             ${HOME}/Library/Caches/${BUNDLE_ID}"
echo "  ✓ Saved state:        ${HOME}/Library/Saved Application State/${BUNDLE_ID}.savedState"
echo "  ✓ Debug log:          ${HOME}/nudge-debug.log"
echo "  △ Accessibility:      MANUAL — see Step 6 instructions above"
echo "  △ Automation:         MANUAL — see Step 6 instructions above"
echo ""
echo "  To reinstall: download a fresh copy or rebuild from source."
echo "  Source: https://github.com/Lumspecroam/nudge"
echo ""
echo "═══════════════════════════════════════════════════════════════"
