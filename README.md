# Installing Arch Linux on a machine

## Arch ISO to USB Stick

Download the ArchInstall ISO from Arch Website.  Prep a USB stick of at least 4GB.  Verify there's no data on the stick.  Insert it into the computer so you can write the ISO file to the USB stick with the following commands.

```console
dd bs=4M if=archlinux-2022.09.03-x86_64.iso of=/dev/sdc conv=fsync oflag=direct status=progress
```

Once the ISO has been written to disk, insert the USB stick into the target machine and boot the machine.

## BIOS Settings

Boot the laptop and immediately start pressing the key combo Fn and F2.  Once in BIOS, under SECURITY, set "Enforce Secure Boot" to DISABLED.  Change the BOOT DEVICE ORDER to the USB stick first.  Also change the Intel Virtualization (Vt-d) to ENABLED.  Save the BIOS config and restart the machine.  The machine will boot from the Arch Install USB stick you have created.

## Partition the machine's hard disk

Find the proper hard disk by running:

```console
lsblk
```

Run cgdisk against the proper hard disk:

```console
cgdisk /dev/nvme0n1
```

Create a 512Mi EFI partition (type: ef00).  For the root, create a Linux partition, choose -32Gi for ending sectors as we want extra space for the filesystem to use incase of bad blocks.  Write changes

## Format the disk partitions

The EFI partition should be formated as FAT32.

```console
mkfs.fat -F 32 /dev/nvme0n1p1
```

Format the boot partition as EXT4.

```console
mkfs.ext4 /dev/nvme0n1p2       (boot partition)
```

## Create the encrypted root parition

Now we will create the root partition as an encrypted volume using the kernel native LUKS encryption.  Run the commands below to encrypt the partition.

```console
cryptsetup -y --use-random -v luksFormat /dev/nvme0n1p3
```

(-y asks for password twice, --use-random uses /dev/random to generate keys)

Type YES in caps
enter passphrase
enter passphrase again

Run the below command to verify no dm-crypt devices are mounted:

```console
ls /dev/mapper
```

Now run this command to open the encrypted partition:

```console
cryptsetup luksOpen /dev/nvme0n1p3 cryptroot
Enter passphrase
```

Now when you list the dev mapper directory, you shoudl see the cryptroot folder:

```console
ls /dev/mapper
```

The cryptroot partition must be formatted.  Format it using EXT4.  Then mount it at /mnt.

```console
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
```

## Creating the initial folder structure on cryptroot

You will now create the initial folder structure for the operating system.

```console
mkdir -p /mnt/{boot,home,swap}
mkdir /mnt/boot/EFI
mount /dev/nvme0n1p2 /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot/EFI
```

## Installing the initial Arch packages

```console
pacstrap /mnt linux linux-firmware base base-devel git vim nano grub efibootmgr intel-ucode os-prober linux-headers
```

## Generate the initial fstab with UUIDs

genfstab -U /mnt >> /mnt/etc/fstab

## CHROOT into the new Arch environment

```console
arch-chroot /mnt
```

## Create the SWAP file on the encrypted root

Make the swap file slightly larger than your RAM.

```console
fallocate -l 38GB /swap/swapfile
chmod 600 /swap/swapfile
mkswap /swap/swapfile
swapon /swap/swapfile
```

Edit FSTAB and add the following at the bottom and save:

```console
nano /etc/fstab

## Swap file config

/swap/swapfile  none    swap  sw 0 0
```

## Set the local time

```console
ln -sf /usr/share/zoneinfo/America/Denver /etc/localtime
hwclock --systohc
```

## Locale

Find my locale (en_US.UTF-8 UTF-8) in the following file and uncomment the line and save the file

```console
nano /etc/locale.gen
```

Generate the locales with following command:

```console
locale-gen
```

Setup the locale LANG with this new file and save it when done:

```console
touch /etc/locale.conf && echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

## Other configuration

Set the hostname by creating the file and echoing the name to file:

```console
touch /etc/hostname && echo "tardis" > /etc/hostname
```

Set the hosts file:

```console
nano /etc/hosts

127.0.0.1   localhost
::1         localhost
127.0.1.1   tardis.localdomain    tardis
```

Generate the root password:

```console
passwd
```

## Pacman configuration

Configure pacman for parallel downloads, the PacMan progress bar and colorization.  Search for Parallel, uncomment the line to allow 5 parallel downloads.

```console
nano /etc/pacman.conf
Color
ParallelDownloads = 5
ILoveCandy
```

Enable the MULTILIB repo by uncommenting the line.

```console
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Save and close the pacman.conf file.

## MKINITCPIO Configuration for LUKS partition

Now we make changes to the mkinitcpio.conf file to accommodate for the encrypted LUKS partition.

```console
nano /etc/mkinitcpio.conf
```

Scroll down to HOOKS and add "encrypt" directly after block and before filesystem, add resume before fsck.  It should look like this:

```console
HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard resume fsck)
```

Run the mkinitcpio command with the preset of "linux"

```console
mkinitcpio -p linux
```

## GRUB Configuration

Time to setup GRUB.  Grab the UUID of the LUKS partition, /dev/nvme0n1p3, by running:

```console
blkid
```

The UUID is:

```console
UUID=e1fb5806-1f0a-4edb-bbd4-855e2a6a4c2e
```

Edit the default grub config file

```console
nano /etc/default/grub
```

In the defualt grub config, find the GRUB_CMDLINE_LINUX and add (with quotes):

"cryptdevice=UUID=$UUIDHERE$:cryptroot:allow-discards root=/dev/mapper/cryptroot"

It should look like this:

```console
GRUB_CMDLINE_LINUX="cryptdevice=UUID=e1fb5806-1f0a-4edb-bbd4-855e2a6a4c2e:cryptroot
```

Replace the default grub line with this:

```console
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet mem_sleep_default=deep nvme.noacpi=1"
```

Change the grub resolution so that you can actually read the text on the screen:

```console
GRUB_GFXMODE=1024x768x32
```

Now we install the grub bootloader

```console
grub-install --target=x86_64-efi --efi-directory=/boot/EFI/ --bootloader-id=grub
```

Now make the grub config:

```console
grub-mkconfig -o /boot/grub/grub.cfg
```

## Creating Local Users and Wheel Permissions

Create the administrator (UID=1000) user and set their password:

```console
useradd -m -G wheel -s /bin/bash administrator
passwd administrator
```

Create your user (UID=1001).

```console
useradd -m -G wheel -s /bin/bash USER
passwd USER
```

Give wheel group sudoer power:

```console
nano /etc/sudoers
```

Find this line and uncomment:

```console
## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL:ALL) ALL
```

## Install the software environment

```console
pacman -S networkmanager network-manager-applet pipewire pipewire-alsa pipewire-jack pipewire-pulse gst-plugin-pipewire libpulse wireplumber firefox chromium ffmpeg openssl openssh htop wget iwd wireless_tools wpa_supplicant smartmontools xdg-utils fprintd xorg-server xorg-xinit mesa libva-mesa-driver libva-intel-driver intel-media-driver vulkan-intel gnome gnome-tweaks gdm gnome-software-packagekit-plugin gnome-firmware man-db man-pages bluez bluez-utils fuse htop iio-sensor-proxy intel-gpu-top mesa mesa-utils flatpak grub-customizer libva-utils mpv cifs-utils nfs-utils gvfs-smb seahorse gnome-connections vlc samba mkvtoolnix-gui mpv tlp ntfs-3g openvpn networkmanager-openvpn wireguard-tools hexchat wine winetricks wine-mono jre17-openjdk jdk17-openjdk icedtea-web syncthing cups cups-pdf signal-desktop gnome-sound-recorder gnome-disk-utility gparted digikam breeze-icons darktable yt-dlp picard mac cuetools pacman-contrib reflector firewalld inetutils wireshark p7zip libreoffice-fresh libreoffice-extension-texmaths libreoffice-extension-writer2latex ttf-caladea ttf-carlito ttf-dejavu ttf-liberation ttf-linux-libertine-g noto-fonts adobe-source-code-pro-fonts adobe-source-sans-fonts adobe-source-serif-fonts hunspell hunspell-en_us hyphen hyphen-en libmythes mythes-en dnsutils dconf-editor kicad gimp pdfarranger transmission-remote-gtk tesseract tesseract-data-eng
```

## Install KiCad's official libraries as dependencies

```console
sudo pacman -Syu --asdeps kicad-library kicad-library-3d
```

## Enable essential services

```console
systemctl enable gdm.service
systemctl enable NetworkManager.service
systemctl enable fstrim.timer
systemctl enable bluetooth.service
systemctl enable cups.service
systemctl enable paccache.timer
systemctl enable reflector.timer
systemctl enable firewalld.service
```

## Add User to Wireshark Group

```console
sudo usermod -aG wireshark USER
```

## Restart the system

After restarting, login as your USER

## Configure Gnome Hibernate Settings

Open Dconf-Editor and navigate to:

```console
org.gnome.settings-daemon.plugins.power
'''

Change this setting:

```console
sleep-inactive-battery-type hibernate
```

## Configure Samba File Sharing

Get the Samba config file and configure Samba for USER

```console
cd /home/USER
wget `https://git.samba.org/samba.git/?p=samba.git;a=blob_plain;f=examples/smb.conf.default;hb=HEAD

mv 'index.html?p=samba.git' smb.conf
sudo cp smb.conf /etc/samba/

sudo smbpasswd -a USER
sudo smbpasswd -e USER

sudo systemctl enable winbind.service
sudo systemctl start winbind.service
```

## Configure JAVA

Change Java Security by removing 3DES_EDE_CBC from jdk.tls.legacyAlgorithms= in the following file.  This enables older encryption for older IPMI/iDRAC servers.

```console
sudo nano /etc/java17-openjdk/security/java.security
```

## Configure SyncThing as USER

```console
systemctl enable syncthing.service --user
systemctl start syncthing.service --user
```

## Set makepkg.conf to utilize multiple threads for faster compile times

Run the following command to find out the number of threads you have available

```console
nproc
```

Edit the makepkg.conf file

```console
nano /etc/makepkg.conf
```

Look for the MAKEFLAGS line and change it to your desired number of threads.  Keep in mind you might want to keep several threads available so you can multitask.

```console
#-- Make Flags: change this for DistCC/SMP systems
MAKEFLAGS="-j12"
```

Save your changes using CTRL+x

## Configure the AUR Package Helper, YAY

```console
mkdir ~/Packages
cd Packages
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

## Install AUR packages

```console
yay -S 1password makemkv neo-matrix-git extension-manager ipmiview ttf-ms-win10 realvnc-vnc-viewer inxi vmware-vmrc visual-studio-code-bin skypeforlinux-stable-bin gnome-browser-connector IPMIviewer syncthing-gtk epson-inkjet-printer-201113w cnrdrvcups-lb sublime-text-4 flirc-bin superpaper-git webcamoid alac-git shntool teamviwer python37 python-yattag chirp-next mullvad-vpn libreoffice-extension-languagetool gnome-shell-extension-media-controls ocrmypdf
```

## Enable/Start Mullvad VPN Service

```console
sudo systemctl enable mullvad-daemon.service
sudo systemctl start mullvad-daemon.service
```

## Enable the teamviewerd service

```console
sudo systemctl enable teamviewerd.service
sudo systemctl start teamviewerd.service
```

## Configure Firefox for Wayland

This allows inertial scrolling in Firefox

```console
touch ~/.config/environment.d/envvars.conf && echo "MOZ_ENABLE_WAYLAND=1" ~/.config/environment.d/envvars.conf
```

## More Firefox Config

In Firefox address bar type and hit ENTER:

```console
about:config
```

Find this setting and disable for better scrolling:

```console
mousewheel.system_scroll_override.enabled
```

Enable video hardware offloading to iGPU by setting these to TRUE:

```console
media.ffmpeg.vaapi.enabled
media.navigator.mediadatadecoder_vpx_enabled
media.rdd-ffmpeg.enabled
```

## Enable DPI Fractional Scaling (restart after making the change)

```console
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
```

## CIFS Browsing on Local Network

AVAHI is better for browsing a local network for shares.  Disable systemd resolved before installing avahi and nss-mdns (for .local hostname resolution):

```console
sudo systemctl disable systemd-resolved.service
sudo pacman -Sy avahi nss-mdns
```

Enable and start the avahi service:

```console
sudo systemctl enable avahi-daemon.service
sudo systemctl start avahi-daemon.service
```

Then, edit the file /etc/nsswitch.conf and change the hosts line to include mdns_minimal [NOTFOUND=return] before resolve and dns:

```console
sudo nano /etc/nsswitch.conf

hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns
```

## Setup Virtualization

```console
sudo pacman -Sy qemu-base virt-manager libvirt edk2-ovmf dnsmasq
```

 The Arch Linux Virtualization Wiki Page:

<https://wiki.archlinux.org/title/Virt-Manager>

Enable and start the libvirt service:

```console
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service
```

Edit the libvirt.conf file:

```console
sudo nano /etc/libvirt/libvirtd.conf
```

Change this:

```console
...
unix_sock_group = 'libvirt'
...
unix_sock_rw_perms = '0770'
...
```

Add your user to the libvirt group:

```console
sudo usermod -a -G libvirt USER
```

Add your user to /etc/libvirt/qemu.conf. Otherwise, QEMU will give a permission denied error when trying to access local drives.  Search for user = "libvirt-qemu" or group = "libvirt-qemu", uncomment both entries and change libvirt-qemu to your user name or ID. Once edited it should look something like below:

```console
user = "USER"

# The group for QEMU processes run by the system instance. It can be
# specified in a similar way to user.
group = "USER"
```

Install the AUR VirtIO ISO Windows package into the /var/lib/libvirt/images folder

```console
yay -Sy virtio-win
```

Download the virtio Windows XP floppy image:

```console
cd Downloads
wget http://web.archive.org/web/20110501124422/http://alt.fedoraproject.org/pub/alt/virtio-win/latest/images/bin/virtio-win-1.1.16.vfd

sudo cp virtio-win-1.1.16.vfd /var/lib/libvirt/images
```

## Install Roon Bridge

```console
# This installs libasound required by Roon
sudo pacman -Sy alsa-lib
cd ~/Packages
wget https://download.roonlabs.net/builds/roonbridge-installer-linuxx64.sh
chmod +x roonbridge-installer-linuxx64.sh
sudo ./roonbridge-installer-linuxx64.sh
```

Now create a new firewalld service and rich rule to allow inbound traffic from Roon Server to the new RoonBridge on the HOME zone

```console

sudo firewall-cmd --permanent --new-service=RoonBridge
sudo firewall-cmd --permanent --service=RoonBridge --set-description=Inbound from RoonServer
sudo firewall-cmd --permanent --service=RoonBridge --set-short=SVC_IN_RoonBridge
sudo firewall-cmd --permanent --service=RoonBridge --add-port=9100-9200/tcp
sudo firewall-cmd --permanent --service=RoonBridge --add-port=9330-9332/tcp
sudo firewall-cmd --permanent --service=RoonBridge --add-port=9003/udp
sudo firewall-cmd --permanent --service=RoonBridge --add-port=1900/udp
sudo firewall-cmd --permanent --service=RoonBridge --add-protocol=igmp
sudo firewall-cmd --permanent --zone=home --add-rich-rule='   rule family="ipv4"   source address="10.0.10.110/32"   port protocol="tcp" accept'
sudo firewall-cmd --permanent --zone=home --add-service=RoonBridge
sudo firewall-cmd --reload
```

## Add USER to the 'uucp' group to access serial console (CHIRP-NEXT)

```console
sudo usermod -aG uucp USER
```

## Download HP 48 Emulation Software

[This is the link](https://www.hpcalc.org/hp48/pc/emulators/) for the HP Calc website.

This is the link for the Emu48 Windows software that will run in WINE.
