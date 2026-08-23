import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property string query: ""
    property var selectedMime: null
    property string candidateQuery: ""
    property bool pickerOpen: false

    readonly property var categories: ["Documents", "Images", "Audio", "Video", "Archives", "Text & Code", "Fonts", "Packages & Disk Images", "Other"]
    readonly property var filteredItems: {
        const needle = root.query.trim().toLowerCase();
        return (MimeTypeInventory.items || []).filter(item => {
            if (!needle) return true;
            const current = root.currentId(item);
            const entry = root.entryFor(current);
            const name = entry?.name || current;
            return `${item.description} ${(item.extensions || []).join(" ")} ${item.id} ${name}`.toLowerCase().includes(needle);
        });
    }

    Component.onCompleted: MimeTypeInventory.refresh()

    function currentId(item) {
        return String(MimeAssociations.values[item.id] || item.defaultId || "");
    }

    function entryFor(id) {
        if (!id)
            return null;
        const direct = DesktopEntries.byId(id);
        if (direct)
            return direct;
        const target = String(id);
        const withoutSuffix = target.endsWith(".desktop") ? target.slice(0, -8) : target;
        return Array.from(DesktopEntries.applications.values || []).find(entry => {
            const entryId = String(entry.id || "");
            return entryId === target || entryId === withoutSuffix || `${entryId}.desktop` === target;
        }) || null;
    }

    function entryName(id) {
        const entry = root.entryFor(id);
        return entry?.name || id || Translation.tr("Not set");
    }

    function currentDescription(item) {
        const id = root.currentId(item);
        const entry = root.entryFor(id);
        if (!id) return Translation.tr("Not set");
        if (!entry) return `${Translation.tr("Current application unavailable")} · ${id}`;
        if (entry.hidden || entry.noDisplay) return `${entry.name || id} · ${Translation.tr("Hidden application")}`;
        return entry.name || id;
    }

    function itemsForCategory(category) {
        return root.filteredItems.filter(item => item.category === category);
    }

    function openPicker(item) {
        root.selectedMime = item;
        root.candidateQuery = "";
        root.pickerOpen = true;
    }

    function candidateEntries() {
        const item = root.selectedMime;
        if (!item) return [];
        const current = root.currentId(item);
        const result = [];
        for (const id of item.candidateIds || []) {
            const entry = root.entryFor(id);
            if (entry && !entry.hidden && !entry.noDisplay)
                result.push(entry);
        }
        const currentEntry = root.entryFor(current);
        if (currentEntry && !result.some(entry => entry.id === currentEntry.id))
            result.unshift(currentEntry);
        if (!currentEntry && current)
            result.unshift({ id: current, name: Translation.tr("Current application unavailable"), icon: "error_outline", unavailable: true });
        return result.sort((a, b) => {
            const aCurrent = a.id === current;
            const bCurrent = b.id === current;
            if (aCurrent !== bCurrent) return aCurrent ? -1 : 1;
            return String(a.name || a.id).localeCompare(String(b.name || b.id));
        });
    }

    function filteredCandidates() {
        const needle = root.candidateQuery.trim().toLowerCase();
        return root.candidateEntries().filter(entry => !needle || `${entry.name || ""} ${entry.id || ""}`.toLowerCase().includes(needle));
    }

    function desktopFileId(entry) {
        const id = String(entry?.id || "");
        return id && id.endsWith(".desktop") ? id : `${id}.desktop`;
    }

    function chooseCandidate(entry) {
        if (!root.selectedMime || entry.unavailable || MimeAssociations.applying)
            return;
        if (MimeAssociations.apply(root.desktopFileId(entry), [root.selectedMime.id]))
            root.pickerOpen = false;
    }

    Connections {
        target: MimeTypeInventory
        function onRefreshed(success) {
            if (success)
                MimeAssociations.query((MimeTypeInventory.items || []).map(item => item.id), true);
        }
    }

    Connections {
        target: MimeAssociations
        function onRevisionChanged() {
            if (MimeTypeInventory.ready && !MimeTypeInventory.loading && !MimeAssociations.applying)
                MimeAssociations.query((MimeTypeInventory.items || []).map(item => item.id), true);
        }
    }

    SettingsGroup {
        title: Translation.tr("FILE ASSOCIATIONS")

        SettingsRow {
            icon: "search"
            title: Translation.tr("Search file types")
            description: root.query.length > 0
                ? Translation.tr("Showing %1 matching file types").arg(root.filteredItems.length)
                : Translation.tr("Search by name, extension, MIME type, or application.")
            registerInSearch: false
            MaterialTextField {
                Layout.preferredWidth: 280
                placeholderText: Translation.tr("Search")
                text: root.query
                onTextChanged: root.query = text
            }
        }

        SettingsRow {
            icon: "refresh"
            title: Translation.tr("Refresh")
            description: MimeTypeInventory.loading ? Translation.tr("Reading file type metadata…") : Translation.tr("Reload file types, handlers, and defaults.")
            registerInSearch: false
            DialogButton {
                buttonText: MimeTypeInventory.loading ? Translation.tr("Refreshing…") : Translation.tr("Refresh")
                enabled: !MimeTypeInventory.loading
                onClicked: MimeTypeInventory.refresh()
            }
        }

        SettingsRow {
            visible: MimeTypeInventory.loading
            icon: "hourglass_top"
            title: Translation.tr("Loading file types…")
            description: Translation.tr("Building the common MIME inventory.")
            registerInSearch: false
        }
    }

    Repeater {
        model: root.categories
        SettingsGroup {
            required property string modelData
            readonly property string categoryName: modelData
            visible: root.itemsForCategory(categoryName).length > 0
            title: Translation.tr(categoryName)

            Repeater {
                model: root.itemsForCategory(categoryName)
                SettingsRow {
                    required property var modelData
                    icon: "insert_drive_file"
                    title: modelData.description
                    description: (modelData.extensions || []).join(", ") || modelData.id
                    clickable: true
                    registerInSearch: false
                    onClicked: root.openPicker(modelData)

                    RowLayout {
                        spacing: 8
                        Image {
                            visible: !!root.entryFor(root.currentId(modelData))
                            source: root.entryFor(root.currentId(modelData)) ? Quickshell.iconPath(root.entryFor(root.currentId(modelData)).icon || "application-x-executable", "image-missing") : ""
                            sourceSize: Qt.size(24, 24)
                            Layout.preferredWidth: visible ? 24 : 0
                            Layout.preferredHeight: visible ? 24 : 0
                        }
                        StyledText {
                            text: root.currentDescription(modelData)
                            color: Appearance.colors.colOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                        MaterialSymbol {
                            text: "chevron_right"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }
                }
            }
        }
    }

    SettingsRow {
        visible: MimeTypeInventory.ready && root.filteredItems.length === 0
        icon: "search_off"
        title: root.query.length > 0 ? Translation.tr("No matching file types") : Translation.tr("No file types found")
        description: root.query.length > 0 ? Translation.tr("Try a different search.") : Translation.tr("No supported user-facing file types were detected.")
        registerInSearch: false
    }

    SettingsRow {
        visible: MimeTypeInventory.error.length > 0
        icon: "error_outline"
        title: Translation.tr("File type information unavailable")
        description: MimeTypeInventory.error
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
                text: root.selectedMime?.description || Translation.tr("Select application")
                font.pixelSize: Appearance.font.pixelSize.title
                color: Appearance.colors.colOnSurface
            }

            StyledText {
                Layout.fillWidth: true
                text: root.selectedMime ? `${(root.selectedMime.extensions || []).join(", ")} · ${root.selectedMime.id}` : ""
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
            }

            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search applications")
                text: root.candidateQuery
                onTextChanged: root.candidateQuery = text
            }

            StyledListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filteredCandidates()

                delegate: ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: 56
                    enabled: !MimeAssociations.applying && !modelData.unavailable

                    background: Rectangle {
                        radius: Appearance.rounding.small
                        color: modelData.id === root.currentId(root.selectedMime) ? Appearance.colors.colSecondaryContainer : "transparent"
                    }

                    contentItem: RowLayout {
                        spacing: 12
                        Image {
                            source: Quickshell.iconPath(modelData.icon || "application-x-executable", "image-missing")
                            sourceSize: Qt.size(32, 32)
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            StyledText { text: modelData.name || modelData.id; color: Appearance.colors.colOnSurface }
                            StyledText { text: modelData.id === root.currentId(root.selectedMime) ? Translation.tr("Current") : modelData.id; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smaller }
                        }
                    }

                    onClicked: root.chooseCandidate(modelData)
                }
            }

            StyledText {
                visible: root.filteredCandidates().length === 0
                text: Translation.tr("No compatible applications found.")
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }
}
