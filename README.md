# Kanata Configuration
A kanata configuration file set for awesome keyboard rebindings!

## Installation

Run the provided install script — it handles everything interactively:

```bash
bash install.sh
```

The script will:
1. Fetch the latest kanata release from GitHub.
2. Check whether the binary is installed (in `~/.local/bin/kanata` or `$PATH`) and offer to download or upgrade it.
3. Detect any existing system or user service and, if none is found, prompt you to set one up.

### Manual installation

If you prefer to do it yourself:

Download the kanata binary:
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
