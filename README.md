## Make your tablet PC into an Ereader using KOReader
Here's how to repurpose an old tablet PC into an Ereader

#### What you'll need:
- Docking station compatible with your tablet PC
- USB-drive to download Debian 13 iso on
- Computer
- USB keyboard
#### Estimated time (Varies by transfer speed, I used relatively slow hardware)
- Creating a bootable USB-drive etc ~30 min
- Download Debian 13 terminal only ~30min-1h
- Download KOReader etc ~5 min (Depending on internet speed)

### 0. If your device's UEFI firmware is 32-bit (As my DELL venue 8 pro's was)
After creating a bootable USB-drive (prefferably using **rufus**):
- Download the `bootia32.efi` from this repository. Or look up how to create on on your own (Not too difficult).
- Put the `bootia32.efi` file into the boot drive's EFI folder:
```bash
/EFI/BOOT/
```
Then your boot drive should be ready to go.

### 1. Download Debian 13 terminal only

Create a user called `remoteuser` (Even if you won't be using SSH)
The password should be easy to remember.

At software selection check only these two:
- ✅ SSH server (Optional but recommended)
- ✅ standard system utilities

(Using SSH you can just paste in the following commands from your computer instead of typing them in manually)

### 2. Make tablet run KOReader at startup
Once the device boots up:
- Log in as `root`.
- Run this command.
```bash
wget -O downloader.sh "https://raw.githubusercontent.com/R-ALD/Tablet-PC-Into-An-Ereader/refs/heads/main/downloader.sh" && bash downloader.sh
```
Once the device has rebooted, on its own, it should boot into KOReader straight away.

If you want to go back to terminal press `Ctrl + Alt + F2`

#### 2.0 Change screen settings
I recommend doing this while being in `KOReader` on your tablet and using ssh from your computer, to see the changes live.

#### 2.1 Screen brightness
To change brightness use this command:
```bash
echo INSERT_BRIGHTNESS_HERE > /sys/class/backlight/intel_backlight/brightness
```

Replace `INSERT_BRIGHTNESS_HERE` with a value in the range 1-100.

#### 2.2 Night mode
To run night mode, run the command:
```bash
nightmode
```
Clear instructions on how to proceed will be displayed.

### 3 (Optional) Create a Wi-Fi switch so it won't run in the background

To create the switch run this command as root:

```bash
wget -O wifiSwitchInstaller.sh "https://raw.githubusercontent.com/R-ALD/Tablet-PC-Into-An-Ereader/refs/heads/main/wifiSwitchInstaller.sh" && bash wifiSwitchInstaller.sh
```

To use it run:
```bash
wifiswitch
```
Clear instructions on how to proceed will be displayed.
