#!/usr/bin/env bash
set -euo pipefail

# Home Wi-Fi SSIDs
HOME_SSIDS=("SSID_1" "SSID_2")

# Username to run tailscale commands as
TAILSCALE_USER="your_username"

# State file stores the last trust state seen ("home" or "away") so the script
# only acts on real transitions. Delete this file to force a fresh evaluation.
STATE_FILE="/var/lib/tailscale-on-demand.state"

# Functions for clean Tailscale control
tailscale_connect() {
    su "$TAILSCALE_USER" -c "tailscale up --accept-dns --accept-routes --operator=\"$TAILSCALE_USER\" --reset"
}

tailscale_disconnect() {
    su "$TAILSCALE_USER" -c "tailscale down"
}

# Determine current trust state: "home", "away", or "none"
HAS_ETHERNET="$(nmcli -t -f TYPE,STATE dev 2>/dev/null | awk -F: '$1=="ethernet" && $2=="connected"{print "yes"; exit}')"

if [[ "$HAS_ETHERNET" == "yes" ]]; then
    # Ethernet is treated as untrusted (we can't easily tell home vs. elsewhere).
    CURRENT_STATE="away"
else
    CURRENT_SSID="$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')"
    if [[ -z "$CURRENT_SSID" ]]; then
        CURRENT_STATE="none"
    else
        CURRENT_STATE="away"
        for s in "${HOME_SSIDS[@]}"; do
            if [[ "$CURRENT_SSID" == "$s" ]]; then
                CURRENT_STATE="home"
                break
            fi
        done
    fi
fi

# Read previous state (empty if file doesn't exist yet)
PREVIOUS_STATE=""
[[ -f "$STATE_FILE" ]] && PREVIOUS_STATE="$(cat "$STATE_FILE" 2>/dev/null || true)"

# Act on trust state; ignore "none" (no network)
if [[ "$CURRENT_STATE" == "none" ]]; then
    exit 0
elif [[ "$CURRENT_STATE" == "away" ]]; then
    # Away is always enforced: connect whenever Tailscale isn't running
    # (manual disconnect, client restart, failed up), not just on transitions.
    # `tailscale status` exits non-zero when stopped or logged out.
    if ! tailscale status >/dev/null 2>&1; then
        tailscale_connect
    fi
elif [[ "$CURRENT_STATE" == "$PREVIOUS_STATE" ]]; then
    # Home only acts on transitions, so a manual `tailscale up` at home survives
    exit 0
else
    tailscale_disconnect
fi

# Persist only home/away so a brief network drop doesn't trigger a reconnect cycle
printf '%s' "$CURRENT_STATE" > "$STATE_FILE"
