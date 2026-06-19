apt update

apt install sudo -y

adduser --disabled-password --gecos "" reader

usermod -aG sudo remoteuser
usermod -aG sudo reader

sudo apt install --no-install-recommends \
  ca-certificates wget dbus-user-session \
  xserver-xorg xinit xinput x11-xserver-utils \
  libinput-tools iio-sensor-proxy \
  fonts-dejavu-core fonts-noto-core -y

cd /tmp

wget https://github.com/koreader/koreader/releases/download/v2026.03/koreader_2026.03-1_amd64.deb

#echo "3a106ede88fd22a3662b99e00a45efb9c550ab9689a2139b80436d8dd0dc41c1  #koreader_2026.03-1_amd64.deb" | sha256sum -c -

sudo apt install ./koreader_2026.03-1_amd64.deb -y

command -v koreader

%EMULATE_READER_W=1200 EMULATE_READER_H=1920 EMULATE_READER_DPI=280 \
%startx /usr/bin/koreader -- :1 -nolisten tcp

passwd -l reader
mkdir -p /home/reader/Books
chown -R reader:reader /home/reader
usermod -aG video,input,render reader

# Sd card
mkdir -p /home/reader/Books/sdBooks
chown -R reader:reader /home/reader/Books
cp /etc/fstab /etc/fstab.bak

apt install --no-install-recommends exfatprogs dosfstools ntfs-3g -y
cat >> /etc/fstab <<'EOF'
/dev/mmcblk1 /home/reader/Books/sdBooks auto ro,nofail,x-systemd.automount,x-systemd.device-timeout=5s,x-systemd.idle-timeout=60 0 0
EOF

apt install --no-install-recommends unclutter redshift -y


sudo tee /usr/local/bin/koreader-kiosk >/dev/null <<'EOF'
#!/bin/sh

# Keep screen awake while reading.
xset -dpms
xset s off
xset s noblank

# Auto-detect current X screen size.
SCREEN_SIZE="$(xrandr | sed -nE 's/^Screen 0:.* current ([0-9]+) x ([0-9]+),.*/\1x\2/p')"

SCREEN_W="${SCREEN_SIZE%x*}"
SCREEN_H="${SCREEN_SIZE#*x}"

export EMULATE_READER_W="$SCREEN_W"
export EMULATE_READER_H="$SCREEN_H"
export EMULATE_READER_DPI=280

unclutter -idle 1 -root &

exec /usr/bin/koreader /home/reader/Books
EOF

sudo chmod +x /usr/local/bin/koreader-kiosk

sudo tee /home/reader/.bash_profile >/dev/null <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx /usr/local/bin/koreader-kiosk -- -keeptty -nolisten tcp vt1
fi
EOF

sudo chown reader:reader /home/reader/.bash_profile

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin reader --noclear %I $TERM
EOF

sudo systemctl daemon-reload
sudo systemctl set-default multi-user.target

systemctl disable --now bluetooth.service 2>/dev/null || true
systemctl mask bluetooth.service

cat >/etc/modprobe.d/disable-bluetooth.conf <<'EOF'
# Disable Bluetooth permanently
blacklist btusb
blacklist bluetooth
blacklist btrtl
blacklist btintel
blacklist btbcm

install btusb /bin/false
install bluetooth /bin/false
EOF

update-initramfs -u

# Night mode: "nightmode" in terminal as user reader to change intensity
cat >/usr/local/bin/nightmode <<'EOF'
#!/bin/sh

MIN_K=1000
MAX_K=6500
NORMAL_K=6500

# Use the KOReader/Xorg display.
# Most startx kiosk setups use :0.
if [ -z "$DISPLAY" ]; then
    DISPLAY=":0"
fi

# Use reader's X authority file if available.
if [ -z "$XAUTHORITY" ] && [ -f "$HOME/.Xauthority" ]; then
    XAUTHORITY="$HOME/.Xauthority"
fi

export DISPLAY
export XAUTHORITY

echo
echo "Night mode / blue-light filter"
echo
echo "Choose color temperature in Kelvin."
echo
echo "  $MIN_K  = strongest warm/red"
echo "  2500    = very warm"
echo "  3000    = strong warm"
echo "  4500    = mild warm"
echo "  $NORMAL_K  = normal daylight / off-ish"
echo
echo "Type:"
echo "  off     = reset/disable night mode"
echo "  normal  = set to $NORMAL_K K"
echo
printf "Choose K between $MIN_K and $MAX_K, or type off: "
read -r K

case "$K" in
    off|OFF|Off)
        if redshift -m randr -x; then
            echo "Night mode disabled."
        else
            echo "Failed to disable night mode. Is KOReader/Xorg running?"
            exit 1
        fi
        exit 0
        ;;
    normal|NORMAL|Normal)
        K="$NORMAL_K"
        ;;
esac

case "$K" in
    ''|*[!0-9]*)
        echo "Invalid input. Enter a number between $MIN_K and $MAX_K, or type off."
        exit 1
        ;;
esac

if [ "$K" -lt "$MIN_K" ] || [ "$K" -gt "$MAX_K" ]; then
    echo "Invalid value. Choose between $MIN_K and $MAX_K."
    exit 1
fi

if redshift -m randr -P -O "$K"; then
    echo "Night mode set to ${K}K."
else
    echo
    echo "Failed to set night mode."
    echo "DISPLAY=$DISPLAY"
    echo "XAUTHORITY=$XAUTHORITY"
    echo
    echo "Make sure KOReader/Xorg is currently running."
    exit 1
fi
EOF

chmod +x /usr/local/bin/nightmode

rm downloader.sh

sudo reboot
