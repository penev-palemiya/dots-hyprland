import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool hasBattery: Battery.available && batteryDevice !== null
    readonly property bool hasHealth: root.hasBattery && batteryDevice.healthSupported
    readonly property var supportedProfiles: {
        const profiles = [
            { label: Translation.tr("Power Saver"), value: PowerProfile.PowerSaver },
            { label: Translation.tr("Balanced"), value: PowerProfile.Balanced }
        ];
        if (PowerProfiles.hasPerformanceProfile)
            profiles.push({ label: Translation.tr("Performance"), value: PowerProfile.Performance });
        return profiles;
    }

    function batteryStatus() {
        if (!root.hasBattery)
            return Translation.tr("No battery detected");
        switch (Battery.chargeState) {
        case UPowerDeviceState.Charging: return Translation.tr("Charging");
        case UPowerDeviceState.Discharging: return Translation.tr("Discharging");
        case UPowerDeviceState.FullyCharged: return Translation.tr("Fully charged");
        case UPowerDeviceState.PendingCharge: return Translation.tr("Charging soon");
        case UPowerDeviceState.PendingDischarge: return Translation.tr("Discharging soon");
        case UPowerDeviceState.Empty: return Translation.tr("Empty");
        default: return Translation.tr("Battery state unavailable");
        }
    }

    function timeText() {
        if (!root.hasBattery)
            return "";
        const seconds = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
        if (!Number.isFinite(seconds) || seconds <= 0 || Battery.energyRate <= 0.01)
            return "";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (hours > 0)
            return Translation.tr("About %1 h %2 min remaining").arg(hours).arg(minutes);
        return Translation.tr("About %1 min remaining").arg(minutes);
    }

    function powerConnectionText() {
        if (!root.hasBattery)
            return "";
        if (!UPower.onBattery)
            return Translation.tr("Plugged in");
        return "";
    }

    SettingsGroup {
        title: Translation.tr("Battery")

        SettingsRow {
            icon: root.hasBattery ? (Battery.isCharging ? "battery_charging_full" : "battery_android_full") : "battery_unknown"
            title: root.hasBattery ? `${Math.round(Battery.percentage * 100)}%` : Translation.tr("No battery detected")
            description: root.batteryStatus()

            ColumnLayout {
                width: 250
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    visible: root.timeText().length > 0
                    text: root.timeText()
                    color: Appearance.colors.colOnSurfaceVariant
                    horizontalAlignment: Text.AlignRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.powerConnectionText().length > 0
                    text: root.powerConnectionText()
                    color: Appearance.colors.colOnSurfaceVariant
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Power Mode")

        SettingsRow {
            icon: "bolt"
            title: Translation.tr("Power profile")
            description: Translation.tr("Changes apply immediately.")

            StyledComboBox {
                width: 250
                textRole: "label"
                model: root.supportedProfiles
                currentIndex: root.supportedProfiles.findIndex(profile => profile.value === PowerProfiles.profile)
                enabled: root.supportedProfiles.length > 0
                onActivated: index => {
                    const profile = root.supportedProfiles[index];
                    if (profile)
                        PowerProfiles.profile = profile.value;
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Battery Health")
        visible: root.hasHealth

        SettingsRow {
            icon: "heart_check"
            title: Translation.tr("Battery health")
            description: Translation.tr("Remaining capacity compared with the original design capacity.")

            StyledText {
                text: `${Battery.health.toFixed(1)}%`
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Low Battery")
        visible: root.hasBattery

        SettingsRow {
            icon: "warning"
            title: Translation.tr("Low warning")
            description: Translation.tr("Battery percentage at which the first warning appears.")
            keywords: "battery percent"

            StyledSpinBox {
                value: Config.options.battery.low
                from: Config.options.battery.critical
                to: 100
                stepSize: 5
                onValueChanged: Config.options.battery.low = value
            }
        }

        SettingsRow {
            icon: "dangerous"
            title: Translation.tr("Critical warning")
            description: Translation.tr("Battery percentage at which an urgent warning appears.")
            keywords: "battery percent"

            StyledSpinBox {
                value: Config.options.battery.critical
                from: Config.options.battery.suspend
                to: Config.options.battery.low
                stepSize: 5
                onValueChanged: Config.options.battery.critical = value
            }
        }

        SettingsRow {
            icon: "charger"
            title: Translation.tr("Full warning")
            description: Translation.tr("Tells you when the battery reaches this level, so you can unplug.")
            keywords: "battery percent charge"

            StyledSpinBox {
                value: Config.options.battery.full
                from: Config.options.battery.low
                to: 101
                stepSize: 5
                onValueChanged: Config.options.battery.full = value
            }
        }

        SettingsToggleRow {
            icon: "pause"
            title: Translation.tr("Automatic suspend")
            description: Translation.tr("Suspends the system on its own once the battery gets critically low.")
            keywords: "sleep power"
            checked: Config.options.battery.automaticSuspend
            onToggled: checked => Config.options.battery.automaticSuspend = checked
        }

        SettingsSubRow {
            title: Translation.tr("Suspend at")
            description: Translation.tr("Battery percentage that triggers the automatic suspend.")
            enabled: Config.options.battery.automaticSuspend

            StyledSpinBox {
                value: Config.options.battery.suspend
                from: 0
                to: Config.options.battery.critical
                stepSize: 5
                onValueChanged: Config.options.battery.suspend = value
            }
        }

        SettingsToggleRow {
            icon: "notifications_active"
            title: Translation.tr("Battery sounds")
            description: Translation.tr("Play sounds for low, critical, plugged-in, and full battery events.")
            checked: Config.options.sounds.battery
            onToggled: checked => Config.options.sounds.battery = checked
        }
    }
}
