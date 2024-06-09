# plsr-hiveos
Pulsar Coin ("PLSR") transaction node installer for HiveOS

## Purpose
1. These simple scripts are meant to be run in a HiveOS shell; their purpose supports Pulsar Coin in a HiveOS environment. 
2. Raise awareness to boost [Investment Mining of Pulsar](https://github.com/Pulsar-Coin/Pulsar-Coin-Cryptocurrency/wiki/03-PLSR-Acquisition#-investment-mining).

`install-pulsar.sh` -- install destination of files will be in **/.pulsar** drectory; remember to chmod +x this file.
<br>automatically install the Pulsar Coin daemon, *pulsard*, as a service. HiveOS updates upon initialization; required Linux dependencies for pulsard daemon are automatically installed ;the latest blocks and chainstate bootstrap available from the [official Pulsar Coin github](https://github.com/Pulsar-Coin/Pulsar-Coin-Cryptocurrency/releases) is downloaded and installed to bring the daemon into syncronization as soon as possible. 

`cloudflare-ddns.sh` -- it's okay to place and execute this script in the **/.pulsar** directory; remember to chmod +x this file.
<br>will reboot HiveOS on first run. creates a file (previous_ip.txt) listing the IP address of the rig and will subsequently grab external IP and compare the current IP with previous IP; will reboot rig on IP change, which will restart the Pulsar Relay node. Cloudflare integration optional. Cloudflare is good for using DNS to keep track of IP changes across a fleet of rigs placed in the homes of friends and family members.

`cloudflare-service-installer.sh` -- put in same directory as cloudflare-ddns.sh; remember to chmod +x this file.
<br>creates programming and files necessary to run cloudflare-ddns.sh as a service; default config is to auto-check for an IP change once per hour.

## Preparation
1. Use a provisioning computer to [download a HiveOS image](https://download.hiveos.farm/).
2. Use either [Rufus](https://rufus.ie/en/) or [Etcher](https://etcher.balena.io/#download-etcher) to burn the image to the NVMe drive that will be placed in the HiveOS machine.
3. Remember to create the `rig.conf` file on this NVMe drive using `rig-config-example.txt` as a template.
4. Remember to go into the bios of the HiveOS machine and configure the computer to "Power On" after a power loss.
5. Where possible, use an ethernet connection to the HiveOS machine. If ethernet is not available, then use a plugin-in wifi expander that has an ethernet output. Personally, I have been using the TP-Link AC750 WiFi Range Extender (RE220) with a power strip that has surge protection.
6. If placing the HiveOS machine at a friend's or family's house (remote location), use a smart plug so that you can remote power cycle the HiveOS machine.
7. You will need to ensure that either: a.) the modem-router forwards port **5995** to the HiveOS installation on the local network; and/or b.) UPnP is active in the router's ettings.
8. After downloading the script, you will need to **chmod +x** the script in order to run it.

## Security
While possible, it is not recommended that users hold a balance on these installations. Building on this, it is not recommended to enable Proof-of-Stake ("PoS") on *pulsard* through HiveOS.
