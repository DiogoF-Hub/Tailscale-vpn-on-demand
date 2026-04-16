# Tailscale Linux VPN On-Demand

This folder contains an **event-driven automation solution** for Linux to automatically connect/disconnect Tailscale VPN based on your current network.

**⚠️ Requirements**: This solution requires **NetworkManager**. It won't work out-of-the-box with other network management systems (systemd-networkd, ConnMan, wicd, etc.), though it may be possible to adapt it to work with those systems while keeping the same base principle.

---

## 📂 Structure

```
Linux/
├── tailscale-on-demand.sh     # Core script: SSID detection + Tailscale control
├── 99-tailscale-on-demand     # NetworkManager dispatcher hook
└── README.md                  # This documentation
```

---

## 🎯 How It Works

1. **Network change detection**: NetworkManager automatically runs dispatcher scripts when network state changes
2. **Event filtering**: The dispatcher hook (`99-tailscale-on-demand`) only triggers on relevant events (`up`, `dhcp4-change`, `dhcp6-change`)
3. **Connection priority detection**: `tailscale-on-demand.sh` uses `nmcli` to check connections with Ethernet taking priority
4. **Automatic control**:
   - If **Ethernet is connected** → Always connect Tailscale (considered untrusted, even if Wi-Fi is also connected)
   - If **only home Wi-Fi** is connected (SSID matches your list) → Disconnect Tailscale
   - If **only other Wi-Fi** is connected → Connect Tailscale with DNS/route acceptance
   - If neither Ethernet nor Wi-Fi → Do nothing (exit silently)

This ensures you're always protected on public/external networks (including all Ethernet) while avoiding unnecessary VPN overhead at home Wi-Fi. Ethernet always takes priority when both connections are active.

---

## ✅ Prerequisites

Before you start, make sure:

- **Tailscale is installed** and you're logged in — see [tailscale.com/download/linux](https://tailscale.com/download/linux)
- The `tailscale` CLI works: `tailscale status`
- **NetworkManager** is your network manager:
  ```bash
  systemctl status NetworkManager
  ```
- **`tailscaled`** service is running:
  ```bash
  systemctl status tailscaled
  ```
- You have **`sudo` access** (needed to install files under `/usr/local/sbin/` and `/etc/NetworkManager/`)
- You know your **home Wi-Fi SSID(s)** exactly as NetworkManager sees them:
  ```bash
  nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2}'
  ```

---

## ⚙️ Setup Instructions

### **1. Configure the Main Script**

Open `tailscale-on-demand.sh` and set **two** values at the top:

```bash
# Home Wi-Fi SSIDs (add as many as you need)
HOME_SSIDS=("My_Home_WiFi" "My_Home_WiFi_5G")

# The user whose Tailscale session should be controlled
TAILSCALE_USER="your_username"
```

- `HOME_SSIDS` is **case-sensitive** and must match exactly what `nmcli` reports
- `TAILSCALE_USER` is the Linux user that owns the Tailscale session — usually your normal login user (run `whoami` to get it). The script runs as root (via the dispatcher) and uses `su` to drop to this user.

---

### **2. Install the Main Script**

Copy it to `/usr/local/sbin/` and make it executable:

```bash
sudo cp tailscale-on-demand.sh /usr/local/sbin/
sudo chmod +x /usr/local/sbin/tailscale-on-demand.sh
```

---

### **3. Install the NetworkManager Dispatcher Hook**

Copy the hook into NetworkManager's dispatcher directory and make it executable:

```bash
sudo cp 99-tailscale-on-demand /etc/NetworkManager/dispatcher.d/
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-tailscale-on-demand
```

> 💡 Dispatcher scripts must be owned by **root** and not writable by others. The `sudo cp` above handles ownership; the default umask handles permissions.

---

### **4. Set the Tailscale Operator (Required)**

The dispatcher runs the script as **root**, which then uses `su "$TAILSCALE_USER"` to run `tailscale up`/`down` as your normal user. That only works if your user is allowed to control Tailscale without `sudo` — which is exactly what the **operator** flag does:

```bash
sudo tailscale set --operator=$USER
```

> ⚠️ This is **not optional** for this setup. Without it, every `tailscale up`/`down` call inside the script will fail with a permission error.

If `TAILSCALE_USER` in the script is **not** the user you're logged in as right now, replace `$USER` with that username:

```bash
sudo tailscale set --operator=your_username
```

---

### **5. Make Sure Services Are Enabled at Boot**

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now tailscaled
```

---

## 🧪 Testing

### **Manual Run**

Run the script directly to confirm it behaves correctly for your current network:

```bash
sudo /usr/local/sbin/tailscale-on-demand.sh
tailscale status
```

Expected behavior:
- On a home SSID → Tailscale is **stopped**
- On any other Wi-Fi → Tailscale is **connected**
- On Ethernet → Tailscale is **connected**
- No active connection → script exits silently (no change)

### **Live Test**

1. Connect to your home Wi-Fi → Tailscale should disconnect
2. Connect to any other Wi-Fi → Tailscale should connect
3. Connect via Ethernet → Tailscale should connect
4. Switch between networks and verify with `tailscale status`

### **Watch the Dispatcher Fire**

To confirm NetworkManager actually triggers the hook, tail the journal while switching networks:

```bash
journalctl -u NetworkManager -f
```

---

## 🔧 Configuration

### **Add More Home Networks**

Edit the SSID array in `/usr/local/sbin/tailscale-on-demand.sh`:

```bash
HOME_SSIDS=("Home_Network" "Home_5G" "Parents_WiFi")
```

### **Change Tailscale Connection Flags**

Modify the `tailscale_connect()` function in the script:

```bash
tailscale_connect() {
    su "$TAILSCALE_USER" -c "tailscale up --accept-dns=false --accept-routes=true --shields-up"
}
```

See `tailscale up --help` for all available options.

---

## 🛠 Troubleshooting

**Script doesn't trigger automatically**:
- Verify NetworkManager is running: `systemctl status NetworkManager`
- Verify the dispatcher script is executable and owned by root:
  ```bash
  ls -la /etc/NetworkManager/dispatcher.d/99-tailscale-on-demand
  ```
- Watch NetworkManager logs while switching networks: `journalctl -u NetworkManager -f`

**Tailscale doesn't connect/disconnect**:
- Run the script manually: `sudo /usr/local/sbin/tailscale-on-demand.sh`
- Check your connection type: `nmcli -t -f TYPE,STATE dev`
- Check your current SSID (if on Wi-Fi): `nmcli -t -f active,ssid dev wifi`
- Verify `HOME_SSIDS` spelling matches exactly (case-sensitive)
- Verify `TAILSCALE_USER` matches a real user that's logged into Tailscale

**"Operation not permitted" or permission errors**:
- You skipped Step 4. Run: `sudo tailscale set --operator=$USER`
- Confirm `TAILSCALE_USER` in the script matches the user you set as operator

**Not working on your distro**:
- This solution requires NetworkManager.
- If using systemd-networkd or another system, you'll need a different approach.

---

## 📝 How It Works (Technical Details)

- **NetworkManager dispatcher**: Runs scripts in `/etc/NetworkManager/dispatcher.d/` when network events occur
- **Event filtering**: Only processes `up`, `dhcp4-change`, and `dhcp6-change` states to avoid redundant executions
- **Priority-based detection**: Checks for Ethernet first, then Wi-Fi—Ethernet always takes precedence when both are connected
- **Ethernet handling**: All Ethernet connections are treated as untrusted (auto-connect), even when home Wi-Fi is also active
- **Silent failures**: Uses `set -euo pipefail` for strict error handling, exits silently if not on Ethernet/Wi-Fi
- **Efficient detection**: Uses `nmcli` with awk parsing for fast, reliable connection detection and SSID extraction
- **Clean functions**: `tailscale_connect()` and `tailscale_disconnect()` functions make the code maintainable
- **User switching**: Dispatcher runs as root; script uses `su "$TAILSCALE_USER"` to run `tailscale` commands as the owning user
