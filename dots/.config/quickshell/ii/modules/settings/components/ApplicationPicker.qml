import QtQuick
import QtQuick.Layouts
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

    // Deliberately smaller than the page title above it. This is a state
    // within the page, not a second page, and rendering it at page-title size
    // made two competing headers. Properly it should replace the page's own
    // header - that needs the nested-navigation mechanism described in
    // docs/design/settings-app.md, which does not exist yet.
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        spacing: 8

        RippleButton {
            implicitWidth: 36
            implicitHeight: 36
            buttonRadius: Appearance.rounding.full
            Accessible.name: Translation.tr("Back")
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
            colRipple: Appearance.colors.colSurfaceContainerHighestActive
            onClicked: root.canceled()
            contentItem: MaterialSymbol {
                text: "arrow_back"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnSurface
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.Medium
            color: Appearance.colors.colOnSurface
            elide: Text.ElideRight
        }
    }

    SettingsSearchField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: root.searchPlaceholder
        text: root.query
        onTextChanged: root.query = text
        onEscaped: root.canceled()
    }

    StyledListView {
        id: list
        readonly property bool hasRows: root.filteredApplications().length > 0
        visible: hasRows
        Layout.fillWidth: true
        Layout.fillHeight: hasRows
        Layout.preferredHeight: hasRows ? Math.min(contentHeight, 420) : 0
        spacing: 4
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
