# Tailscale VPN On-Demand

Automatically connect/disconnect Tailscale VPN based on your network location. When you're on trusted home networks, Tailscale disconnects. On any other network (coffee shops, public Wi-Fi, work), it automatically connects to keep you secure.

## 🎯 Why This Exists
Tailscale doesn't natively support automatic connection based on network detection (except on iOS and macOS). This project provides cross-platform automation that:

- **Protects you everywhere else**: Auto-connects on untrusted networks (public Wi-Fi, cellular, etc.)
- **Saves resources at home**: Auto-disconnects when you're on your trusted home network(s)
- **Works silently**: No user interaction required, purely event-driven

## 🖥️ Platform Support

This project provides **two independent implementations** tailored to each platform's native automation:

- **[Linux](Linux/)** - Uses NetworkManager dispatcher hooks (requires NetworkManager)
- **[Windows](Windows/)** - Uses Task Scheduler with PowerShell and VBScript

Each platform has its own README with complete setup instructions.

## 🚀 Quick Start

1. Pick your platform and check prerequisites: [Linux](Linux/README.md#-prerequisites) or [Windows](Windows/README.md#-prerequisites)
2. Follow the platform-specific setup instructions
3. Configure your trusted home network SSID(s)
4. Done! Your VPN will now connect/disconnect automatically

## 🧭 Platform Feature Parity

Both platforms share the same core behavior (home Wi-Fi → disconnect, anything else → connect):

| Capability | Linux | Windows |
|---|---|---|
| Home Wi-Fi SSID detection | ✅ | ✅ |
| Ethernet treated as untrusted (auto-connect) | ✅ | ✅ |
| Transition-based logic (manual override survives) | ✅ | ✅ |
| Trigger mechanism | NetworkManager dispatcher | Task Scheduler event trigger |
| Runs silently in background | ✅ | ✅ |

## 📋 How It Works

Both implementations follow the same logic:

1. Monitor network state changes (new connections, DHCP renewals)
2. Classify the current network as `home` (matches your SSID list) or `away` (anything else)
3. Compare against the last state stored in a small state file
4. Only act on real transitions:
   - `away → home` → Disconnect Tailscale
   - `home → away` → Connect Tailscale
   - Same state as before → Do nothing

This transition-based design means you can **manually `tailscale up` at home** (e.g. to use a Mullvad exit node) without the script immediately reverting it. The next time you actually leave and come back, the script will disconnect again.

The key difference is **how** each platform triggers this logic:

- **Linux**: NetworkManager runs dispatcher scripts on network events
- **Windows**: Task Scheduler responds to NetworkProfile event log entries

## 🔧 Configuration

Configuration is done by editing variables at the top of each platform's main script — no config files:

- **Linux** (`tailscale-on-demand.sh`): set the `HOME_SSIDS` array **and** `TAILSCALE_USER` (the user whose Tailscale session the script controls)
- **Windows** (`tailscale.ps1`): set the `$homeSSIDs` array

See the platform READMEs for the full setup, including path and Task Scheduler / NetworkManager wiring.