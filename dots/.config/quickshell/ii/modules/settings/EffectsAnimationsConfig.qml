import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    readonly property bool transparencyEnabled: Config.options.appearance.transparency.enable
    readonly property bool automatic: Config.options.appearance.transparency.automatic
    property real backgroundDraft: Config.options.appearance.transparency.backgroundTransparency
    property real contentDraft: Config.options.appearance.transparency.contentTransparency

    readonly property real previewBackground: root.transparencyEnabled
        ? (root.automatic ? Appearance.effectiveBackgroundTransparency : root.backgroundDraft)
        : 0
    readonly property real previewContent: root.automatic
        ? Appearance.effectiveContentTransparency
        : root.contentDraft

    function commitBackground() {
        const value = Math.max(0, Math.min(1, root.backgroundDraft));
        root.backgroundDraft = value;
        Config.options.appearance.transparency.backgroundTransparency = value;
    }

    function commitContent() {
        const value = Math.max(0, Math.min(1, root.contentDraft));
        root.contentDraft = value;
        Config.options.appearance.transparency.contentTransparency = value;
    }

    SettingsGroup {
        title: Translation.tr("Transparency")

        SettingsRow {
            icon: "opacity"
            title: Translation.tr("Behavior")
            description: root.automatic
                ? Translation.tr("Adjusts shell transparency to the current wallpaper and color scheme.")
                : Translation.tr("Use the saved background and content transparency values.")

            Row {
                spacing: 0

                SelectionGroupButton {
                    buttonText: Translation.tr("Automatic")
                    leftmost: true
                    rightmost: false
                    toggled: root.automatic
                    enabled: root.transparencyEnabled
                    onClicked: Config.options.appearance.transparency.automatic = true
                }
                SelectionGroupButton {
                    buttonText: Translation.tr("Custom")
                    leftmost: false
                    rightmost: true
                    toggled: !root.automatic
                    enabled: root.transparencyEnabled
                    onClicked: Config.options.appearance.transparency.automatic = false
                }
            }
        }

        SettingsRow {
            visible: !root.transparencyEnabled
            icon: "info"
            title: Translation.tr("Transparency is turned off")
            description: Translation.tr("Enable transparency in Personalization → Appearance to use these controls.")
            registerInSearch: false
        }

        SettingsRow {
            visible: root.transparencyEnabled && !root.automatic
            icon: "wallpaper"
            title: Translation.tr("Background")
            description: Translation.tr("How much of the wallpaper shows through shell backgrounds")

            RowLayout {
                spacing: 10

                StyledSlider {
                    id: backgroundSlider
                    Layout.preferredWidth: 240
                    configuration: StyledSlider.Configuration.S
                    from: 0
                    to: 1
                    value: root.backgroundDraft
                    usePercentTooltip: true
                    onMoved: root.backgroundDraft = value
                    onPressedChanged: if (!pressed) root.commitBackground()
                }
                StyledText {
                    text: `${Math.round(root.backgroundDraft * 100)}%`
                    color: Appearance.colors.colOnSurfaceVariant
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        SettingsRow {
            visible: root.transparencyEnabled && !root.automatic
            icon: "layers"
            title: Translation.tr("Content")
            description: Translation.tr("How much shell content blends with the surface")

            RowLayout {
                spacing: 10

                StyledSlider {
                    id: contentSlider
                    Layout.preferredWidth: 240
                    configuration: StyledSlider.Configuration.S
                    from: 0
                    to: 1
                    value: root.contentDraft
                    usePercentTooltip: true
                    onMoved: root.contentDraft = value
                    onPressedChanged: if (!pressed) root.commitContent()
                }
                StyledText {
                    text: `${Math.round(root.contentDraft * 100)}%`
                    color: Appearance.colors.colOnSurfaceVariant
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Preview")

        SettingsRow {
            icon: "preview"
            title: Translation.tr("Surface preview")
            description: Translation.tr("Shows transparency only; blur and motion are not controlled here.")
            minimumHeight: 260

            Item {
                implicitWidth: 500
                implicitHeight: 230

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    clip: true
                    color: Appearance.m3colors.m3background

                    Image {
                        anchors.fill: parent
                        source: Config.options.background.wallpaperPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Appearance.m3colors.m3surface
                        opacity: 1 - root.previewBackground
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.72
                        height: parent.height * 0.62
                        radius: Appearance.rounding.normal
                        color: Appearance.m3colors.m3surfaceContainer
                        opacity: 1 - root.previewContent
                        border.color: Appearance.m3colors.m3outline
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Translation.tr("Translucent shell surface")
                                color: Appearance.m3colors.m3onSurface
                                font.pixelSize: Appearance.font.pixelSize.large
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Translation.tr("Background %1% · Content %2%").arg(Math.round(root.previewBackground * 100)).arg(Math.round(root.previewContent * 100))
                                color: Appearance.m3colors.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }
}
