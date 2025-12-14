#!/usr/bin/env bash
set -euo pipefail

# Home Wi-Fi SSIDs
HOME_SSIDS=("SSID_1" "SSID_2")

# Get active Wi-Fi SSID, empty if not on Wi-Fi
CURRENT_SSID="$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')"

# If not on Wi-Fi, do nothing
[[ -z "$CURRENT_SSID" ]] && exit 0

# Check if home
for s in "${HOME_SSIDS[@]}"; do
    [[ "$CURRENT_SSID" == "$s" ]] && exec tailscale down
done

# Not home
exec tailscale up --accept-dns=true --accept-routes=true
