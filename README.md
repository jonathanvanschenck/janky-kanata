# Kanata Configuration
A kanata configuration file set for awesome keyboard rebindings!

## Installation
Make sure that your user account has the right permissions:
```bash
sudo groupadd uinput
sudo usermod -aG input $USER
sudo usermod -aG uinput $USER
```
Then reboot your system.

If you run into any errors, you can check out the [following page](https://github.com/jtroo/kanata/wiki/Avoid-using-sudo-on-Linux) to set up the required udev rules.

Next you need to download the kanata binary:
```bash
VERSION=1.7.0
URL="https://github.com/jtroo/kanata/releases/download/v$VERSION/kanata_cmd_allowed"

curl -o ~/.local/bin/kanata $URL
chmod +x ~/.local/bin/kanata
```

Then edit `kanata.service.template` into `kanata.service` and link it with systemctl:
```bash
ln -s kanata.service ~/.config/systemd/user/kanata.service
systemctl --user enable kanata.service
systemctl --user start kanata.service
```

Then you should be good to go!
