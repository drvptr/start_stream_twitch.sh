# FreeBSD Twitch Streaming Script (No OBS, No PulseAudio)

This is a simple yet powerful shell script to stream your desktop **on FreeBSD** using only:

- `ffmpeg`
- `virtual_oss`
- `x11grab`
- **No OBS**
- **No PulseAudio**
- **No JACK**
- **No GUI bullshit**

---

## Why?

Because:
- OBS on FreeBSD is often broken or hard to build.
- The PulseAudio + OBS combo can mess with your system's audio stack.
- We like **minimalism** and **control**.

This script provides an alternative way to stream **what you see and hear**, using clean CLI tools and native OSS.

---

## Requirements

Make sure you have the following installed:

- `ffmpeg` (built with `--enable-oss`)
- `virtual_oss`
- `xorg` running
- Your user has access to `/dev/dsp*` (typically via the `operator` group)

---

## Setup Instructions

### 0.1. Enable `virtual_oss` at boot

Edit `/etc/rc.conf`:

```sh
virtual_oss_enable="YES"
#virtual_oss_flags="-Q 0 -C 2 -c 2 -r 48000 -b 16 -s 1024 -P /dev/dsp0.1 -R /dev/null -d vdsp -l dsp"
You can adjust /dev/dspX.Y as needed for your system (see device detection below).
```
Start the service:
```sh
service virtual_oss start
```
### 0.2. Disable conflicting audio servers
```sh
Edit
pkill sndiod
pkill pulseaudio
```

### 1.1 Clone the repo
```sh
git clone https://github.com/yourname/freebsd-twitch-streamer.git
cd freebsd-twitch-streamer
chmod +x stream.sh
```
### 1.2. Set your Twitch stream key
```sh
./stream.sh --set-default-key YOUR_TWITCH_KEY
This embeds the key into the script itself
```
### 1.3. Start streaming
```sh
./stream.sh
```
### 2.1.  Options
```sh
./stream.sh [OPTIONS] [TWITCH_STREAM_KEY]
Options:

--set-default-key <key> — Save the key into the script (self-modifying).

--skip-oss-setup — Skip virtual_oss setup (if it's already running).

--help, -h — Show usage help.

Examples
Stream with embedded key:

./stream.sh
Stream with a new key (overrides embedded key temporarily):

./stream.sh zzzz9999xxxx8888
Skip OSS setup (e.g. if already running):

./stream.sh --skip-oss-setup
Both skip setup and provide key manually:

./stream.sh --skip-oss-setup xyz789zzz000
```
### 2.2. How It Works
The script:
Kills any existing virtual_oss instances, then detects your mic and system playback devices from /dev/sndstat, then tarts a new virtual_oss that mixes them into /dev/vdsp, then launches ffmpeg. Screen is captured by x11grab

### 2.3. Troubleshooting
No sound / no devices: Check cat /dev/sndstat and adjust device IDs accordingly.
Script fails on su: Re-run it and ensure correct root password.
Permission denied: Ensure your user is in the operator group, or run as root.

### 3. Why This Exists
"I got tired of OBS randomly breaking my FreeBSD install and PulseAudio being a parasite. So I wrote this script that uses only ffmpeg, OSS, and good old Unix principles."

This project is for minimalists, tinkerers, and FreeBSD loyalists who want to stream without the overhead.


