# Quick Reference

One-page guide for using the setup scripts.

## 🚀 Usage

### Arch Linux
```bash
cd MY_OWN_REPO-s
chmod +x scripts/arch_setup.sh
./scripts/arch_setup.sh
```

### Ubuntu with Snap (Recommended)
```bash
cd MY_OWN_REPO-s
chmod +x scripts/ubuntu_setup_snap.sh
./scripts/ubuntu_setup_snap.sh
```

### Ubuntu with Flatpak
```bash
cd MY_OWN_REPO-s
chmod +x scripts/ubuntu_setup_flatpak.sh
./scripts/ubuntu_setup_flatpak.sh
```

## 📦 What's Installed

- **Editors**: vim, nano, VS Code
- **Browsers**: Brave (stable + nightly)
- **Media**: VLC
- **Tools**: git, curl, tldr, ncdu, gparted, calibre
- **Apps**: Discord, Notion, Notion Calendar
- **Dev**: Python 3, pip

## ⚙️ Pre-configured

- Git username: `a49ty1m`
- Git email: `a4920251m@gmail.com`
- Git editor: VS Code

**⚠️ Change these if you're not a49ty1m!**

## 📂 Repository Structure

```
.
├── scripts/
│   ├── arch_setup.sh              # For Arch Linux
│   ├── ubuntu_setup_snap.sh       # For Ubuntu (Snap)
│   └── ubuntu_setup_flatpak.sh    # For Ubuntu (Flatpak)
├── docs/
│   ├── COMPARISON.md              # Compare scripts
│   └── CUSTOMIZATION.md           # Customize scripts
├── .gitignore
└── README.md
```

## 🔍 Which Script Should I Use?

| If you have... | Use this script |
|----------------|-----------------|
| Arch Linux | `arch_setup.sh` |
| Ubuntu (any version) | `ubuntu_setup_snap.sh` |
| Want Flatpak instead | `ubuntu_setup_flatpak.sh` |

## 📚 Documentation

- **README.md** - Full documentation
- **docs/COMPARISON.md** - Detailed script comparison
- **docs/CUSTOMIZATION.md** - How to customize scripts

## 🛠️ Common Customizations

### Change Git Settings

Edit your chosen script, find:
```bash
git config --global user.name "a49ty1m"
git config --global user.email "a4920251m@gmail.com"
```

Change to your details:
```bash
git config --global user.name "YourUsername"
git config --global user.email "your@email.com"
```

### Add Packages

**Arch:**
```bash
# Official packages
sudo pacman -S --noconfirm --needed package-name

# AUR packages
yay -S --noconfirm package-name
```

**Ubuntu:**
```bash
# APT packages
sudo apt-get install -y package-name

# Snap packages
sudo snap install package-name

# Flatpak packages
flatpak install flathub app.id.Name
```

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Permission denied | Run `chmod +x scripts/script-name.sh` |
| Script interrupted (Ubuntu Snap) | Just run it again - it resumes! |
| Package not found | Update package lists first |
| Check logs (Ubuntu Snap) | `cat ~/ubuntu-setup.log` |

## 💡 Tips

1. **Test in VM first** if modifying scripts
2. **Backup important data** before running
3. **Check internet connection** before starting
4. **Restart after setup** for best results

## 📞 Support

For detailed help, see:
- [README.md](../README.md) - Main documentation
- [COMPARISON.md](COMPARISON.md) - Script comparison
- [CUSTOMIZATION.md](CUSTOMIZATION.md) - Customization guide
