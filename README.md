# plsr-hiveos
Pulsar Coin ("PLSR") transaction node installer for HiveOS

## Purpose
This simple script is meant to be run in a HiveOS shell and its purpose is to automatically install the Pulsar Coin daemon, *pulsard*, as a service. Required daemon Linux dependencies are automatically installed and the latest blocks and chainstate bootstrap available from the [official Pulsar Coin github](https://github.com/Pulsar-Coin/Pulsar-Coin-Cryptocurrency/releases) is downloaded and installed to bring the daemon into syncronization as soon as possible.

## Preparation
1. Use a provisioning computer to [download a HiveOS image](https://download.hiveos.farm/).
2. Use either [Rufus](https://rufus.ie/en/) or [Etcher](https://etcher.balena.io/#download-etcher) to burn the image to the NVMe drive that will be placed in the HiveOS machine.
3. Remember to create the `rig.conf` file on this NVMe drive using `rig-config-example.txt` as a template.
4. Remember to go into the bios of the HiveOS machine and configure the computer to "Power On" after a power loss.
5. Where possible, use an ethernet connection to the HiveOS machine. If ethernet is not available, then use a plugin-in wifi expander that has an ethernet output. Personally, I have been using the TP-Link AC750 WiFi Range Extender (RE220) with a power strip that has surge protection.
6. If placing the HiveOS machine at a friend's or family's house (remote location), use a smart plug so that you can remote power cycle the HiveOS machine.
7. You will need to ensure that either: a.) the modem-router forwards port **5995** to the HiveOS installation on the local network; and/or b.) UPnP is active in the router's ettings.

## Security
While possible, it is not recommended that users hold a balance on these installations. Building on this, it is not recommended to enable Proof-of-Stake ("PoS") on *pulsard* through HiveOS.
