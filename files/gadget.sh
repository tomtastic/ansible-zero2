#!/usr/bin/env bash
# Configure USB gadgets (run as root from /etc/rc.local)

### Configuring USB gadgets via ConfigFS
# NB:
#
# 1) We only have one available UDC (USB Device Controller), so all gadgets
#    have to be held within configurations under a single UDC.
# 2) Windows composite gadgets must have just one configuration

#### Define our composite gadget parameters
GADGET_NAME="zero2"
MANUFACTURER="Raspberry"
PRODUCT="PiZero2 Gadget"
HOST="48:6f:73:74:50:43" # "HostPC"
SELF0="42:61:64:55:53:42" # "USB0"
SELF1="42:61:64:55:53:43" # "USB1"
MASS_STORAGE0="/home/pi/mass_storage.lun0"
SCSI_INQUIRY="Zero2 Mass Storage"

### Create a sparse file for the mass storage gadget
if [[ ! -f "$MASS_STORAGE0" ]]; then
    # 8GB seems plenty?
    dd if=/dev/zero of="$MASS_STORAGE0" bs=1M seek=8192 count=0
    #echo <<EOFCAT | fdisk -u "$MASS_STORAGE0"
    #EOFCAT
    losetup -o 4096 /dev/loop0 "$MASS_STORAGE0"
    mkdosfs -v /dev/loop0 -S 4096 -g 64/8 -n ZERO2USB
    losetup -d /dev/loop0
fi

# Dont touch these...
COMMAND="$1" # 'start' or 'stop'
OS=$(cat /tmp/os.fingerprint)
CONFIGFS_HOME="/sys/kernel/config"
GADGET="$CONFIGFS_HOME"/usb_gadget/"$GADGET_NAME"
GADGET_LANG="0x409" # English language strings
BCD_USB="0x0200" # USB2
BCD_DEVICE="0x0100" # version number ?
B_DEVICECLASS="0xEF" # For Windows compatible identifier of 'USB\COMPOSITE'
B_DEVICESUBCLASS="0x02" # For Windows compatible identifier of 'USB\COMPOSITE'
B_DEVICEPROTOCOL="0x01" # For Windows compatible identifier of 'USB\COMPOSITE'
ID_VENDOR="0x1d6b" # Linux Foundation
ID_PRODUCT="0x0104" # Multifunction Composite Gadget
SERIAL=$(awk -F": " '/^Serial/ {print $2}' /proc/cpuinfo)
MAX_POWER=250

#### Create a composite gadget
mkdir -p "$GADGET" || exit 1
echo "$BCD_USB" > "$GADGET"/bcdUSB
echo "$BCD_DEVICE" > "$GADGET"/bcdDevice
echo "$B_DEVICECLASS" > "$GADGET"/bDeviceClass
echo "$B_DEVICESUBCLASS" > "$GADGET"/bDeviceSubClass
echo "$B_DEVICEPROTOCOL" > "$GADGET"/bDeviceProtocol
echo "$ID_VENDOR" > "$GADGET"/idVendor
echo "$ID_PRODUCT" > "$GADGET"/idProduct
mkdir -p "$GADGET"/strings/"$GADGET_LANG" || exit 1
echo "$SERIAL" > "$GADGET"/strings/"$GADGET_LANG"/serialnumber
echo "$MANUFACTURER" > "$GADGET"/strings/"$GADGET_LANG"/manufacturer
echo "$PRODUCT" > "$GADGET"/strings/"$GADGET_LANG"/product


function RNDIS_CONFIG_START () {
    #### CONFIG - RNDIS, ACM, STORAGE ####
    mkdir -p "$GADGET"/configs/c.1/strings/"$GADGET_LANG" || exit 1
    echo "CDC RNDIS and CDC ACM and MASS_STORAGE" > "$GADGET"/configs/c.1/strings/"$GADGET_LANG"/configuration
    #### --> Ethernet gadget
    mkdir -p "$GADGET"/functions/rndis.usb0 || exit 1
    echo "$HOST" > "$GADGET"/functions/rndis.usb0/host_addr
    echo "$SELF0" > "$GADGET"/functions/rndis.usb0/dev_addr
    echo "RNDIS" > "$GADGET"/functions/rndis.usb0/os_desc/interface.rndis/compatible_id
    echo "5162001" > "$GADGET"/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id
    echo "0x80" > "$GADGET"/configs/c.1/bmAttributes # Bus Powered
    echo "0xcd" > "$GADGET"/os_desc/b_vendor_code # Microsoft
    echo "MSFT100" > "$GADGET"/os_desc/qw_sign # Microsoft
    echo "1" > "$GADGET"/os_desc/use

    #### --> Serial gadget
    mkdir -p "$GADGET"/functions/acm.usb0 || exit 1

    #### --> Mass Storage gadget
    mkdir -p "$GADGET"/functions/mass_storage.usb0 || exit 1
    echo 1 > "$GADGET"/functions/mass_storage.usb0/stall
    echo 0 > "$GADGET"/functions/mass_storage.usb0/lun.0/cdrom
    echo 0 > "$GADGET"/functions/mass_storage.usb0/lun.0/ro
    echo 0 > "$GADGET"/functions/mass_storage.usb0/lun.0/nofua
    echo 1 > "$GADGET"/functions/mass_storage.usb0/lun.0/removable
    echo "$SCSI_INQUIRY" > "$GADGET"/functions/mass_storage.usb0/lun.0/inquiry_string
    echo "$MASS_STORAGE0" > "$GADGET"/functions/mass_storage.usb0/lun.0/file

    ## Initialise the config
    echo "$MAX_POWER" > "$GADGET"/configs/c.1/MaxPower
    ln -s "$GADGET"/functions/rndis.usb0 "$GADGET"/configs/c.1
    ln -s "$GADGET"/functions/acm.usb0 "$GADGET"/configs/c.1
    ln -s "$GADGET"/functions/mass_storage.usb0 "$GADGET"/configs/c.1
    ln -s "$GADGET"/configs/c.1 "$GADGET"/os_desc

    basename "$(find /sys/class/udc -type l)" > "$GADGET"/UDC
    udevadm settle -t 5 || true
}


function NCM_CONFIG_START () {
    #### CONFIG - NCM, ACM, STORAGE ####
    mkdir -p "$GADGET"/configs/c.1/strings/"$GADGET_LANG" || exit 1
    echo "CDC NCM and CDC ACM and MASS_STORAGE" > "$GADGET"/configs/c.1/strings/"$GADGET_LANG"/configuration
    #### --> Ethernet gadget
    mkdir -p "$GADGET"/functions/ncm.usb0 || exit 1
    echo "$HOST" > "$GADGET"/functions/ncm.usb0/host_addr
    echo "$SELF1" > "$GADGET"/functions/ncm.usb0/dev_addr

    #### --> Serial gadget
    mkdir -p "$GADGET"/functions/acm.usb0 || exit 1

    #### --> Mass Storage gadget
    mkdir -p "$GADGET"/functions/mass_storage.usb0 || exit 1
    echo 1 > "$GADGET"/functions/mass_storage.usb0/stall
    echo 0 > "$GADGET"/functions/mass_storage.usb0/lun.0/cdrom
    echo 0 > "$GADGET"/functions/mass_storage.usb0/lun.0/ro
    echo 0 > "$GADGET"/functions/mass_storage.usb0/lun.0/nofua
    echo 1 > "$GADGET"/functions/mass_storage.usb0/lun.0/removable
    echo "$SCSI_INQUIRY" > "$GADGET"/functions/mass_storage.usb0/lun.0/inquiry_string
    echo "$MASS_STORAGE0" > "$GADGET"/functions/mass_storage.usb0/lun.0/file

    ## Initialise the config
    echo "$MAX_POWER" > "$GADGET"/configs/c.1/MaxPower
    ln -s "$GADGET"/functions/ncm.usb0 "$GADGET"/configs/c.1
    ln -s "$GADGET"/functions/acm.usb0 "$GADGET"/configs/c.1
    ln -s "$GADGET"/functions/mass_storage.usb0 "$GADGET"/configs/c.1
    ln -s "$GADGET"/configs/c.1 "$GADGET"/os_desc

    basename "$(find /sys/class/udc -type l)" > "$GADGET"/UDC
    udevadm settle -t 5 || true
}

function CONFIG_STOP () {
    # Takes "rndis" or "ncm" as argument
    FUNC="$1"
    if [[ "$(cat "$GADGET"/UDC)" != "" ]]; then
        echo "" > "$GADGET"/UDC
    fi
    # Remove in reverse order...
    rm -f "$GADGET"/os_desc/c.1
    rm -f "$GADGET"/configs/c.1/mass_storage.usb0
    rm -f "$GADGET"/configs/c.1/acm.usb0
    rm -f "$GADGET"/configs/c.1/"$FUNC".usb0
    rmdir "$GADGET"/functions/mass_storage.usb0 2>/dev/null
    rmdir "$GADGET"/functions/acm.usb0 2>/dev/null
    rmdir "$GADGET"/functions/"$FUNC".usb0 2>/dev/null
    rmdir "$GADGET"/configs/c.1/strings/"$GADGET_LANG" 2>/dev/null
    rmdir "$GADGET"/configs/c.1 2>/dev/null
    rmdir "$GADGET"/strings/"$GADGET_LANG" 2>/dev/null
    rmdir "$GADGET" 2>/dev/null
}

function gadget_start () {
    if [[ "$OS" == "MacOS" ]]; then
        echo "[+] Enabling MacOS composite gadget in $GADGET"
        NCM_CONFIG_START
    else
        echo "[+] Enabling Linux/Win composite gadget in $GADGET"
        RNDIS_CONFIG_START
    fi

    # Enable Serial
    echo "[+] Starting getty service"
    systemctl start getty@ttyGS0.service || true
}

function gadget_stop () {
    echo "[+] Stopping getty service"
    systemctl stop getty@ttyGS0.service || true

    if [[ "$OS" == "MacOS" ]]; then
        echo "[+] Disabling MacOS gadget..."
        CONFIG_STOP ncm
    else
        echo "[+] Disabling Windows/Linux gadget..."
        CONFIG_STOP rndis
    fi
}

case "${COMMAND}" in
    start)
        gadget_start
        exit 0;;
    stop)
        gadget_stop
        exit 0;;
    *)
        echo "Usage: $0 start|stop"
        exit 1;;
esac

