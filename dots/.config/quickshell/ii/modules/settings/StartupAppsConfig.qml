import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property string pickerQuery: ""
    property bool pickerOpen: false

    function displayName(entry) {
        return entry.name || entry.basename.replace(/\.desktop$/, "");
    }

    function candidates() {
        const present = Autostart.entries.map(entry => entry.basename);
        const needle = root.pickerQuery.trim().toLowerCase();
        return Array.from(DesktopEntries.applications.values || [])
            .filter(entry => !entry.hidden && !entry.noDisplay && entry.command?.length > 0)
            .filter(entry => !present.includes(String(entry.id).endsWith(".desktop") ? String(entry.id) : `${entry.id}.desktop`))
            .filter(entry => !needle || `${entry.name} ${entry.id}`.toLowerCase().includes(needle))
            .sort((a, b) => String(a.name || a.id).localeCompare(String(b.name || b.id)));
    }

    Component.onCompleted: Autostart.refresh()

    SettingsGroup {
        title: Translation.tr("STARTUP APPS")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Apps that start automatically when you sign in.")
            color: Appearance.colors.colOnSurfaceVariant
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: Autostart.entries

            SettingsRow {
                required property var modelData
                icon: modelData.icon || "application-x-executable"
                iconSource: Quickshell.iconPath(modelData.icon || "application-x-executable", "image-missing")
                title: root.displayName(modelData)
                description: modelData.available === false ? `${Translation.tr("Unavailable")} · ${modelData.exec || modelData.basename}` : (modelData.exec || modelData.basename)
                enabled: !Autostart.applying
                clickable: true
                onClicked: Autostart.toggle(modelData, !modelData.enabled)

                RowLayout {
                    spacing: 8

                    StyledSwitch {
                        checked: modelData.enabled
                        enabled: !Autostart.applying
                        onClicked: {
                            checked = Qt.binding(() => modelData.enabled);
                            Autostart.toggle(modelData, !modelData.enabled);
                        }
                    }

                    DialogButton {
                        visible: modelData.removable
                        buttonText: Translation.tr("Remove")
                        enabled: !Autostart.applying
                        onClicked: Autostart.remove(modelData)
                    }
                }
            }
        }

        SettingsRow {
            visible: Autostart.entries.length === 0
            icon: "info"
            title: Translation.tr("No user-facing startup apps")
            description: Translation.tr("Add an installed application to start it automatically.")
            registerInSearch: false
        }

        SettingsRow {
            icon: "add"
            title: Translation.tr("Add startup app")
            description: Translation.tr("Choose an installed application.")
            clickable: true
            onClicked: {
                root.pickerQuery = "";
                root.pickerOpen = true;
            }
        }
    }

    SettingsRow {
        visible: Autostart.error.length > 0
        icon: "error_outline"
        title: Translation.tr("Startup applications unavailable")
        description: Autostart.error
        registerInSearch: false
    }

    Popup {
        id: picker
        parent: Overlay.overlay
        visible: root.pickerOpen
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(560, (root.Window.window?.width ?? 900) - 32)
        height: Math.min(620, (root.Window.window?.height ?? 720) - 48)
        anchors.centerIn: Overlay.overlay
        padding: 16
        onClosed: root.pickerOpen = false

        background: Rectangle {
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3surfaceContainerHigh
            StyledRectangularShadow { target: parent }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Add startup app")
                font.pixelSize: Appearance.font.pixelSize.title
                color: Appearance.colors.colOnSurface
            }

            TextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search applications")
                text: root.pickerQuery
                onTextChanged: root.pickerQuery = text
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width
                    Repeater {
                        model: root.candidates()
                        SettingsRow {
                            required property var modelData
                            Layout.fillWidth: true
                            iconSource: Quickshell.iconPath(modelData.icon || "application-x-executable", "image-missing")
                            title: modelData.name || modelData.id
                            description: modelData.id
                            clickable: true
                            onClicked: {
                                const desktopId = String(modelData.id || "");
                                Autostart.add(desktopId.endsWith(".desktop") ? desktopId : `${desktopId}.desktop`);
                                root.pickerOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
