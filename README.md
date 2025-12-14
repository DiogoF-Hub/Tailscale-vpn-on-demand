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

1. Choose your platform: [Linux](Linux/README.md) or [Windows](Windows/README.md)
2. Follow the platform-specific setup instructions
3. Configure your trusted home network SSID(s)
4. Done! Your VPN will now connect/disconnect automatically

## 📋 How It Works

Both implementations follow the same logic:

1. Monitor network state changes (new connections, DHCP renewals)
2. Detect current Wi-Fi SSID
3. If SSID matches your home network(s) → Disconnect Tailscale
4. If on any other network → Connect Tailscale

The key difference is **how** each platform triggers this logic:

- **Linux**: NetworkManager runs dispatcher scripts on network events
- **Windows**: Task Scheduler responds to NetworkProfile event log entries

## 🔧 Configuration

All configuration is done by editing a single array of trusted SSIDs in each platform's main script:

**Linux**: Edit `HOME_SSIDS` array in `tailscale-on-demand.sh`
**Windows**: Edit `$homeSSIDs` array in `tailscale.ps1`

No complex config files, just simple string arrays.