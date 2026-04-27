# Update this array with your home network SSIDs (add as many as needed)
$homeSSIDs = @(
    "Your_Home_Network_SSID_1",
    "Your_Home_Network_SSID_2"
    # Add more SSIDs as needed
)

# State file stores the last trust state seen ("home" or "away") so the script
# only acts on real transitions. Delete this file to force a fresh evaluation.
$stateFile = Join-Path $PSScriptRoot "last-state.txt"

# Ethernet is treated as untrusted (we can't easily tell home vs. elsewhere),
# mirroring the Linux script. -Physical filters out virtual adapters like
# Tailscale's own, Hyper-V, and other VPN tunnels.
$ethernetUp = [bool](Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
    Where-Object { $_.MediaType -eq '802.3' -and $_.Status -eq 'Up' })

if ($ethernetUp) {
    $currentSSID = ""
    $currentState = "away"
}
else {
    $currentSSID = (netsh wlan show interfaces) | ForEach-Object {
        if ($_ -match "^\s+SSID\s+:\s+(.*)$") {
            $matches[1].Trim()
        }
    }

    if ([string]::IsNullOrEmpty($currentSSID)) {
        $currentState = "none"
    }
    elseif ($homeSSIDs -contains $currentSSID) {
        $currentState = "home"
    }
    else {
        $currentState = "away"
    }
}

$previousState = if (Test-Path $stateFile) { (Get-Content $stateFile -Raw).Trim() } else { "" }

Write-Output "Current SSID: '$currentSSID' | State: $currentState | Previous: $previousState"

if ($currentState -eq "none") {
    Write-Output "No Wi-Fi; leaving Tailscale alone."
}
elseif ($currentState -eq $previousState) {
    Write-Output "No trust-state transition; leaving Tailscale alone."
}
elseif ($currentState -eq "home") {
    Write-Output "Transition to home network. Disconnecting Tailscale..."
    tailscale down
}
elseif ($currentState -eq "away") {
    Write-Output "Transition to away network. Connecting Tailscale..."
    tailscale up
}

# Persist only home/away so a brief Wi-Fi drop doesn't trigger a reconnect cycle.
if ($currentState -ne "none") {
    Set-Content -Path $stateFile -Value $currentState -NoNewline
}
