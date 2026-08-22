import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string currentValue: ""
    property list<string> options: []
    property string placeholder: Translation.tr("Select")
    property string searchPlaceholder: Translation.tr("Search")
    signal selected(string value)

    implicitWidth: 300
    implicitHeight: 40

    function filteredOptions() {
        const query = searchField.text.trim().toLowerCase();
        if (query === "") return root.options;
        return root.options.filter(value => value.toLowerCase().includes(query));
    }

    RippleButton {
        anchors.fill: parent
        enabled: root.enabled
        buttonRadius: height / 2
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colBackgroundToggled: Appearance.colors.colSecondaryContainerActive
        onClicked: {
            searchField.text = "";
            selectorPopup.open();
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
        width: Math.min(Math.max(root.width, 360), (root.Window.window?.width ?? 800) - 16)
        height: Math.min(selectorColumn.implicitHeight + 16, 420)
        padding: 8

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
                onTextChanged: optionList.model = root.filteredOptions()
            }

            StyledListView {
                id: optionList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.filteredOptions()

                delegate: ItemDelegate {
                    required property string modelData
                    width: optionList.width
                    implicitHeight: 40
                    background: Rectangle {
                        radius: Appearance.rounding.small
                        color: modelData === root.currentValue ? Appearance.colors.colSecondaryContainer : "transparent"
                    }
                    contentItem: StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        text: modelData
                        color: Appearance.colors.colOnSurface
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: {
                        root.selected(modelData);
                        selectorPopup.close();
                    }
                }
            }
        }
    }
}
