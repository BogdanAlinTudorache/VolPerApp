# VolPerApp 🔊

VolPerApp is a lightweight, native macOS menu bar application written purely in Swift. It lives entirely in your Mac's status bar (with no dock icon!) and gives you full control over system volume, per-app volume levels, and audio device switching — all from a single click.

## Features

* **System Volume Slider** — Control your Mac's output volume with a live percentage readout.
* **Mute Toggle** — Instantly mute and unmute output with a single click on the speaker icon.
* **Input Volume Control** — Separate slider and mute toggle for your microphone / line-in.
* **Output Device Switcher** — All connected output devices listed with one-tap selection and a live checkmark on the active device.
* **Input Device Switcher** — Same for input devices — switch between built-in mic, external mic, and USB interfaces instantly.
* **Per-App Volume Mixer** — Dedicated mixer view lists every running GUI application with its own volume slider (0–100%).
* **Persistent App Volumes** — Each app's volume level is remembered across sessions and restored automatically.
* **Running Apps Snapshot** — Main view shows a quick glance at the top 5 running apps and their current volume.
* **CoreAudio Low-Level Accuracy** — Volume reads and writes use `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` directly for true hardware control.
* **Theme Support** — System, Light, or Dark mode.
* **No Xcode Required** — Builds entirely from the terminal using a custom shell script.

## Requirements

* macOS 13.0 (Ventura) or later
* Swift 5.7+ (included with Xcode Command Line Tools)

## Preview

![VolPerApp preview](preview.png)

### App mixer view

![VolPerApp mixer](mixer.png)

## Installation & Setup

You can build and run VolPerApp directly from your terminal without opening Xcode.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/BogdanAlinTudorache/VolPerApp.git
   cd VolPerApp
   ```

2. **Make the build script executable (first time only):**
   ```bash
   chmod +x build.sh
   ```

3. **Build the app:**
   ```bash
   ./build.sh
   ```

4. **Run it directly:**
   ```bash
   open build/VolPerApp.app
   ```

5. **(Optional) Install to your Applications folder:**
   ```bash
   cp -r build/VolPerApp.app /Applications/
   ```

## Customization

Click the **speaker icon** in your menu bar to open the volume panel. Tap the **slider icon** (top right) to open the App Mixer, or tap the **gear icon** for Settings.

* **Show input volume** — toggle the microphone section on / off
* **Show running apps** — toggle the quick-glance app list on / off
* **Theme** — System / Light / Dark

> **Tip:** Per-app volume levels are stored in `~/Library/Application Support/VolPerApp/app_volumes.json` — you can inspect or reset them manually if needed.
