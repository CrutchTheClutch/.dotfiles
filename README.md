# .dotfiles

My personal dotfiles for macOS

## install

Run this command to install my dotfiles. Downloads and runs the `init.sh` script in this repo which kicks off the dotfiles setup.  This currently only supports macOS, will potentially add linux support in the future.

```shell
curl -L https://dotfiles.wrc.dev | zsh
```

# TODO

List of things I need to configure and automate for simple dev env setup (in no particular order)

- [x] Git
- [x] Homebrew
- [x] Rosetta2
- [x] macOS defaults (system preferences) Maybe more to explore here?
- [x] Ghostty
- [x] Neovim
- [x] Raycast
- [ ] yabai?
- [ ] skhd?
- [ ] Actual .dotfiles symlinking
- [ ] UTM (full disk access)
- [ ] CrystalFetch
- [ ] QEMU-aarch64 (full disk access)
- [ ] Map Downloads to iCloud? (see below)

## Map Downloads to iCloud

```shell
crutchtheclutch@Williams-M3-MBP Downloads % ln -s ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/Downloads ~/Downloads
crutchtheclutch@Williams-M3-MBP Downloads % ls -la ~/Downloads
total 16
drwx------@  5 crutchtheclutch  staff   160 Mar 28 11:25 .
drwxr-x---+ 51 crutchtheclutch  staff  1632 Mar 28 11:19 ..
-rw-r--r--@  1 crutchtheclutch  staff  6148 Mar 28 11:24 .DS_Store
-rw-r--r--   1 crutchtheclutch  staff     0 Nov 22  2023 .localized
lrwxr-xr-x@  1 crutchtheclutch  staff    77 Mar 28 11:25 Downloads -> /Users/crutchtheclutch/Library/Mobile Documents/com~apple~CloudDocs/Downloads
crutchtheclutch@Williams-M3-MBP Downloads % mv ~/Downloads ~/Downloads_old

mv: rename /Users/crutchtheclutch/Downloads to /Users/crutchtheclutch/Downloads_old: Permission denied
crutchtheclutch@Williams-M3-MBP Downloads % sudo mv ~/Downloads ~/Downloads_old
Password:
crutchtheclutch@Williams-M3-MBP Downloads % ln -s ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/Downloads ~/Downloads
```