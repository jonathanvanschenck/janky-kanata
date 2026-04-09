#!/usr/bin/env bash
set -euo pipefail

# ── constants ────────────────────────────────────────────────────────────────
KANATA_BIN="${HOME}/.local/bin/kanata"
KANATA_CONFIG="${HOME}/.config/kanata/init.kbd"
SERVICE_TEMPLATE="${HOME}/.config/kanata/kanata.service.template"
SYSTEM_SERVICE="/etc/systemd/system/kanata.service"
USER_SERVICE="${HOME}/.config/systemd/user/kanata.service"
GITHUB_RELEASES="https://api.github.com/repos/jtroo/kanata/releases/latest"
BINARY_BASE_URL="https://github.com/jtroo/kanata/releases/download"
BINARY_NAME="kanata_cmd_allowed"

# ── helpers ──────────────────────────────────────────────────────────────────
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

confirm() {
    # Usage: confirm "Question?" [default: y/n]
    local prompt="$1"
    local default="${2:-n}"
    local yn_hint
    if [[ "$default" == "y" ]]; then
        yn_hint="[Y/n]"
    else
        yn_hint="[y/N]"
    fi
    while true; do
        read -rp "$(bold "$prompt $yn_hint: ")" answer
        answer="${answer:-$default}"
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     yellow "Please answer y or n." ;;
        esac
    done
}

version_gt() {
    # Returns 0 if $1 > $2 (semver, no pre-release handling needed)
    [[ "$1" == "$2" ]] && return 1
    local IFS=.
    local ver1=($1) ver2=($2)
    for i in 0 1 2; do
        local a="${ver1[$i]:-0}" b="${ver2[$i]:-0}"
        (( a > b )) && return 0
        (( a < b )) && return 1
    done
    return 1
}

# ── step 1: fetch latest version from GitHub ─────────────────────────────────
bold "── Checking latest kanata release ─────────────────────────────────────"

LATEST_VERSION=""
if command -v curl &>/dev/null; then
    LATEST_VERSION=$(curl -fsSL "$GITHUB_RELEASES" \
        | grep '"tag_name"' \
        | head -1 \
        | sed 's/.*"v\([^"]*\)".*/\1/')
elif command -v wget &>/dev/null; then
    LATEST_VERSION=$(wget -qO- "$GITHUB_RELEASES" \
        | grep '"tag_name"' \
        | head -1 \
        | sed 's/.*"v\([^"]*\)".*/\1/')
fi

if [[ -z "$LATEST_VERSION" ]]; then
    yellow "Could not fetch latest version from GitHub (offline?). Falling back to README version 1.8.1."
    LATEST_VERSION="1.8.1"
else
    green "Latest kanata release: v${LATEST_VERSION}"
fi

# ── step 2: check for installed binary ───────────────────────────────────────
bold "── Checking for kanata binary ──────────────────────────────────────────"

INSTALLED_VERSION=""
INSTALLED_PATH=""

if [[ -x "$KANATA_BIN" ]]; then
    INSTALLED_PATH="$KANATA_BIN"
elif command -v kanata &>/dev/null; then
    INSTALLED_PATH="$(command -v kanata)"
fi

if [[ -n "$INSTALLED_PATH" ]]; then
    raw=$("$INSTALLED_PATH" --version 2>&1 || true)
    # Output is typically "kanata v1.8.1" or "kanata 1.8.1"
    INSTALLED_VERSION=$(echo "$raw" | grep -oP '\d+\.\d+\.\d+' | head -1 || true)
    if [[ -n "$INSTALLED_VERSION" ]]; then
        green "Found kanata v${INSTALLED_VERSION} at ${INSTALLED_PATH}"
    else
        green "Found kanata at ${INSTALLED_PATH} (version unknown)"
    fi
else
    yellow "kanata binary not found."
fi

# ── step 3: decide whether to download ───────────────────────────────────────
bold "── Binary download ─────────────────────────────────────────────────────"

DO_DOWNLOAD=false
DOWNLOAD_URL="${BINARY_BASE_URL}/v${LATEST_VERSION}/${BINARY_NAME}"

if [[ -z "$INSTALLED_PATH" ]]; then
    if confirm "kanata is not installed. Download v${LATEST_VERSION} to ${KANATA_BIN}?" "y"; then
        DO_DOWNLOAD=true
    fi
elif [[ -n "$INSTALLED_VERSION" ]] && version_gt "$LATEST_VERSION" "$INSTALLED_VERSION"; then
    yellow "A newer version is available: v${LATEST_VERSION} (installed: v${INSTALLED_VERSION})"
    if confirm "Download and replace with v${LATEST_VERSION}?" "y"; then
        DO_DOWNLOAD=true
    fi
else
    green "kanata is up to date (v${INSTALLED_VERSION})."
fi

if [[ "$DO_DOWNLOAD" == true ]]; then
    mkdir -p "$(dirname "$KANATA_BIN")"
    echo "Downloading ${DOWNLOAD_URL} ..."
    if command -v curl &>/dev/null; then
        curl -fL --progress-bar -o "$KANATA_BIN" "$DOWNLOAD_URL"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "$KANATA_BIN" "$DOWNLOAD_URL"
    else
        red "Neither curl nor wget is available. Cannot download."
        exit 1
    fi
    chmod +x "$KANATA_BIN"
    green "kanata v${LATEST_VERSION} installed to ${KANATA_BIN}"
    INSTALLED_PATH="$KANATA_BIN"
fi

# Bail out here if we still have no binary
if [[ -z "$INSTALLED_PATH" ]]; then
    red "No kanata binary available. Skipping service setup."
    exit 0
fi

# ── step 4: detect existing services ─────────────────────────────────────────
bold "── Detecting existing services ─────────────────────────────────────────"

HAS_SYSTEM_SERVICE=false
HAS_USER_SERVICE=false

if [[ -f "$SYSTEM_SERVICE" ]]; then
    green "System service found: ${SYSTEM_SERVICE}"
    HAS_SYSTEM_SERVICE=true
fi
if [[ -f "$USER_SERVICE" ]]; then
    green "User service found: ${USER_SERVICE}"
    HAS_USER_SERVICE=true
fi

if $HAS_SYSTEM_SERVICE && $HAS_USER_SERVICE; then
    yellow "Both a system service and a user service exist — nothing to set up."
    exit 0
fi

if $HAS_SYSTEM_SERVICE || $HAS_USER_SERVICE; then
    yellow "A service is already configured. Skipping service setup."
    exit 0
fi

# ── step 5: offer service setup ───────────────────────────────────────────────
bold "── Service setup ───────────────────────────────────────────────────────"

if ! confirm "No kanata service found. Set one up now?" "y"; then
    yellow "Skipping service setup."
    exit 0
fi

echo ""
bold "Which type of service would you like?"
echo "  1) System service  (runs as root for all users, requires sudo)"
echo "  2) User service    (runs as your user, no sudo required)"
echo ""

SERVICE_TYPE=""
while [[ "$SERVICE_TYPE" != "1" && "$SERVICE_TYPE" != "2" ]]; do
    read -rp "$(bold "Enter 1 or 2: ")" SERVICE_TYPE
done

# Generate the service file from the template
if [[ ! -f "$SERVICE_TEMPLATE" ]]; then
    red "Service template not found at ${SERVICE_TEMPLATE}"
    exit 1
fi

build_service_file() {
    local bin_path="$1"
    local cfg_path="$2"
    local want_by="$3"
    sed \
        -e "s|ExecStart=.*|ExecStart=${bin_path} -c ${cfg_path}|" \
        -e "s|WantedBy=.*|WantedBy=${want_by}|" \
        "$SERVICE_TEMPLATE"
}

if [[ "$SERVICE_TYPE" == "1" ]]; then
    # ── system service ──────────────────────────────────────────────────────
    SERVICE_CONTENT=$(build_service_file "$INSTALLED_PATH" "$KANATA_CONFIG" "multi-user.target")

    echo ""
    echo "The following will be written to ${SYSTEM_SERVICE}:"
    echo "────────────────────────────────────────────────────"
    echo "$SERVICE_CONTENT"
    echo "────────────────────────────────────────────────────"

    if ! confirm "Proceed with sudo?" "y"; then
        yellow "Aborted."
        exit 0
    fi

    echo "$SERVICE_CONTENT" | sudo tee "$SYSTEM_SERVICE" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable kanata.service
    sudo systemctl start kanata.service
    green "System service enabled and started."
    echo "  Status: $(sudo systemctl is-active kanata.service)"

else
    # ── user service ────────────────────────────────────────────────────────
    SERVICE_CONTENT=$(build_service_file "$INSTALLED_PATH" "$KANATA_CONFIG" "default.target")
    mkdir -p "$(dirname "$USER_SERVICE")"

    echo ""
    echo "The following will be written to ${USER_SERVICE}:"
    echo "────────────────────────────────────────────────────"
    echo "$SERVICE_CONTENT"
    echo "────────────────────────────────────────────────────"

    if ! confirm "Proceed?" "y"; then
        yellow "Aborted."
        exit 0
    fi

    echo "$SERVICE_CONTENT" > "$USER_SERVICE"
    systemctl --user daemon-reload
    systemctl --user enable kanata.service
    systemctl --user start kanata.service
    green "User service enabled and started."
    echo "  Status: $(systemctl --user is-active kanata.service)"

    # Remind about lingering so the service survives logout
    if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
        yellow "Note: enable lingering so the service starts at boot without a login session:"
        echo "  sudo loginctl enable-linger $USER"
    fi
fi

green "Done!"
