import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var entities: []
    property string currentId: ""
    property string placeholder: Translation.tr("Select device")
    property string searchPlaceholder: Translation.tr("Search devices")
    property string query: ""
    signal selected(var entity)
    signal canceled()

    implicitWidth: 300
    implicitHeight: 40
    activeFocusOnTab: true

    function idOf(entity) { return String(entity && entity.id !== undefined ? entity.id : ""); }
    function nameOf(entity) { return String(entity && (entity.name || entity.label || entity.id || "")); }
    function secondaryOf(entity) { return String(entity && (entity.secondary || entity.status || "")); }
    function filteredEntities() {
        const values = (root.entities || []).slice().sort((a, b) => {
            const ac = root.idOf(a) === root.currentId;
            const bc = root.idOf(b) === root.currentId;
            if (ac !== bc) return ac ? -1 : 1;
            return root.nameOf(a).localeCompare(root.nameOf(b));
        });
        const needle = root.query.trim().toLowerCase();
        return needle ? values.filter(entity => `${root.nameOf(entity)} ${root.secondaryOf(entity)} ${root.idOf(entity)}`.toLowerCase().includes(needle)) : values;
    }

    RippleButton {
        id: trigger
        anchors.fill: parent
        enabled: root.enabled
        activeFocusOnTab: true
        Accessible.name: root.entities.find(entity => root.idOf(entity) === root.currentId) ? root.nameOf(root.entities.find(entity => root.idOf(entity) === root.currentId)) : root.placeholder
        buttonRadius: height / 2
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colBackgroundToggled: Appearance.colors.colSecondaryContainerActive
        onClicked: {
            root.query = "";
            picker.open();
            Qt.callLater(() => searchField.forceActiveFocus());
        }
        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: root.entities.find(entity => root.idOf(entity) === root.currentId) ? root.nameOf(root.entities.find(entity => root.idOf(entity) === root.currentId)) : root.placeholder
                color: Appearance.colors.colOnSecondaryContainer
                elide: Text.ElideRight
            }
            MaterialSymbol { text: "keyboard_arrow_down"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer; rotation: picker.visible ? 180 : 0 }
        }
    }

    Popup {
        id: picker
        y: root.height + 4
        width: Math.min(Math.max(root.width, 360), (root.Window.window ? root.Window.window.width : 800) - 16)
        height: Math.min(column.implicitHeight + 16, 420)
        padding: 8
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: Qt.callLater(() => trigger.forceActiveFocus())

        background: Rectangle { radius: Appearance.rounding.normal; color: Appearance.m3colors.m3surfaceContainerHigh; StyledRectangularShadow { target: parent } }

        ColumnLayout {
            id: column
            anchors.fill: parent
            spacing: 8
            MaterialTextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: root.searchPlaceholder
                Accessible.name: root.searchPlaceholder
                text: root.query
                onTextChanged: if (text !== root.query) root.query = text
                Keys.onEscapePressed: picker.close()
            }
            StyledListView {
                id: entityList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: root.filteredEntities()
                clip: true
                focus: true
                keyNavigationEnabled: true
                activeFocusOnTab: true
                delegate: ItemDelegate {
                    required property var modelData
                    width: entityList.width
                    implicitHeight: 54
                    background: Rectangle { radius: Appearance.rounding.small; color: root.idOf(modelData) === root.currentId ? Appearance.colors.colSecondaryContainer : "transparent" }
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        MaterialSymbol { visible: !!modelData.icon; text: modelData.icon || "device_hub"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurfaceVariant }
                        ColumnLayout {
                            Layout.fillWidth: true
                            StyledText { Layout.fillWidth: true; text: root.nameOf(modelData); color: Appearance.colors.colOnSurface; elide: Text.ElideRight }
                            StyledText { Layout.fillWidth: true; text: root.secondaryOf(modelData); visible: text.length > 0; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smaller; elide: Text.ElideRight }
                        }
                        MaterialSymbol { visible: root.idOf(modelData) === root.currentId; text: "check"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colPrimary }
                    }
                    onClicked: { root.selected(modelData); picker.close(); }
                }
            }
            StyledText { visible: entityList.count === 0; text: root.entities.length === 0 ? Translation.tr("No devices available.") : Translation.tr("No matching devices."); color: Appearance.colors.colOnSurfaceVariant }
        }
    }
}
