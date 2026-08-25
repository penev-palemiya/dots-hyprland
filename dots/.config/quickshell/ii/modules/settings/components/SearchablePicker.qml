import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var sourceItems: []
    property string currentValue: ""
    property string currentText: ""
    property string placeholder: Translation.tr("Select")
    property string searchPlaceholder: Translation.tr("Search")
    property string query: ""
    property string emptyText: Translation.tr("No options available.")
    property string noResultsText: Translation.tr("No matching options.")
    property var itemValue: item => typeof item === "string" ? item : String(item && (item.value !== undefined ? item.value : (item.primaryText !== undefined ? item.primaryText : "")))
    property var primaryText: item => typeof item === "string" ? item : String(item && (item.primaryText || item.label || root.itemValue(item)))
    property var secondaryText: item => typeof item === "string" ? "" : String(item && (item.secondaryText || ""))
    property var iconText: item => typeof item === "string" ? "" : String(item && (item.icon || ""))
    property var sortItems: values => values
    signal picked(var item)

    implicitWidth: 300
    implicitHeight: 40
    activeFocusOnTab: true

    function filteredItems() {
        const values = root.sortItems((root.sourceItems || []).slice());
        const needle = root.query.trim().toLowerCase();
        return needle
            ? values.filter(item => `${root.primaryText(item)} ${root.secondaryText(item)} ${root.itemValue(item)}`.toLowerCase().includes(needle))
            : values;
    }

    function commitCurrentItem() {
        if (optionList.currentIndex < 0 || optionList.currentIndex >= optionList.model.length)
            return;
        root.picked(optionList.model[optionList.currentIndex]);
        selectorPopup.close();
    }

    RippleButton {
        id: trigger
        anchors.fill: parent
        enabled: root.enabled
        activeFocusOnTab: true
        leftPadding: 16
        rightPadding: 12
        spacing: 8
        opacity: enabled ? 1 : 0.38
        Accessible.name: root.currentText || root.placeholder
        buttonRadius: height / 2
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colBackgroundToggled: Appearance.colors.colSecondaryContainerActive
        onClicked: {
            root.query = "";
            selectorPopup.open();
            Qt.callLater(() => searchField.forceActiveFocus());
        }

        contentItem: RowLayout {
            spacing: trigger.spacing

            StyledText {
                Layout.fillWidth: true
                text: root.currentText || root.placeholder
                color: Appearance.colors.colOnSecondaryContainer
                elide: Text.ElideRight
            }

            MaterialSymbol {
                text: "keyboard_arrow_down"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnSecondaryContainer
                rotation: selectorPopup.visible ? 180 : 0

                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            z: 1
            visible: trigger.activeFocus
            radius: trigger.buttonRadius
            color: "transparent"
            border.width: 2
            border.color: Appearance.colors.colPrimary
        }
    }

    Popup {
        id: selectorPopup
        y: root.height + 4
        width: Math.min(Math.max(root.width, 360), (root.Window.window ? root.Window.window.width : 800) - 16)
        implicitHeight: Math.min(selectorColumn.implicitHeight + topPadding + bottomPadding, 420)
        padding: 8
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: {
            searchField.forceActiveFocus();
            const index = optionList.model.findIndex(item => root.itemValue(item) === root.currentValue);
            optionList.currentIndex = index >= 0 ? index : 0;
            if (index >= 0)
                optionList.positionViewAtIndex(index, ListView.Visible);
        }
        onClosed: Qt.callLater(() => trigger.forceActiveFocus())

        background: Rectangle {
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerHigh
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
                text: root.query
                onTextChanged: {
                    if (text !== root.query)
                        root.query = text;
                    optionList.currentIndex = 0;
                }
                Keys.onDownPressed: if (optionList.count > 0) optionList.incrementCurrentIndex()
                Keys.onUpPressed: if (optionList.count > 0) optionList.decrementCurrentIndex()
                Keys.onReturnPressed: root.commitCurrentItem()
                Keys.onEscapePressed: selectorPopup.close()
            }

            StyledListView {
                id: optionList
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.min(contentHeight, 320)
                clip: true
                spacing: 2
                model: root.filteredItems()
                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Visible)
                delegate: SearchablePickerOption {
                    required property var modelData
                    width: optionList.width
                    primaryText: root.primaryText(modelData)
                    secondaryText: root.secondaryText(modelData)
                    iconText: root.iconText(modelData)
                    selected: root.itemValue(modelData) === root.currentValue
                    keyboardCurrent: ListView.isCurrentItem
                    onClicked: {
                        root.picked(modelData);
                        selectorPopup.close();
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: optionList.count === 0
                text: root.sourceItems.length === 0 ? root.emptyText : root.noResultsText
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }
}
