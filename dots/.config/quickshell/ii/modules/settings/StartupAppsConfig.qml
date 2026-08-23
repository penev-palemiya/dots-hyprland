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

    property bool pickerOpen: false
    property var pendingRemoval: null

    function desktopId(entry) {
        const id = String(entry?.id || "");
        return id.endsWith(".desktop") ? id : `${id}.desktop`;
    }

    function displayName(entry) {
        return entry.name || entry.basename.replace(/\.desktop$/, "");
    }

    function candidates() {
        const present = Autostart.entries.map(entry => entry.basename);
        return Array.from(DesktopEntries.applications.values || [])
            .filter(entry => !entry.hidden && !entry.noDisplay && entry.command?.length > 0)
            .filter(entry => !present.includes(root.desktopId(entry)))
            .sort((a, b) => String(a.name || a.id).localeCompare(String(b.name || b.id)));
    }

    function addCandidate(entry) {
        if (!entry)
            return;
        Autostart.add(root.desktopId(entry));
        root.pickerOpen = false;
    }

    Component.onCompleted: Autostart.refresh()

    SettingsGroup {
        visible: !root.pickerOpen
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
                        visible: modelData.removable && root.pendingRemoval !== modelData
                        buttonText: Translation.tr("Remove")
                        enabled: !Autostart.applying
                        onClicked: root.pendingRemoval = modelData
                    }

                    DialogButton {
                        visible: root.pendingRemoval === modelData
                        buttonText: Translation.tr("Confirm")
                        enabled: !Autostart.applying
                        onClicked: { Autostart.remove(modelData); root.pendingRemoval = null; }
                    }

                    DialogButton {
                        visible: root.pendingRemoval === modelData
                        buttonText: Translation.tr("Cancel")
                        onClicked: root.pendingRemoval = null
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
                root.pickerOpen = true;
            }
        }
    }

    SettingsRow {
        visible: !root.pickerOpen && Autostart.error.length > 0
        icon: "error_outline"
        title: Translation.tr("Startup applications unavailable")
        description: Autostart.error
        registerInSearch: false
    }

    ApplicationPicker {
        visible: root.pickerOpen
        title: Translation.tr("Add startup app")
        applications: root.candidates()
        currentId: ""
        noResultsText: Translation.tr("No matching applications found.")
        onSelected: application => root.addCandidate(application)
        onCanceled: root.pickerOpen = false
    }

    SettingsRow {
        visible: !root.pickerOpen
        icon: "refresh"
        title: Translation.tr("Refresh startup apps")
        description: Translation.tr("Reload entries from the effective XDG autostart files.")
        clickable: true
        enabled: !Autostart.loading && !Autostart.applying
        onClicked: Autostart.refresh(true)
        registerInSearch: false
    }
}
