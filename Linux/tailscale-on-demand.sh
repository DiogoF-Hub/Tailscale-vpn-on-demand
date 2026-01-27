#!/usr/bin/env bash
set -euo pipefail

# Home Wi-Fi SSIDs
HOME_SSIDS=("SSID_1" "SSID_2")

# Username to run tailscale commands as
TAILSCALE_USER="myuser"

# Functions for clean Tailscale control
tailscale_connect() {
    su - "$TAILSCALE_USER" -c "tailscale up --accept-dns --accept-routes"
}

tailscale_disconnect() {
    su - "$TAILSCALE_USER" -c "tailscale down"
}

# Check if Ethernet is connected (takes priority)
HAS_ETHERNET="$(nmcli -t -f TYPE,STATE dev 2>/dev/null | awk -F: '$1=="ethernet" && $2=="connected"{print "yes"; exit}')"

# If on Ethernet, always connect (Its not so easy to identify which ethernet is home, so we assume any ethernet is trusted)
[[ "$HAS_ETHERNET" == "yes" ]] && tailscale_connect

# Get active Wi-Fi SSID (only matters if no Ethernet)
CURRENT_SSID="$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')"

# If not on Wi-Fi either, do nothing
[[ -z "$CURRENT_SSID" ]] && exit 0

# Check if on home Wi-Fi
for s in "${HOME_SSIDS[@]}"; do
    [[ "$CURRENT_SSID" == "$s" ]] && tailscale_disconnect
done

# Not on home Wi-Fi, connect
tailscale_connect
