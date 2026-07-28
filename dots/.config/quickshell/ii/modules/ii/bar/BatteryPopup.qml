import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar.weather

StyledPopup {
    id: root

    readonly property bool warning: Battery.isLow && !Battery.isCharging

    function formatTime(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? `${h}h, ${m}m` : `${m}m`;
    }

    Item {
        anchors.centerIn: parent
        implicitWidth: gridLayout.implicitWidth + 8
        implicitHeight: columnLayout.implicitHeight + 8

        ColumnLayout {
            id: columnLayout
            anchors.centerIn: parent
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                ColumnLayout {
                    Layout.alignment: Qt.AlignLeft
                    spacing: 0

                    StyledText {
                        text: Translation.tr("Battery")
                        font {
                            weight: Font.Bold
                            pixelSize: Appearance.font.pixelSize.small
                        }
                        color: Appearance.colors.colOnSurface
                    }

                    StyledText {
                        text: Battery.chargeState == 4 ? Translation.tr("Fully charged") : Battery.isCharging ? Translation.tr("Charging") : Translation.tr("Discharging")
                        font {
                            weight: Font.Normal
                            pixelSize: Appearance.font.pixelSize.smaller
                        }
                        color: Appearance.colors.colOutline
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    StyledText {
                        text: `${Math.round(Battery.percentage * 100)}%`
                        font {
                            weight: Font.SemiBold
                            pixelSize: Appearance.font.pixelSize.small * 2
                        }
                        color: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSurface
                    }

                    MaterialSymbol {
                        text: Battery.isCharging ? "battery_charging_full" : root.warning ? "battery_alert" : "battery_android_full"
                        fill: 0
                        font.weight: Font.Normal
                        iconSize: Appearance.font.pixelSize.small * 2
                        color: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSurface
                    }
                }
            }

            // Stat tiles: vertical list, full width
            ColumnLayout {
                id: gridLayout
                Layout.fillWidth: true
                spacing: 8

                WeatherCard {
                    visible: {
                        const timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                        return !(Battery.chargeState == 4 || timeValue <= 0 || Battery.energyRate <= 0.01);
                    }
                    title: Battery.isCharging ? Translation.tr("Time to full") : Translation.tr("Time to empty")
                    symbol: "schedule"
                    value: root.formatTime(Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty)
                }
                WeatherCard {
                    visible: !(Battery.chargeState != 4 && Battery.energyRate == 0)
                    title: Battery.isCharging ? Translation.tr("Charging") : Translation.tr("Discharging")
                    symbol: "bolt"
                    value: Battery.chargeState == 4 ? "--" : `${Battery.energyRate.toFixed(2)}W`
                }
                WeatherCard {
                    title: Translation.tr("Health")
                    symbol: "heart_check"
                    value: `${Battery.health.toFixed(1)}%`
                }
            }
        }
    }
}
