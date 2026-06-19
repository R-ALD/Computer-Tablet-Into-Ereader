#Install needed tools
apt install --no-install-recommends network-manager rfkill -y
systemctl enable --now NetworkManager


#Create the wifiswitch command
cat >/usr/local/bin/wifiswitch <<'EOF'
#!/bin/sh
set -eu

MARKER="/etc/koreader-wifi-disabled"

# If run as reader, re-run through sudo.
if [ "$(id -u)" -ne 0 ]; then
    exec sudo /usr/local/bin/wifiswitch "$@"
fi

NMCLI="$(command -v nmcli || true)"
RFKILL="$(command -v rfkill || true)"

wifi_off() {
    touch "$MARKER"

    if [ -n "$NMCLI" ]; then
        "$NMCLI" radio wifi off || true
    fi

    if [ -n "$RFKILL" ]; then
        "$RFKILL" block wifi || true
    fi

    echo "Wi-Fi is OFF now and will stay blocked at boot."
}

wifi_on() {
    rm -f "$MARKER"

    if [ -n "$RFKILL" ]; then
        "$RFKILL" unblock wifi || true
    fi

    if [ -n "$NMCLI" ]; then
        "$NMCLI" networking on || true
        "$NMCLI" radio wifi on || true
        "$NMCLI" device wifi rescan >/dev/null 2>&1 || true
    fi

    echo "Wi-Fi is ON now and allowed at boot."
}

wifi_apply_boot() {
    if [ -f "$MARKER" ]; then
        if [ -n "$NMCLI" ]; then
            "$NMCLI" radio wifi off || true
        fi
        if [ -n "$RFKILL" ]; then
            "$RFKILL" block wifi || true
        fi
    else
        if [ -n "$RFKILL" ]; then
            "$RFKILL" unblock wifi || true
        fi
        if [ -n "$NMCLI" ]; then
            "$NMCLI" networking on || true
            "$NMCLI" radio wifi on || true
        fi
    fi
}

wifi_status() {
    echo
    echo "Wi-Fi boot preference:"
    if [ -f "$MARKER" ]; then
        echo "  blocked at boot"
    else
        echo "  allowed at boot"
    fi

    echo
    echo "NetworkManager radio:"
    if [ -n "$NMCLI" ]; then
        "$NMCLI" radio wifi || true
        echo
        "$NMCLI" device status || true
        echo
        "$NMCLI" connection show --active || true
    else
        echo "  nmcli not found"
    fi

    echo
    echo "rfkill:"
    if [ -n "$RFKILL" ]; then
        "$RFKILL" list wifi || "$RFKILL" list || true
    else
        echo "  rfkill not found"
    fi
}

case "${1:-menu}" in
    on|enable|allow)
        wifi_on
        ;;
    off|disable|block)
        wifi_off
        ;;
    status)
        wifi_status
        ;;
    apply-boot)
        wifi_apply_boot
        ;;
    menu)
        echo
        echo "Wi-Fi switch"
        echo
        echo "1) Turn Wi-Fi ON and allow it at boot"
        echo "2) Turn Wi-Fi OFF and block it at boot"
        echo "3) Show Wi-Fi status"
        echo
        printf "Choose 1, 2, or 3: "
        read -r choice

        case "$choice" in
            1) wifi_on ;;
            2) wifi_off ;;
            3) wifi_status ;;
            *) echo "Invalid choice."; exit 1 ;;
        esac
        ;;
    *)
        echo "Usage: wifiswitch [on|off|status]"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/wifiswitch

#Create boot enforcement service
#This makes the choice survive reboot.

cat >/etc/systemd/system/koreader-wifi-boot.service <<'EOF'
[Unit]
Description=Apply KOReader kiosk Wi-Fi boot preference
After=NetworkManager.service systemd-rfkill.service
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wifiswitch apply-boot

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable koreader-wifi-boot.service

#Allow KOReader’s reader user to run it
cat >/etc/sudoers.d/koreader-wifiswitch <<'EOF'
reader ALL=(root) NOPASSWD: /usr/local/bin/wifiswitch
EOF

chmod 440 /etc/sudoers.d/koreader-wifiswitch

rm wifiSwitchInstaller.sh