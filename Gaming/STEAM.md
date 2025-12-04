# Steam Configuration for Arch Linux

This document will outline the steps needed to install Steam on an Arch Linux machine.

## Enable Multilib Repository in pacman

From [this link](https://wiki.archlinux.org/title/Official_repositories#multilib) edit the ```/etc/pacman.conf``` file and enable ```multilib``` by uncommenting both of these lines:

```console
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Run a system update ```sudo pacman -Su```.

## Initial Install

Run the following commands to install Steam and its dependencies:

```console
sudo pacman -Sy steam ttf-liberation lib32-systemd
```

NOTE:  You might get a prompt asking which ```lib32-vulkan``` drivers you should install.  Choose the drivers appropriate for your system.

I got several errors when starting Steam the first time.  I just closed and kept restarting and eventually the client started and I could log in.

## Install MangoHUD

MangoHUD displays valuable CPU/GPU information in an overlay on top of a game.  To install, run the following commands:

```console
sudo pacman -Sy mangohud lib32-mangohud vulkan-tools goverlay
```

Use ```goverlay``` to make changes to ```mangohud```.

## Config Changes

The Arch Wiki recommends changes to ```vm.max_map_count```.  Create a new file for Arch to process on startup.

```console
sudo nano /etc/sysctl.d/80-gamecompatibility.conf
```

Add this content and save and close the file.

```console
vm.max_map_count = 2147483642
```

## Install GameMode

GameMod will create optimizations for the CPU/CPU when running a game.  Install the packages:

```console
sudo pacman -Sy gamemode lib32-gamemode
```

The user running Steam will need permissions to run gamemode.  Add the user to the newly created group:

```console
sudo usermod -aG gamemode user
```

Now, create a configuration file for gamemode.  Create the folder and then the file:

```console
sudo mkdir -p /usr/share/gamemode
sudo nano /usr/share/gamemode/gamemode.ini
```

Paste the contents of the ```gamemode.ini``` from FeralInteractive's [Github](https://github.com/FeralInteractive/gamemode/blob/master/example/gamemode.ini) page.

Next we have to enable the ```gamemoded``` service as a user.

```console
systemctl --user enable --now gamemode
```
