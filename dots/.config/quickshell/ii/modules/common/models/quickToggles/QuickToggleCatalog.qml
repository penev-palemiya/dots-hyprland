pragma Singleton

import QtQuick
import qs.services
import qs.modules.common

QtObject {
    readonly property list<var> entries: [
        { type: "network", labelKey: "Internet", icon: "wifi" },
        { type: "bluetooth", labelKey: "Bluetooth", icon: "bluetooth" },
        { type: "audio", labelKey: "Audio output", icon: "volume_up" },
        { type: "easyEffects", labelKey: "EasyEffects", icon: "graphic_eq" },
        { type: "cloudflareWarp", labelKey: "Cloudflare WARP", icon: "cloud_lock" },
        { type: "nightLight", labelKey: "Night Light", icon: "night_sight_auto" },
        { type: "darkMode", labelKey: "Dark Mode", icon: "contrast" },
        { type: "gameMode", labelKey: "Game mode", icon: "gamepad" },
        { type: "idleInhibitor", labelKey: "Keep awake", icon: "coffee" },
        { type: "screenSnip", labelKey: "Screen snip", icon: "screenshot_region" },
        { type: "colorPicker", labelKey: "Color picker", icon: "colorize" },
        { type: "onScreenKeyboard", labelKey: "Virtual Keyboard", icon: "keyboard" },
        { type: "mic", labelKey: "Audio input", icon: "mic" },
        { type: "notifications", labelKey: "Notifications", icon: "notifications" },
        { type: "powerProfile", labelKey: "Power Profile", icon: "energy_savings_leaf" },
        { type: "musicRecognition", labelKey: "Identify Music", icon: "music_note" },
        { type: "antiFlashbang", labelKey: "Anti-flashbang", icon: "flash_on" }
    ]

    readonly property list<string> ids: entries.map(entry => entry.type)

    function entry(type) {
        return entries.find(item => item.type === type) || null;
    }

    function isAvailable(type) {
        switch (type) {
        case "bluetooth": return BluetoothStatus.available;
        case "easyEffects": return EasyEffects.available;
        default: return true;
        }
    }
}
