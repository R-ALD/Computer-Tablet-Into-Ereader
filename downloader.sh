apt update

apt install sudo -y

adduser --disabled-password --gecos "" remoteuser
printf 'remoteuser: \n' | chpasswd

usermod -aG sudo remoteuser
usermod -aG sudo reader

sudo apt install --no-install-recommends \
  ca-certificates wget dbus-user-session \
  xserver-xorg xinit xinput x11-xserver-utils \
  libinput-tools iio-sensor-proxy \
  fonts-dejavu-core fonts-noto-core -y

cd /tmp

wget https://github.com/koreader/koreader/releases/download/v2026.03/koreader_2026.03-1_amd64.deb

echo "3a106ede88fd22a3662b99e00a45efb9c550ab9689a2139b80436d8dd0dc41c1  koreader_2026.03-1_amd64.deb" | sha256sum -c -

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

# Dell Venue 8 Pro 5855 portrait-ish layout.
export EMULATE_READER_W=1200 
export EMULATE_READER_H=1920 
export EMULATE_READER_DPI=280 

unclutter -idle 3 -root &

# Blue-light filter / warm screen.
redshift -O 1000 &

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

sudo reboot
