import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * The pill-shaped search field in the app header.
 */
Rectangle {
    id: root

    property alias text: input.text
    property string placeholderText: Translation.tr("Search settings")

    signal accepted()
    signal escaped()

    implicitHeight: 46
    radius: Appearance.rounding.full
    color: input.activeFocus ? Appearance.colors.colSurfaceContainerHigh : Appearance.colors.colSurfaceContainer
    border.width: 1
    border.color: input.activeFocus ? Appearance.colors.colPrimary : "transparent"

    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }
    Behavior on border.color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    function forceSearchFocus() {
        input.forceActiveFocus();
        input.selectAll();
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 18
            rightMargin: 8
        }
        spacing: 12

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: "search"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSurfaceVariant
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: Appearance.colors.colOnSurface
                selectionColor: Appearance.colors.colSecondaryContainer
                selectedTextColor: Appearance.colors.colOnSecondaryContainer
                selectByMouse: true
                renderType: Text.NativeRendering
                font {
                    family: Appearance.font.family.main
                    pixelSize: Appearance.font.pixelSize.normal
                    variableAxes: Appearance.font.variableAxes.main
                }

                onAccepted: root.accepted()
                Keys.onEscapePressed: root.escaped()

                StyledText {
                    anchors.fill: parent
                    visible: input.text.length === 0
                    text: root.placeholderText
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
            }
        }

        RippleButton { // Clear
            Layout.alignment: Qt.AlignVCenter
            visible: input.text.length > 0
            implicitWidth: 32
            implicitHeight: 32
            buttonRadius: Appearance.rounding.full
            onClicked: {
                input.clear();
                input.forceActiveFocus();
            }
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: "close"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }
}
