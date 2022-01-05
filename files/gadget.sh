#!/usr/bin/env bash
# Configure USB gadgets (run as root from /etc/rc.local)

### Create a sparse file for the mass storage gadget
MASS_STORAGE0="/home/pi/mass_storage.lun0"
if [[ ! -f "$MASS_STORAGE0" ]]; then
	# 8GB seems plenty?
    dd if=/dev/zero of="$MASS_STORAGE0" bs=1M seek=8192 count=0
    #echo <<EOFCAT | fdisk -u "$MASS_STORAGE0"
    #EOFCAT
    losetup -o 4096 /dev/loop0 "$MASS_STORAGE0"
    mkdosfs -v /dev/loop0 -S 4096 -g 64/8 -n ZERO2USB
    losetup -d /dev/loop0
fi

### Configuring USB gadgets via ConfigFS

#### Define our composite gadget parameters
GADGET_NAME="zero2"
MANUFACTURER="Raspberry"
PRODUCT="PiZero2 Composite Gadget"
SERIAL=$(awk -F": " '/^Serial/ {print $2}' /proc/cpuinfo)
HOST="48:6f:73:74:50:43" # "HostPC"
SELF0="42:61:64:55:53:42" # "USB0"
SELF1="42:61:64:55:53:43" # "USB1"
SCSI_INQUIRY="Zero2 Mass Storage"

# Dont touch these...
OS=$(cat /tmp/os.fingerprint)
CONFIGFS_HOME="/sys/kernel/config"
GADGET_DIR="$CONFIGFS_HOME"/usb_gadget/"$GADGET_NAME"
GADGET_LANG="0x409" # English language strings
ID_VENDOR="0x04b3" # IBM ?
ID_PRODUCT="0x4123" # Nonsense
BCD_USB="0x0200" # USB2
BCD_DEVICE="0x0100" # v1.0.0
B_DEVICECLASS="0x02"
B_DEVICESUBCLASS="0x00"
MAX_POWER=250

#### Create a composite gadget
mkdir -p "$GADGET_DIR" || exit 1
cd "$GADGET_DIR" || exit 1
echo "$BCD_USB" > bcdUSB
echo "$BCD_DEVICE" > bcdDevice
echo "$B_DEVICECLASS" > bDeviceClass
echo "$B_DEVICESUBCLASS" > bDeviceSubClass
echo "$ID_VENDOR" > idVendor
echo "$ID_PRODUCT" > idProduct
mkdir -p strings/"$GADGET_LANG"
echo "$SERIAL" > strings/"$GADGET_LANG"/serialnumber
echo "$MANUFACTURER" > strings/"$GADGET_LANG"/manufacturer
echo "$PRODUCT" > strings/"$GADGET_LANG"/product

#### --> Ethernet gadget
# If we're not connected to MacOS, configure an RNDIS-type adapter
if [[ "$OS" != "MacOS" ]]; then
    mkdir -p configs/c.1/strings/"$GADGET_LANG"
    echo "CDC ACM+MassStorage+RNDIS" > configs/c.1/strings/"$GADGET_LANG"/configuration
    echo "$MAX_POWER" > configs/c.1/MaxPower
    mkdir -p functions/rndis.usb0
    echo "$HOST" > functions/rndis.usb0/host_addr
    echo "$SELF0" > functions/rndis.usb0/dev_addr
    echo "RNDIS" > functions/rndis.usb0/os_desc/interface.rndis/compatible_id
    echo "5162001" > functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id
    echo "0x80" > configs/c.1/bmAttributes # Bus Powered
    echo "0xcd" > os_desc/b_vendor_code # Microsoft
    echo "MSFT100" > os_desc/qw_sign # Microsoft
    echo "1" > os_desc/use
fi
# We'll always also configure an ECM-type adapter
mkdir -p configs/c.2/strings/"$GADGET_LANG"
echo "CDC ACM+MassStorage+ECM" > configs/c.2/strings/"$GADGET_LANG"/configuration
echo "$MAX_POWER" > configs/c.2/MaxPower
mkdir -p functions/ecm.usb0
echo "$HOST" > functions/ecm.usb0/host_addr
echo "$SELF1" > functions/ecm.usb0/dev_addr

#### --> Serial gadget
mkdir -p functions/acm.usb0

#### --> Mass Storage gadget
mkdir -p functions/mass_storage.usb0
echo 0 > functions/mass_storage.usb0/stall
echo 0 > functions/mass_storage.usb0/lun.0/cdrom
echo 0 > functions/mass_storage.usb0/lun.0/ro
echo 0 > functions/mass_storage.usb0/lun.0/nofua
echo 1 > functions/mass_storage.usb0/lun.0/removable
echo "$SCSI_INQUIRY" > functions/mass_storage.usb0/lun.0/inquiry_string
echo "$MASS_STORAGE0" > functions/mass_storage.usb0/lun.0/file

## Initialise the config
if [[ "$OS" != "MacOS" ]]; then
    ln -s configs/c.1 os_desc
    ln -s functions/rndis.usb0 configs/c.1
fi
ln -s functions/ecm.usb0 configs/c.2
ln -s functions/acm.usb0 configs/c.2
ln -s functions/mass_storage.usb0 configs/c.2

udevadm settle -t 5 || true
echo "" > UDC
basename "$(find /sys/class/udc -type l)" > UDC
