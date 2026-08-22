import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 28

    signal openSubPage(string key)

    function wallpaperName(path) {
        if (!path || path.length === 0)
            return Translation.tr("No wallpaper selected");
        const slash = path.lastIndexOf("/");
        return slash >= 0 ? path.slice(slash + 1) : path;
    }

    function openWallpaperPicker() {
        Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"]);
    }

    SettingsGroup {
        title: Translation.tr("Wallpaper")

        Rectangle {
            id: hero
            Layout.fillWidth: true
            implicitHeight: Math.min(340, Math.max(190, width * 9 / 16))
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerHighest
            clip: true

            Image {
                id: wallpaperImage
                anchors.fill: parent
                source: Config.options.background.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                visible: wallpaperImage.status !== Image.Ready
                color: Appearance.colors.colSurfaceContainerHighest

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "wallpaper"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Wallpaper preview unavailable")
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: 68
                color: Appearance.colors.colScrim
                opacity: 0.86

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            Layout.fillWidth: true
                            text: root.wallpaperName(Config.options.background.wallpaperPath)
                            color: "#ffffff"
                            elide: Text.ElideMiddle
                            font.weight: Font.Medium
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Desktop background")
                            color: "#e5e5e5"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }

                    RippleButtonWithIcon {
                        materialIcon: "wallpaper"
                        mainText: Translation.tr("Change")
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colBackgroundToggled: Appearance.colors.colPrimary
                        colBackgroundToggledHover: Appearance.colors.colPrimaryActive
                        onClicked: root.openWallpaperPicker()
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Personalization")

        SettingsNavRow {
            icon: "contrast"
            title: Translation.tr("Appearance")
            description: Translation.tr("Theme and shell appearance")
            onClicked: root.openSubPage("personalization-appearance")
        }
        SettingsNavRow {
            icon: "colors"
            title: Translation.tr("Colors")
            description: Translation.tr("Accent and Material palette")
            onClicked: root.openSubPage("personalization-colors")
        }
        SettingsNavRow {
            icon: "font_download"
            title: Translation.tr("Fonts")
            description: Translation.tr("Interface typography")
            onClicked: root.openSubPage("personalization-fonts")
        }
        SettingsNavRow {
            icon: "lock"
            title: Translation.tr("Lock Screen")
            description: Translation.tr("Lock screen appearance")
            onClicked: root.openSubPage("personalization-lock-screen")
        }
        SettingsNavRow {
            icon: "animation"
            title: Translation.tr("Effects & Animations")
            description: Translation.tr("Transparency, blur and motion")
            onClicked: root.openSubPage("personalization-effects-animations")
        }
    }
}
