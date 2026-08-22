import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    readonly property int shownCount: Math.max(1, Config.options.bar.workspaces.shown)
    readonly property int activeWorkspaceId: HyprlandData.activeWorkspace?.id ?? 1
    readonly property int workspaceGroup: Math.floor((root.activeWorkspaceId - 1) / root.shownCount)
    readonly property var slotIndexes: Array.from({ length: root.shownCount }, (_, index) => index)

    function workspaceIdAt(index) {
        return root.workspaceGroup * root.shownCount + index + 1;
    }

    function windowCount(id) {
        return HyprlandData.windowList.filter(window => window.workspace?.id === id).length;
    }

    function biggestWindow(id) {
        return HyprlandData.biggestWindowForWorkspace(id);
    }

    function iconSource(id) {
        const window = root.biggestWindow(id);
        return window ? Quickshell.iconPath(AppSearch.guessIcon(window.class), "image-missing") : "";
    }

    function slotShowsIcon(id) {
        return Config.options.bar.workspaces.showAppIcons && root.windowCount(id) > 0 && root.iconSource(id).length > 0;
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Live workspace preview")
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.Medium
            color: Appearance.colors.colOnSurface
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Workspaces are created automatically as needed.")
            color: Appearance.colors.colOnSurfaceVariant
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: previewFlow.childrenRect.height + 28
            Layout.minimumHeight: previewFlow.childrenRect.height + 28
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerHighest

            Flow {
                id: previewFlow
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 16
                    rightMargin: 16
                    topMargin: 14
                }
                spacing: 6

                Repeater {
                    model: root.slotIndexes

                    delegate: Rectangle {
                        required property int modelData
                        readonly property int workspaceId: root.workspaceIdAt(modelData)
                        readonly property int windows: root.windowCount(workspaceId)
                        readonly property bool active: workspaceId === root.activeWorkspaceId
                        readonly property bool hasIcon: root.slotShowsIcon(workspaceId)

                        width: Math.max(42, Math.min(56, (previewFlow.width - (root.shownCount - 1) * previewFlow.spacing) / root.shownCount))
                        height: 58
                        radius: Appearance.rounding.small
                        color: active
                            ? Appearance.colors.colPrimaryContainer
                            : Appearance.colors.colLayer2
                        border.width: active ? 2 : 0
                        border.color: Appearance.colors.colPrimary

                        StyledText {
                            anchors {
                                top: parent.top
                                horizontalCenter: parent.horizontalCenter
                                topMargin: 6
                            }
                            text: workspaceId
                            color: active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        Image {
                            id: previewIcon
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 7
                            width: 24
                            height: 24
                            source: root.iconSource(workspaceId)
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                            visible: hasIcon
                        }

                        ColorOverlay {
                            anchors.fill: previewIcon
                            source: previewIcon
                            color: active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            visible: hasIcon && Config.options.bar.workspaces.monochromeIcons
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 7
                            text: "apps"
                            iconSize: 22
                            color: active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            visible: hasIcon && previewIcon.status === Image.Error
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 8
                            width: windows > 0 ? Math.min(22, 6 + windows * 5) : 5
                            height: 5
                            radius: 3
                            color: active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            visible: !hasIcon || previewIcon.status === Image.Error
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                rightMargin: 4
                                bottomMargin: 4
                            }
                            width: 16
                            height: 14
                            radius: 7
                            color: active ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHigh
                            visible: windows > 1

                            StyledText {
                                anchors.centerIn: parent
                                text: windows
                                color: active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("WORKSPACE INDICATOR")

        SettingsRow {
            icon: "view_carousel"
            title: Translation.tr("Workspaces shown")
            description: Translation.tr("Number of workspace positions shown in the workspace indicator")

            StyledSpinBox {
                from: 1
                to: 10
                stepSize: 1
                value: Config.options.bar.workspaces.shown
                onValueChanged: {
                    const next = Math.max(from, Math.min(to, Math.round(value)));
                    if (Config.options.bar.workspaces.shown !== next)
                        Config.options.bar.workspaces.shown = next;
                }
            }
        }

        SettingsToggleRow {
            icon: "apps"
            title: Translation.tr("Show application icons")
            description: Translation.tr("Show the largest window's application icon in occupied slots")
            checked: Config.options.bar.workspaces.showAppIcons
            onToggled: checked => Config.options.bar.workspaces.showAppIcons = checked
        }

        SettingsToggleRow {
            icon: "colors"
            title: Translation.tr("Monochrome app icons")
            description: Config.options.bar.workspaces.showAppIcons
                ? Translation.tr("Tint workspace application icons with the shell color")
                : Translation.tr("Enable application icons to use this option")
            checked: Config.options.bar.workspaces.monochromeIcons
            enabled: Config.options.bar.workspaces.showAppIcons
            onToggled: checked => Config.options.bar.workspaces.monochromeIcons = checked
        }

        SettingsToggleRow {
            icon: "numbers"
            title: Translation.tr("Always show workspace numbers")
            description: Translation.tr("Keep numbers visible instead of contextual dots or application icons")
            checked: Config.options.bar.workspaces.alwaysShowNumbers
            onToggled: checked => Config.options.bar.workspaces.alwaysShowNumbers = checked
        }
    }
}
