pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * One layer-shell surface per QScreen. QScreen.name and the Hyprland output
 * name are the same connector identity in this shell (for example, eDP-1),
 * so screens are always matched by name rather than list position.
 *
 * Identify numbers use the current logical Hyprland layout, ordered
 * top-to-bottom and then left-to-right (y, then x, then connector name).
 */
Scope {
    id: root

    readonly property bool confirmationActive: DisplaysPreview.previewActive
    readonly property var identifyMonitors: DisplaysService.activeMonitors
        .slice()
        .sort((left, right) => left.y - right.y || left.x - right.x || left.name.localeCompare(right.name))

    function monitorForScreen(screen): var {
        return DisplaysService.monitorByName(screen?.name ?? "");
    }

    function displayName(monitor): string {
        if (monitor?.description)
            return monitor.description;
        if (monitor?.make || monitor?.model)
            return `${monitor.make} ${monitor.model}`.trim();
        return monitor?.name ?? "";
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlayWindow

            required property var modelData
            readonly property var monitor: root.monitorForScreen(modelData)
            readonly property int identifyNumber: root.identifyMonitors.findIndex(item => item.name === monitor?.name) + 1
            readonly property bool identifyShown: DisplayOverlayState.identifyActive && monitor?.enabled === true
            readonly property bool confirmationShown: root.confirmationActive && monitor?.enabled === true
            readonly property bool shown: identifyShown || confirmationShown

            screen: modelData
            visible: shown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:display-overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            // Confirmation deliberately has no keyboard focus: Escape cannot
            // abandon the active backend transaction.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // Identify is click-through. Confirmation accepts only its card,
            // so outside clicks neither dismiss it nor block the desktop.
            mask: Region { item: overlayWindow.confirmationShown ? confirmationCard : null }

            Item {
                id: identifyContent
                anchors.centerIn: parent
                visible: overlayWindow.identifyShown && !overlayWindow.confirmationShown
                width: identifyColumn.implicitWidth + 56
                height: identifyColumn.implicitHeight + 44

                StyledRectangularShadow { target: identifyCard }
                Rectangle {
                    id: identifyCard
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHigh
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant

                    ColumnLayout {
                        id: identifyColumn
                        anchors.centerIn: parent
                        spacing: 4

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: String(overlayWindow.identifyNumber)
                            color: Appearance.colors.colPrimary
                            font.pixelSize: Appearance.font.pixelSize.title * 2.5
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.displayName(overlayWindow.monitor)
                            color: Appearance.colors.colOnSurface
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: overlayWindow.monitor?.name ?? ""
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }
                }
            }

            Item {
                id: confirmationCard
                anchors.centerIn: parent
                visible: overlayWindow.confirmationShown
                width: confirmationColumn.implicitWidth + 48
                height: confirmationColumn.implicitHeight + 40

                StyledRectangularShadow { target: confirmationSurface }
                Rectangle {
                    id: confirmationSurface
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHigh
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant

                    ColumnLayout {
                        id: confirmationColumn
                        anchors.centerIn: parent
                        spacing: 14

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Keep these display settings?")
                            color: Appearance.colors.colOnSurface
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Reverting in %1 seconds").arg(DisplaysPreview.previewSecondsRemaining)
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            DialogButton {
                                buttonText: Translation.tr("Revert")
                                onClicked: DisplaysPreview.revertPreview("user")
                            }
                            DialogButton {
                                buttonText: Translation.tr("Keep Changes")
                                colBackground: Appearance.colors.colPrimary
                                colBackgroundHover: Appearance.colors.colPrimaryHover
                                colRipple: Appearance.colors.colPrimaryActive
                                colText: Appearance.colors.colOnPrimary
                                onClicked: DisplaysPreview.confirmPreview()
                            }
                        }
                    }
                }
            }
        }
    }
}
