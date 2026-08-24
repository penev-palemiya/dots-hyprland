import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string currentValue: ""
    property var options: []
    property var items: []
    property string placeholder: Translation.tr("Select")
    property string searchPlaceholder: Translation.tr("Search")
    signal selected(string value)

    implicitWidth: 300
    implicitHeight: 40
    activeFocusOnTab: true

    function sourceItems() {
        if (root.items && root.items.length > 0)
            return root.items;
        return root.options.map(value => ({ value: value, primaryText: value }));
    }
    function itemValue(item) { return typeof item === "string" ? item : String(item && (item.value !== undefined ? item.value : (item.primaryText !== undefined ? item.primaryText : ""))); }
    function primaryText(item) { return typeof item === "string" ? item : String(item && (item.primaryText || item.label || root.itemValue(item))); }
    function secondaryText(item) { return typeof item === "string" ? "" : String(item && (item.secondaryText || "")); }
    function iconText(item) { return typeof item === "string" ? "" : String(item && (item.icon || "")); }
    function filteredOptions() {
        const query = searchField.text.trim().toLowerCase();
        const values = root.sourceItems();
        if (query === "") return values;
        return values.filter(item => `${root.primaryText(item)} ${root.secondaryText(item)} ${root.itemValue(item)}`.toLowerCase().includes(query));
    }

    RippleButton {
        id: trigger
        anchors.fill: parent
        enabled: root.enabled
        activeFocusOnTab: true
        Accessible.name: root.currentValue || root.placeholder
        buttonRadius: height / 2
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colBackgroundToggled: Appearance.colors.colSecondaryContainerActive
        onClicked: {
            searchField.text = "";
            selectorPopup.open();
            Qt.callLater(() => searchField.forceActiveFocus());
        }

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: root.currentValue || root.placeholder
                color: Appearance.colors.colOnSecondaryContainer
                elide: Text.ElideRight
            }
            MaterialSymbol {
                text: "keyboard_arrow_down"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnSecondaryContainer
                rotation: selectorPopup.visible ? 180 : 0
            }
        }
    }

    Popup {
        id: selectorPopup
        y: root.height + 4
        width: Math.min(Math.max(root.width, 360), (root.Window.window ? root.Window.window.width : 800) - 16)
        height: Math.min(selectorColumn.implicitHeight + 16, 420)
        padding: 8
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: {
            searchField.forceActiveFocus();
            const index = optionList.model.findIndex(item => root.itemValue(item) === root.currentValue);
            optionList.currentIndex = index >= 0 ? index : 0;
            if (index >= 0) optionList.positionViewAtIndex(index, ListView.Visible);
        }
        onClosed: Qt.callLater(() => trigger.forceActiveFocus())

        background: Rectangle {
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3surfaceContainerHigh
            StyledRectangularShadow { target: parent }
        }

        ColumnLayout {
            id: selectorColumn
            anchors.fill: parent
            spacing: 8

            MaterialTextField {
                id: searchField
                Layout.fillWidth: true
                implicitHeight: 40
                placeholderText: root.searchPlaceholder
                Accessible.name: root.searchPlaceholder
                onTextChanged: optionList.model = root.filteredOptions()
                Keys.onEscapePressed: selectorPopup.close()
            }

            StyledListView {
                id: optionList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.filteredOptions()
                focus: true
                keyNavigationEnabled: true
                activeFocusOnTab: true
                Keys.onReturnPressed: if (currentIndex >= 0 && currentIndex < model.length) { root.selected(root.itemValue(model[currentIndex])); selectorPopup.close(); }

                delegate: ItemDelegate {
                    required property var modelData
                    width: optionList.width
                    implicitHeight: secondaryText.implicitHeight > 0 ? 54 : 40
                    background: Rectangle {
                        radius: Appearance.rounding.small
                        color: root.itemValue(modelData) === root.currentValue ? Appearance.colors.colSecondaryContainer : "transparent"
                    }
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        MaterialSymbol {
                            visible: root.iconText(modelData).length > 0
                            text: root.iconText(modelData)
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: root.primaryText(modelData)
                                color: Appearance.colors.colOnSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                id: secondaryText
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: root.secondaryText(modelData)
                                color: Appearance.colors.colOnSurfaceVariant
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                            }
                        }
                        MaterialSymbol {
                            visible: root.itemValue(modelData) === root.currentValue
                            text: "check"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colPrimary
                        }
                    }
                    onClicked: {
                        root.selected(root.itemValue(modelData));
                        selectorPopup.close();
                    }
                }
            }

            StyledText {
                visible: optionList.count === 0
                text: root.sourceItems().length === 0 ? Translation.tr("No options available.") : Translation.tr("No matching options.")
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }
}
