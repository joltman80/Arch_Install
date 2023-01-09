# Fix PACMAN Encryption Keys

Update mirrors list

```console
sudo pacman-mirrors -c United States # or any other Country
sudo pacman-mirrors -f 5
```

Remove gnupg and re-init it

```console
sudo rm -rv /etc/pacman.d/gnupg
sudo pacman-key --init
```

Remove pacman cache

```console
sudo rm -Rf /var/cache/pacman/pkg/*
```

Create a temporary directory for package cache

```console
sudo mkdir -pv $HOME/.cache/pkg/
```

Download the newest keyring package which contains the GPG keys from Arch Linux Package site:

<https://archlinux.org/packages/core/any/archlinux-keyring/>

Install the package to the temporary pkg folder you created above
**Don't import keys here... so type "n" if asking.**

```console
sudo pacman -Syw archlinux-keyring --cachedir $HOME/.cache/pkg/
```

Remove the signatures

```console
sudo rm -f $HOME/.cache/pkg/*.sig
```

Install the packages in the temp folder.  This will install all the new/correct GPG keys.

```console
sudo pacman -U $HOME/.cache/pkg/*.tar.zst
```

Clear the pacman cache

```console
sudo pacman -Sc
```

Remove the downloaded GPG packages

```console
sudo rm -Rf $HOME/.cache/pkg/
```
