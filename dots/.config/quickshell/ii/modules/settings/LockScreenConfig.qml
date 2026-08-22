import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    readonly property string wallpaperPath: Config.options.background.wallpaperPath
    readonly property string lockClockStyle: Config.options.background.widgets.clock.styleLocked
    readonly property bool lockDateVisible: lockClockStyle === "digital"
        ? Config.options.background.widgets.clock.digital.showDate
        : Config.options.background.widgets.clock.cookie.dateStyle !== "hide"
    readonly property bool blurEnabled: Config.options.lock.blur.enable

    function setDateVisible(enabled) {
        if (root.lockClockStyle === "digital") {
            Config.options.background.widgets.clock.digital.showDate = enabled;
        } else {
            // Cookie clocks already own their date presentation. Reuse that
            // state rather than introducing a second lock-only date flag.
            Config.options.background.widgets.clock.cookie.dateStyle = enabled ? "bubble" : "hide";
        }
    }

    SettingsGroup {
        title: Translation.tr("Preview")

        SettingsRow {
            icon: "lock"
            title: Translation.tr("Lock screen")
            description: Translation.tr("Visual preview only; it will not lock or authenticate the session.")
            minimumHeight: 300

            Item {
                implicitWidth: 500
                implicitHeight: 280

                Rectangle {
                    id: preview
                    anchors.fill: parent
                    radius: 18
                    color: Appearance.colors.colLayer0
                    clip: true

                    Image {
                        id: wallpaper
                        anchors.fill: parent
                        visible: !blurLoader.active
                        source: root.wallpaperPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        opacity: status === Image.Ready ? 1 : 0
                    }

                    Loader {
                        id: blurLoader
                        anchors.fill: parent
                        active: root.blurEnabled && wallpaper.status === Image.Ready
                        sourceComponent: GaussianBlur {
                            source: wallpaper
                            radius: Config.options.lock.blur.radius / 4
                            samples: radius * 2 + 1
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Appearance.colors.colLayer0
                        opacity: root.blurEnabled ? 0.30 : 0.12
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Loader {
                            anchors.horizontalCenter: parent.horizontalCenter
                            active: root.lockClockStyle === "cookie"
                            sourceComponent: Rectangle {
                                width: 112
                                height: 112
                                radius: 56
                                color: Appearance.colors.colPrimaryContainer
                                border.color: Appearance.colors.colPrimary
                                border.width: 2

                                StyledText {
                                    anchors.centerIn: parent
                                    text: DateTime.time
                                    color: Appearance.colors.colOnPrimaryContainer
                                    font.pixelSize: 22
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        StyledText {
                            visible: root.lockClockStyle === "digital"
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: DateTime.time
                            color: Appearance.colors.colOnSurface
                            font.pixelSize: 38
                            font.weight: Font.Medium
                        }

                        StyledText {
                            visible: root.lockDateVisible
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: DateTime.longDate
                            color: Appearance.colors.colOnSurface
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }

                        StyledText {
                            visible: Config.options.lock.showUserName
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: SystemInfo.username
                            color: Appearance.colors.colOnSurface
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Background")

        SettingsRow {
            icon: "wallpaper"
            title: Translation.tr("Background")
            description: Translation.tr("Always follows the desktop wallpaper")

            StyledText {
                text: Translation.tr("Desktop wallpaper")
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        SettingsToggleRow {
            icon: "blur_on"
            title: Translation.tr("Blur background")
            description: Translation.tr("Soften the wallpaper behind the lock screen")
            checked: Config.options.lock.blur.enable
            onToggled: checked => Config.options.lock.blur.enable = checked
        }
    }

    SettingsGroup {
        title: Translation.tr("Clock")

        SettingsToggleRow {
            icon: "calendar_month"
            title: Translation.tr("Show date")
            description: Translation.tr("Use the shared system date and locale formatting")
            checked: root.lockDateVisible
            onToggled: checked => root.setDateVisible(checked)
        }

        SettingsRow {
            icon: "schedule"
            title: Translation.tr("Clock style")
            description: Translation.tr("Style used when the session is locked")

            StyledComboBox {
                textRole: "displayName"
                model: [
                    { displayName: Translation.tr("Digital"), value: "digital" },
                    { displayName: Translation.tr("Cookie"), value: "cookie" }
                ]
                currentIndex: model.findIndex(item => item.value === root.lockClockStyle)
                onActivated: index => Config.options.background.widgets.clock.styleLocked = model[index].value
            }
        }

        SettingsToggleRow {
            icon: "center_focus_weak"
            title: Translation.tr("Center clock")
            description: Translation.tr("Keep the lock-screen clock centered")
            checked: Config.options.lock.centerClock
            onToggled: checked => Config.options.lock.centerClock = checked
        }
    }

    SettingsGroup {
        title: Translation.tr("Profile")

        SettingsToggleRow {
            icon: "account_circle"
            title: Translation.tr("Show user name")
            description: Translation.tr("Show the current account name on the lock screen")
            checked: Config.options.lock.showUserName
            onToggled: checked => Config.options.lock.showUserName = checked
        }
    }
}
