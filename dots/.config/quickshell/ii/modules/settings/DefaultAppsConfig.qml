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

    property string selectedRoleId: ""
    property string candidateQuery: ""
    property bool pickerOpen: false

    readonly property var roles: [
        { id: "browser", title: Translation.tr("Web browser"), description: Translation.tr("Used when opening links and web documents."), icon: "language", mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"] },
        { id: "email", title: Translation.tr("Email"), description: "", icon: "mail", mimes: ["x-scheme-handler/mailto"] },
        { id: "fileManager", title: Translation.tr("File manager"), description: Translation.tr("Used when applications open folders."), icon: "folder", mimes: ["inode/directory"] },
        { id: "textEditor", title: Translation.tr("Text editor"), description: Translation.tr("Used for plain text files."), icon: "edit_note", mimes: ["text/plain"] },
        { id: "images", title: Translation.tr("Image viewer"), description: "", icon: "image", mimes: ["image/jpeg", "image/png", "image/webp", "image/gif", "image/svg+xml", "image/avif", "image/bmp", "image/tiff"] },
        { id: "video", title: Translation.tr("Video player"), description: "", icon: "movie", mimes: ["video/mp4", "video/x-matroska", "video/webm", "video/mpeg", "video/quicktime", "video/x-msvideo"] },
        { id: "music", title: Translation.tr("Music player"), description: "", icon: "music_note", mimes: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/opus", "audio/x-wav", "audio/mp4"] },
        { id: "pdf", title: Translation.tr("PDF viewer"), description: "", icon: "picture_as_pdf", mimes: ["application/pdf"] },
        { id: "archives", title: Translation.tr("Archive manager"), description: "", icon: "folder_zip", mimes: ["application/zip", "application/x-7z-compressed", "application/vnd.rar", "application/x-tar"] }
    ]

    readonly property var allMimes: {
        const result = [];
        for (const role of root.roles)
            for (const mime of role.mimes)
                if (!result.includes(mime)) result.push(mime);
        return result;
    }

    function roleFor(id) {
        return root.roles.find(role => role.id === id) || null;
    }

    function entryFor(id) {
        if (!id) return null;
        return DesktopEntries.byId(id) || null;
    }

    function roleState(role) {
        const values = role.mimes.map(mime => String(MimeAssociations.values[mime] || ""));
        const active = values.filter(value => value.length > 0);
        const unique = [...new Set(active)];
        if (active.length === 0)
            return { kind: "unset", desktopId: "", entry: null };
        if (unique.length > 1)
            return { kind: "mixed", desktopId: "", entry: null, ids: unique };
        const entry = root.entryFor(unique[0]);
        return { kind: entry ? "set" : "stale", desktopId: unique[0], entry: entry };
    }

    function entryName(entry, fallback) {
        return entry?.name || fallback || Translation.tr("Not set");
    }

    function roleValue(role) {
        if (!MimeAssociations.ready) return Translation.tr("Loading…");
        const state = root.roleState(role);
        if (state.kind === "unset") return Translation.tr("Not set");
        if (state.kind === "mixed") return Translation.tr("Mixed");
        return root.entryName(state.entry, state.desktopId);
    }

    function roleDescription(role) {
        const state = root.roleState(role);
        if (state.kind === "mixed")
            return Translation.tr("Different apps are used for these file types.");
        if (state.kind === "stale")
            return `${state.desktopId} · ${Translation.tr("Unavailable")}`;
        if (state.kind === "set" && (state.entry?.noDisplay || state.entry?.hidden))
            return `${role.description || Translation.tr("Current association")}${role.description ? " · " : ""}${Translation.tr("Hidden handler")}`;
        return role.description;
    }

    function entrySupports(entry, role) {
        if (!entry || entry.hidden || entry.noDisplay) return false;
        const supported = entry.supportedMimeTypes || [];
        return role.mimes.every(mime => supported.includes(mime));
    }

    function candidatesFor(role) {
        if (!role) return [];
        const entries = DesktopEntries.applications.values || [];
        const state = root.roleState(role);
        const candidates = entries.filter(entry => root.entrySupports(entry, role));
        const current = state.desktopId ? root.entryFor(state.desktopId) : null;
        if (current && !current.hidden && !current.noDisplay && !candidates.some(entry => entry.id === current.id))
            candidates.push(current);
        return candidates.sort((a, b) => {
            const aCurrent = a.id === state.desktopId;
            const bCurrent = b.id === state.desktopId;
            if (aCurrent !== bCurrent) return aCurrent ? -1 : 1;
            return String(a.name || a.id).localeCompare(String(b.name || b.id));
        });
    }

    function filteredCandidates() {
        const role = root.roleFor(root.selectedRoleId);
        const candidates = root.candidatesFor(role);
        const needle = root.candidateQuery.trim().toLowerCase();
        if (!needle) return candidates;
        return candidates.filter(entry => `${entry.name || ""} ${entry.id || ""}`.toLowerCase().includes(needle));
    }

    function openPicker(role) {
        root.selectedRoleId = role.id;
        root.candidateQuery = "";
        root.pickerOpen = true;
    }

    function chooseCandidate(entry) {
        const role = root.roleFor(root.selectedRoleId);
        if (!role || MimeAssociations.applying) return;
        if (MimeAssociations.apply(entry.id, role.mimes))
            root.pickerOpen = false;
    }

    Component.onCompleted: MimeAssociations.refresh(root.allMimes)

    Connections {
        target: MimeAssociations
        function onRevisionChanged() {
            if (MimeAssociations.ready && !MimeAssociations.loading && !MimeAssociations.applying)
                MimeAssociations.refresh(root.allMimes);
        }
        function onApplied(success) {
            if (success) MimeAssociations.refresh(root.allMimes);
        }
    }

    SettingsGroup {
        title: Translation.tr("DEFAULT APPS")

        Repeater {
            model: root.roles

            SettingsRow {
                required property var modelData
                readonly property var state: root.roleState(modelData)
                icon: modelData.icon
                title: modelData.title
                description: root.roleDescription(modelData)
                clickable: true
                onClicked: root.openPicker(modelData)

                RowLayout {
                    spacing: 8

                    Image {
                        visible: state.entry !== null
                        source: state.entry ? Quickshell.iconPath(state.entry.icon || "application-x-executable", "image-missing") : ""
                        sourceSize: Qt.size(24, 24)
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                    }

                    StyledText {
                        text: root.roleValue(modelData)
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

    SettingsRow {
        visible: MimeAssociations.error.length > 0
        icon: "error_outline"
        title: Translation.tr("Default applications unavailable")
        description: MimeAssociations.error
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
                text: root.roleFor(root.selectedRoleId)?.title || Translation.tr("Select default application")
                font.pixelSize: Appearance.font.pixelSize.title
                color: Appearance.colors.colOnSurface
            }

            StyledText {
                visible: root.roleFor(root.selectedRoleId)?.id === "images"
                Layout.fillWidth: true
                text: Translation.tr("Choosing an app applies it to all common image types in this role.")
                color: Appearance.colors.colOnSurfaceVariant
                wrapMode: Text.WordWrap
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
                    enabled: !MimeAssociations.applying

                    background: Rectangle {
                        radius: Appearance.rounding.small
                        color: modelData.id === (root.roleFor(root.selectedRoleId) ? root.roleState(root.roleFor(root.selectedRoleId)).desktopId : "")
                            ? Appearance.colors.colSecondaryContainer : "transparent"
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
                            StyledText { text: modelData.id; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smaller }
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
