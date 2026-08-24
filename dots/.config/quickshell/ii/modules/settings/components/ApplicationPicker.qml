import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    property var applications: []
    property string currentId: ""
    property string title: Translation.tr("Select application")
    property string searchPlaceholder: Translation.tr("Search applications")
    property string query: ""
    property bool loading: false
    property string emptyText: Translation.tr("No applications are available.")
    property string noResultsText: Translation.tr("No matching applications found.")
    property string unavailableText: Translation.tr("Current application unavailable")

    signal selected(var application)
    signal canceled()

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 12

    function displayName(app) { return String(app && (app.name || app.id || "")); }
    function idOf(app) { return String(app && app.id || ""); }
    function filteredApplications() {
        const list = (root.applications || []).slice().sort((a, b) => {
            const ac = root.idOf(a) === root.currentId;
            const bc = root.idOf(b) === root.currentId;
            if (ac !== bc) return ac ? -1 : 1;
            return root.displayName(a).localeCompare(root.displayName(b));
        });
        const needle = root.query.trim().toLowerCase();
        if (!needle) return list;
            return list.filter(app => `${root.displayName(app)} ${root.idOf(app)} ${app && app.description || ""}`.toLowerCase().includes(needle));
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ToolButton {
            display: AbstractButton.IconOnly
            Accessible.name: Translation.tr("Back")
            onClicked: root.canceled()
            contentItem: MaterialSymbol { text: "arrow_back"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurface }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Appearance.font.pixelSize.title
            color: Appearance.colors.colOnSurface
        }
    }

    MaterialTextField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: root.searchPlaceholder
        text: root.query
        Accessible.name: root.searchPlaceholder
        onTextChanged: root.query = text
        Keys.onEscapePressed: root.canceled()
    }

    StyledListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 240
        implicitHeight: Math.min(contentHeight, 420)
        clip: true
        focus: false
        activeFocusOnTab: true
        keyNavigationEnabled: true
        model: root.filteredApplications()
        Keys.onReturnPressed: {
            if (currentIndex >= 0 && currentIndex < model.length)
                root.selected(model[currentIndex]);
        }

        delegate: SettingsRow {
            required property var modelData
            width: list.width
            iconSource: Quickshell.iconPath(modelData.icon || "application-x-executable", "image-missing")
            title: root.displayName(modelData)
            description: modelData.unavailable
                ? root.unavailableText
                : String(modelData.secondary || modelData.description || modelData.id || "")
            clickable: !modelData.unavailable
            color: root.idOf(modelData) === root.currentId
                ? Appearance.colors.colSecondaryContainer
                : Appearance.colors.colSurfaceContainerHighest
            focus: ListView.isCurrentItem
            activeFocusOnTab: true
            Accessible.name: root.displayName(modelData) + (root.idOf(modelData) === root.currentId ? ", " + Translation.tr("Selected") : "")
            onClicked: root.selected(modelData)
            Keys.onReturnPressed: if (enabled) root.selected(modelData)

            MaterialSymbol {
                visible: root.idOf(modelData) === root.currentId
                text: "check"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colPrimary
            }
        }
    }

    SettingsRow {
        visible: root.loading
        icon: "hourglass_top"
        title: Translation.tr("Loading applications…")
        description: Translation.tr("Preparing the application list.")
        registerInSearch: false
    }
    SettingsRow {
        visible: !root.loading && root.applications.length === 0
        icon: "apps"
        title: root.emptyText
        description: Translation.tr("No candidate applications were provided.")
        registerInSearch: false
    }
    SettingsRow {
        visible: !root.loading && root.applications.length > 0 && root.filteredApplications().length === 0
        icon: "search_off"
        title: root.noResultsText
        description: Translation.tr("Try a different search.")
        registerInSearch: false
    }

    Component.onCompleted: searchField.forceActiveFocus()
    onVisibleChanged: if (visible) { root.query = ""; Qt.callLater(() => searchField.forceActiveFocus()); }
    Keys.onEscapePressed: root.canceled()
}
