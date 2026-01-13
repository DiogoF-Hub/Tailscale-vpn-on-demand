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

## ⚙️ Setup Instructions

### **1. Configure Your Home SSIDs**

Edit `tailscale-on-demand.sh` and update the SSID array:

```bash
HOME_SSIDS=("SSID_1" "SSID_2")
```

### **2. Install the Main Script**

Copy `tailscale-on-demand.sh` to `/usr/local/sbin/`:

```bash
sudo cp tailscale-on-demand.sh /usr/local/sbin/
sudo chmod +x /usr/local/sbin/tailscale-on-demand.sh
```

### **3. Install the NetworkManager Dispatcher Hook**

Copy `99-tailscale-on-demand` to NetworkManager's dispatcher directory:

```bash
sudo cp 99-tailscale-on-demand /etc/NetworkManager/dispatcher.d/
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-tailscale-on-demand
```

### **4. Set Tailscale Operator (Optional but Recommended)**

Allow your user to control Tailscale without sudo:

```bash
sudo tailscale set --operator=$USER
```

This enables the script to run `tailscale` commands as your user, avoiding permission issues.

### **5. Ensure Required Services Are Running**

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now tailscaled
```

---

## 🧪 Testing

### **Live Test**

1. Connect to your home Wi-Fi → Tailscale should disconnect
2. Connect to any other Wi-Fi → Tailscale should connect
3. Connect via Ethernet → Tailscale should connect
4. Switch between networks and verify behavior

### **Debug Mode**

To see what the script is doing, you can run it directly:

```bash
sudo /usr/local/sbin/tailscale-on-demand.sh
```

If you're on Ethernet or Wi-Fi, it will execute immediately. If not, it exits silently (which is correct behavior).

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
    exec tailscale up --accept-dns=false --accept-routes=true --shields-up
}
```

See `tailscale up --help` for all available options.

---

## 🛠 Troubleshooting

**Script doesn't trigger automatically**:
- Verify NetworkManager is running: `systemctl status NetworkManager`
- Check dispatcher directory permissions: `ls -la /etc/NetworkManager/dispatcher.d/`
- Ensure both scripts are executable (`chmod +x`)

**Tailscale doesn't connect/disconnect**:
- Run script manually to see if it works: `sudo /usr/local/sbin/tailscale-on-demand.sh`
- Check your connection type: `nmcli -t -f TYPE,STATE dev`
- Check your current SSID (if on Wi-Fi): `nmcli -t -f active,ssid dev wifi`
- Verify SSID spelling matches exactly in the `HOME_SSIDS` array

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
- **Direct execution**: Uses `exec` to replace the shell process (no lingering processes)
