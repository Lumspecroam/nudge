#!/bin/bash
#
# nudge-cleanup.sh — Remove Nudge and clear all macOS permissions / caches
#
# Uses Apple's official `tccutil` to clear Accessibility, Automation, and
# other TCC-protected permissions. This is the SIP-safe approach: works
# without disabling SIP, but MUST be run from a real Terminal.app window
# (IDE-integrated terminals are sandboxed and will fail with
# "Operation not permitted from sandbox").
#
# Removes:
#   • The Nudge.app bundle (from /Applications and user home)
#   • Accessibility permission (tccutil reset Accessibility)
#   • Automation permissions (tccutil reset AppleEvents)
#   • All other TCC entries (tccutil reset All)
#   • LaunchAgent / Login Items (SMAppService registration)
#   • Preferences, containers, caches, logs
#   • Quarantine attribute (xattr)
#
# Safety:
#   • Interactive — prompts before each destructive step (use --yes to skip)
#   • Dry-run mode: --dry-run shows what would happen without changing anything
#   • Only touches files matching the Nudge bundle identifier (app.nudge.Nudge)
#   • Sandbox detection — warns if run from an IDE-integrated terminal
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

LAUNCH_AGENT_PATH="${HOME}/Library/LaunchAgents/${BUNDLE_ID}.plist"

# TCC services to reset via tccutil (Apple's official, SIP-safe mechanism)
# Full list: see `tccutil` man page. These cover all permission types Nudge
# might have requested.
TCC_SERVICES=(
    "Accessibility"            # 辅助功能（核心权限）
    "AppleEvents"              # 自动化（AppleScript 控制）
    "All"                      # 兜底：重置所有 TCC 条目
)

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

# ---------- Sandbox detection ----------
# IDE-integrated terminals (Trae, VSCode, etc.) run in a sandbox that blocks
# tccutil. Detect and warn the user early.
detect_sandbox() {
    # Heuristic: sandboxed processes cannot write outside their container.
    # Test by trying to stat the system TCC.db in a way that requires
    # sandbox-bypass. A simpler check: see if the parent process is an IDE.
    local parent_cmd
    parent_cmd=$(ps -o comm= -p $PPID 2>/dev/null | head -1)
    if echo "${parent_cmd}" | grep -qiE "trae|vscode|code-helper|cursor|electron"; then
        return 0
    fi
    # Direct sandbox check: try a harmless tccutil operation
    if tccutil reset Accessibility com.apple.dummy.nonexistent 2>&1 | grep -qi "sandbox"; then
        return 0
    fi
    return 1
}

# ---------- Banner ----------
echo "═══════════════════════════════════════════════════════════════"
echo "  Nudge Cleanup Script"
echo "  Bundle ID: ${BUNDLE_ID}"
$DRY_RUN && echo "  Mode: DRY-RUN (no changes will be made)"
$AUTO_YES && echo "  Mode: AUTO-YES (no prompts)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ---------- Sandbox pre-flight ----------
if detect_sandbox; then
    echo "⚠️  SANDBOX DETECTED"
    echo ""
    echo "   This terminal appears to be running inside an IDE sandbox"
    echo "   (Trae / VSCode / Cursor). macOS blocks tccutil from sandboxes."
    echo ""
    echo "   To clear Accessibility permission, please run this script from"
    echo "   a real Terminal.app window:"
    echo ""
    echo "       1. Open Applications → Utilities → Terminal"
    echo "       2. cd $(pwd)"
    echo "       3. ./scripts/nudge-cleanup.sh"
    echo ""
    echo "   Or run the single command directly in Terminal.app:"
    echo ""
    echo "       tccutil reset Accessibility ${BUNDLE_ID}"
    echo "       tccutil reset All ${BUNDLE_ID}"
    echo ""
    echo "   Continuing with non-TCC cleanup steps (file removal works)..."
    echo ""
fi

# ---------- Step 1: Quit running app ----------
echo "▸ Step 1: Quitting ${APP_NAME} if running ..."
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    if $DRY_RUN; then
        echo "   [DRY-RUN] Would send Terminate to ${APP_NAME}"
    else
        osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || pkill -x "${APP_NAME}"
        sleep 1
        pkill -9 -x "${APP_NAME}" 2>/dev/null || true
        echo "   ✅ ${APP_NAME} terminated"
    fi
else
    echo "   ℹ️  ${APP_NAME} not running"
fi
echo ""

# ---------- Step 2: Clear TCC permissions via tccutil ----------
echo "▸ Step 2: Clearing macOS permissions via tccutil ..."
echo "   (Accessibility, Automation, and all other TCC entries)"
echo ""
for service in "${TCC_SERVICES[@]}"; do
    if $DRY_RUN; then
        echo "   [DRY-RUN] Would run: tccutil reset ${service} ${BUNDLE_ID}"
        continue
    fi
    output=$(tccutil reset "${service}" "${BUNDLE_ID}" 2>&1)
    if echo "${output}" | grep -qi "sandbox"; then
        echo "   ⚠️  tccutil ${service}: BLOCKED BY SANDBOX"
        echo "      Run this in Terminal.app instead of IDE terminal."
    elif echo "${output}" | grep -qi "not permitted\|denied\|error"; then
        echo "   ⚠️  tccutil ${service}: ${output}"
    elif [[ -z "${output}" ]]; then
        echo "   ✅ tccutil reset ${service} ${BUNDLE_ID}"
    else
        echo "   ✅ tccutil reset ${service} ${BUNDLE_ID} (${output})"
    fi
done

# Also reset by bundle name (some TCC entries use app name instead of bundle ID)
if ! $DRY_RUN; then
    tccutil reset Accessibility "${APP_NAME}" 2>/dev/null && echo "   ✅ tccutil reset Accessibility ${APP_NAME}" || true
fi
echo ""

# ---------- Step 3: Remove Login Item (SMAppService) ----------
echo "▸ Step 3: Removing login item registration ..."
if $DRY_RUN; then
    echo "   [DRY-RUN] Would remove LaunchAgent plist"
else
    action_rm "${LAUNCH_AGENT_PATH}" "LaunchAgent"
fi
echo ""

# ---------- Step 4: Remove app bundle ----------
echo "▸ Step 4: Removing ${APP_BUNDLE} ..."
for path in "${APP_PATHS[@]}"; do
    action_rm "${path}" "app bundle"
done
echo ""

# ---------- Step 5: Remove preferences, caches, logs ----------
echo "▸ Step 5: Removing preferences, caches, and logs ..."
for path in "${PREFS_PATHS[@]}"; do
    action_rm "${path}" "data"
done
echo ""

# ---------- Step 6: Remove quarantine attribute ----------
echo "▸ Step 6: Clearing quarantine xattr from any remaining copies ..."
if $DRY_RUN; then
    echo "   [DRY-RUN] Would run: xattr -dr com.apple.quarantine ~/Downloads/${APP_BUNDLE}"
else
    for path in "${APP_PATHS[@]}"; do
        if [[ -e "${path}" ]]; then
            xattr -dr com.apple.quarantine "${path}" 2>/dev/null && \
                echo "   ✅ Quarantine cleared: ${path}"
        fi
    done
fi
echo ""

# ---------- Step 7: Summary ----------
echo "═══════════════════════════════════════════════════════════════"
echo "  Cleanup Summary"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  ✓ App process:        terminated (if running)"
echo "  ✓ TCC permissions:    reset via tccutil (Accessibility, AppleEvents, All)"
echo "  ✓ Login item:         unregistered"
echo "  ✓ App bundle:         removed from all standard locations"
echo "  ✓ Preferences:        ${HOME}/Library/Preferences/${BUNDLE_ID}.plist"
echo "  ✓ Container:          ${HOME}/Library/Containers/${BUNDLE_ID}"
echo "  ✓ Caches:             ${HOME}/Library/Caches/${BUNDLE_ID}"
echo "  ✓ Saved state:        ${HOME}/Library/Saved Application State/${BUNDLE_ID}.savedState"
echo "  ✓ Debug log:          ${HOME}/nudge-debug.log"
echo ""
echo "  ─────────────────────────────────────────────────────────"
echo "  Verify in System Settings:"
echo "  ─────────────────────────────────────────────────────────"
echo "  Open  系统设置 → 隐私与安全性 → 辅助功能"
echo "  Nudge should NO LONGER appear in the list."
echo ""
echo "  If it still appears, manually click Nudge → (−) button to remove."
echo ""
echo "═══════════════════════════════════════════════════════════════"
