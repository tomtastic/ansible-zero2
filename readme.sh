## things to do for libcomposite gadgets

### Get some useful packages
sudo apt update
sudo apt install -y git bc bison flex libssl-dev libncurses-dev isc-dhcp-server dsniff tcpdump lsof screen nodejs bridge-utils libatlas-base-dev libopenjp2-7 libtiff5 patchelf python3-dbus ovmerge ifmetric libimagequant0 liblcms2-2 libwebpdemux2 libwebpmux3 mailcap mime-support python3-numpy python3-olefile python3-pil iptables
sudo systemctl disable isc-dhcp-server

### Drop some config files
sudo cp files/usb0.conf /etc/network/interfaces.d/usb0
sudo cp files/lo.conf /etc/network/interfaces.d/lo
sudo cp files/dhcpd.conf /etc/dhcp/
sudo cp files/isc-dhcp-server /etc/default/
sudo cp files/rc.local /etc/
sudo cp files/usb_fingerprint.sh /home/pi/
sudo cp files/gadget.sh /home/pi/
sudo cp files/dummy_gadget.conf /etc/modprobe.d/
sudo cp files/rpi-pirate-audio.service /lib/systemd/system/
sudo ln -s /lib/systemd/system/rpi-pirate-audio.service /etc/systemd/system/poweroff.target.wants/
sudo systemctl enable rpi-pirate-audio.service
printf "dwc2\n#libcomposite\ng_serial\n" | sudo tee -a /etc/modules
printf "dtoverlay=dwc2\n" | sudo tee -a /boot/config.txt
printf "dtoverlay=hifiberry-dac\n" | sudo tee -a /boot/config.txt
printf "\ndenyinterfaces usb*\n" | sudo tee -a /etc/dhcpcd.conf

### Patch the dwc2 kernel module so we print host request fingerprints
# Get the right kernel source for our current kernel...
cd ~
sudo wget https://raw.githubusercontent.com/bstalk/rpi-source/feature/experimental_python3/rpi-source -O /usr/bin/rpi-source && sudo chmod +x /usr/bin/rpi-source && /usr/bin/rpi-source -q --tag-update
rpi-source
# Apply the printk patch...
cd ~/linux/drivers/usb/dwc2
patch -i ~/ansible-zero2/files/gadget_fingerprint_5.10.63-v7+.patch
cd ~/linux

# Apply the rate patch...?
#cd ~/linux/drivers/usb/gadget/function || exit 1
#patch -i ~/files/gadget_rate_5.10.63-v7+.patch
#cd ~/linux || exit 1

# Compile and install extra gadget modules...
make M=drivers/usb/dwc2 CONFIG_USB_DWC2=m
make M=drivers/usb/gadget/function
sudo cp -p ~/linux/drivers/usb/dwc2/dwc2.ko /lib/modules/"$(uname -r)"/kernel/drivers/usb/dwc2/dwc2.ko
sudo cp -p ~/linux/drivers/usb/gadget/function/usb_f_ecm.ko /lib/modules/"$(uname -r)"/kernel/drivers/usb/gadget/function/
sudo cp -p ~/linux/drivers/usb/gadget/function/usb_f_ncm.ko /lib/modules/"$(uname -r)"/kernel/drivers/usb/gadget/function/
sudo cp -p ~/linux/drivers/usb/gadget/function/usb_f_rndis.ko /lib/modules/"$(uname -r)"/kernel/drivers/usb/gadget/function/

