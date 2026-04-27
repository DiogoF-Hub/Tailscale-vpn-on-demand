# Tailscale Windows VPN On-Demand

This folder contains a **custom automation solution** for Windows to automatically connect/disconnect Tailscale VPN based on your current network.

The **Windows Tailscale client doesn't natively support automatic connection based on network detection**, so this solution uses PowerShell and Windows Task Scheduler to provide that functionality.

---

## 📂 Structure

```
Windows/
├── tailscale.ps1           # PowerShell script that detects SSID and controls Tailscale
├── tailscale-launcher.vbs  # VBScript wrapper for silent execution (no console window)
├── Task Scheduler.xml      # Windows Task Scheduler configuration
└── README.md               # This documentation
```

---

## 🎯 How It Works

1. **Network change detection**: Windows Task Scheduler monitors network profile changes (Event IDs 10000 and 10002)
2. **Silent execution**: When triggered, it runs `tailscale-launcher.vbs` (no visible window)
3. **Connection priority detection**: `tailscale.ps1` first checks for an active physical Ethernet adapter (`Get-NetAdapter -Physical`), and falls back to Wi-Fi SSID detection (`netsh wlan show interfaces`) when no Ethernet is connected. Ethernet is always classified as `away`/untrusted (we can't easily tell home Ethernet from elsewhere).
4. **Transition-based control**: The script classifies the current network as `home`, `away`, or `none` and compares it against the last trust state stored in `last-state.txt` (next to the script). It only acts when the trust state actually changes:
   - **`away` → `home`** (you came home on Wi-Fi) → Disconnect Tailscale
   - **`home` → `away`** (you left home, or plugged in Ethernet) → Connect Tailscale
   - **Same state as before** (e.g. DHCP renewal, Wi-Fi blip, the Tailscale adapter itself coming online) → Do nothing
   - **`none`** (no Ethernet and no Wi-Fi) → Do nothing

This ensures you're always protected on public/external networks (including all Ethernet) while avoiding unnecessary VPN overhead at home Wi-Fi — and crucially, it lets you **manually `tailscale up` while at home** (e.g. to use a Mullvad exit node) without the script immediately undoing it. The next time you actually leave and come back home, the script will disconnect again.

---

## ✅ Prerequisites

Before you start, make sure:

- **Tailscale is installed** and you're logged in — download from [tailscale.com/download](https://tailscale.com/download)
- The `tailscale` CLI works in PowerShell: run `tailscale status` to confirm
- You have **administrator rights** on your machine (needed to import the scheduled task)
- You know your **home Wi-Fi SSID(s)** exactly as Windows sees them — check with:
  ```powershell
  netsh wlan show interfaces
  ```

---

## ⚙️ Setup Instructions

### **1. Pick a Permanent Location for the Scripts**

Create a folder where the scripts will live — they must not move after setup. Example:

```
C:\Users\YourUsername\Documents\Tailscale\
```

Copy `tailscale.ps1` and `tailscale-launcher.vbs` into that folder.

> 💡 Write down this full path — you'll paste it into three places below.

---

### **2. Configure Your Home SSIDs**

Open `tailscale.ps1` in your chosen folder and replace the placeholder SSIDs with your own:

```powershell
$homeSSIDs = @(
    "My_Home_WiFi",
    "My_Home_WiFi_5G"
    # Add more SSIDs as needed
)
```

SSIDs are **case-sensitive** and must match exactly what `netsh wlan show interfaces` reports.

---

### **3. Update the Path in `tailscale-launcher.vbs`**

Open `tailscale-launcher.vbs` and replace the path with the full path to your `tailscale.ps1`:

```vb
objShell.Run "powershell.exe -ExecutionPolicy Bypass -File ""C:\Users\YourUsername\Documents\Tailscale\tailscale.ps1""", 0, False
```

Keep the **doubled quotes** (`""`) around the path — VBScript requires them.

---

### **4. Update `Task Scheduler.xml`**

Open `Task Scheduler.xml` in a text editor and change **three** values:

| Tag | What to put |
|---|---|
| `<Author>` | `COMPUTERNAME\username` — run `whoami` in PowerShell to get it |
| `<UserId>` | Your user SID — run `whoami /user` in PowerShell to get it |
| `<Arguments>` | The full path to `tailscale-launcher.vbs`, keeping the surrounding quotes |

Example `<Arguments>` line:

```xml
<Arguments>"C:\Users\YourUsername\Documents\Tailscale\tailscale-launcher.vbs"</Arguments>
```

> 💡 The `<UserId>` field is what ties the task to your account. If you skip it, Task Scheduler will ask for it during import — that's fine too.

---

### **5. Import the Scheduled Task**

1. Press `Win + R`, type `taskschd.msc`, and press Enter
2. In the right panel, click **Import Task…**
3. Select your edited `Task Scheduler.xml`
4. Review the settings — if prompted, enter your Windows password so the task can run in the background
5. Click **OK** to create the task named **"Tailscale VPN On Demand"**

---

### **6. Test the Setup**

**Manual run** (does it work at all?):

1. In Task Scheduler, find **"Tailscale VPN On Demand"** in the task list
2. Right-click → **Run**
3. Open PowerShell and check: `tailscale status`
   - On a home SSID → should be **stopped**
   - On any other network → should be **connected**

**Live test** (does it trigger automatically?):

1. Disconnect from Wi-Fi, then reconnect — or switch networks
2. Wait a few seconds, then check `tailscale status` again
3. In Task Scheduler, open the task → **History** tab to confirm it fired

---

## 🔒 Security Notes

- The script uses `-ExecutionPolicy Bypass` to allow execution without signing
- VBScript runs with `0` window mode for silent operation
- Task runs with **HighestAvailable** privileges (required for Tailscale control)
- No sensitive data is stored in these scripts

---

## 🛠 Troubleshooting

**Task doesn't trigger automatically**:
- Verify the task is **Enabled** in Task Scheduler
- Check that Event IDs 10000 and 10002 exist in `Microsoft-Windows-NetworkProfile/Operational` log (Event Viewer → Applications and Services Logs)
- Ensure paths in both the VBS and XML are correct and absolute
- Open the task → **History** tab to see if it fired and what happened

**Tailscale doesn't connect/disconnect**:
- Run the PowerShell script manually to see output:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "C:\Path\To\tailscale.ps1"
  ```
- Verify your SSID is spelled exactly right in `$homeSSIDs` (case-sensitive)
- Check that the Tailscale CLI is in PATH: `tailscale status`

**Script shows execution errors**:
- Ensure PowerShell execution policy allows scripts:
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```
- Verify Tailscale is installed and the CLI is accessible from any PowerShell window

**"The task is configured for a different user" on import**:
- You didn't update `<UserId>` in the XML. Either fix it first (see Step 4) or let Task Scheduler prompt you for credentials during import.

---

## 📝 How to Modify

**Add more home networks**: Just add SSIDs to the `$homeSSIDs` array in `tailscale.ps1`

**Change trigger conditions**: Edit the task in Task Scheduler to use different events or schedules

**See script output while debugging**: In `tailscale-launcher.vbs`, change the `0` to `1` to show the PowerShell window during execution

---

## 📝 How It Works (Technical Details)

- **Task Scheduler Event Triggers**: Monitors `Microsoft-Windows-NetworkProfile/Operational` log for Event IDs 10000 (network connected) and 10002 (network disconnected)
- **Silent execution wrapper**: VBScript launches PowerShell with window mode `0` to prevent console flashing
- **Execution policy bypass**: PowerShell runs with `-ExecutionPolicy Bypass` flag to allow unsigned script execution
- **Ethernet detection**: Uses `Get-NetAdapter -Physical` filtered to `MediaType '802.3'` and `Status 'Up'`. The `-Physical` flag excludes virtual adapters (Tailscale's own, Hyper-V, VPN tunnels) so they don't falsely register as Ethernet.
- **SSID detection**: Uses `netsh wlan show interfaces` with regex pattern matching to extract the current Wi-Fi SSID (only consulted when no Ethernet is up)
- **Trust-state machine**: Each run derives a state (`home` / `away` / `none`) and compares it to the previous state stored in `last-state.txt` (written next to `tailscale.ps1`). Only `home↔away` transitions trigger Tailscale changes; `none` is never persisted, so a momentary Wi-Fi drop won't cause a reconnect cycle.
- **Manual override at home**: Because the script only reacts to transitions, running `tailscale up` yourself while at home is preserved — the resulting NetworkProfile event finds `home → home` and exits without touching Tailscale.
- **Force re-evaluation**: Delete `last-state.txt` to make the next run treat the current network as a fresh transition.
- **Elevated privileges**: Task runs with `HighestAvailable` privilege level (required for Tailscale CLI control)
- **No output logs**: Script writes to stdout but VBScript suppresses all output for clean operation
