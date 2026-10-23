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

# Ask Tailscale whether it's actually connected, so an "away" state can't get
# stuck with Tailscale stopped (manual disconnect, client restart, failed up).
$tailscaleRunning = $false
try {
    $tailscaleRunning = ((tailscale status --json 2>$null | Out-String | ConvertFrom-Json).BackendState -eq 'Running')
}
catch { }

Write-Output "Current SSID: '$currentSSID' | State: $currentState | Previous: $previousState | Tailscale running: $tailscaleRunning"

$commandFailed = $false

if ($currentState -eq "none") {
    Write-Output "No network; leaving Tailscale alone."
}
elseif ($currentState -eq "away") {
    # Away is always enforced: connect whenever Tailscale isn't running.
    if ($tailscaleRunning) {
        Write-Output "Away network and Tailscale already running; nothing to do."
    }
    else {
        Write-Output "Away network and Tailscale not running. Connecting Tailscale..."
        tailscale up
        $commandFailed = ($LASTEXITCODE -ne 0)
    }
}
elseif ($currentState -eq $previousState) {
    # Home only acts on transitions, so a manual `tailscale up` at home survives.
    Write-Output "Still on home network; leaving Tailscale alone."
}
else {
    Write-Output "Transition to home network. Disconnecting Tailscale..."
    tailscale down
    $commandFailed = ($LASTEXITCODE -ne 0)
}

# Persist only home/away so a brief Wi-Fi drop doesn't trigger a reconnect cycle.
# Skip it if the tailscale command failed so the next run retries.
if ($commandFailed) {
    Write-Output "tailscale command failed (exit code $LASTEXITCODE); not saving state."
}
elseif ($currentState -ne "none") {
    Set-Content -Path $stateFile -Value $currentState -NoNewline
}
