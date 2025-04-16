# Kanata Configuration
A kanata configuration file set for awesome keyboard rebindings!

## Installation
Ya know... Just install it for root, it'll make your life better.

Next you need to download the kanata binary:
```bash
VERSION=1.8.1
URL="https://github.com/jtroo/kanata/releases/download/v$VERSION/kanata_cmd_allowed"

curl -o ~/.local/bin/kanata $URL
chmod +x ~/.local/bin/kanata
```

Then edit `kanata.service.template` into `kanata.service` and link it with systemctl:
```bash
sudo ln -s kanata.service /etc/systemd/system/kanata.service
sudo systemctl enable kanata.service
sudo systemctl start kanata.service
```

Then you should be good to go!
