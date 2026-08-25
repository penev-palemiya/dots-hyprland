import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    radius: Appearance.rounding.small
    color: Appearance.colors.colSurfaceContainerHigh

    implicitWidth: 220
    implicitHeight: mainColumn.implicitHeight + 24

    property alias title: title.text
    property alias symbol: symbol.text
    property alias valueText: value.text
    property alias subtitleText: subtitle.text
    property alias subtitleText2: subtitle2.text
    property real percentage: 0
    property bool warning: false

    ColumnLayout {
        id: mainColumn
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: iconContainer
                width: Appearance.font.pixelSize.large * 2
                height: Appearance.font.pixelSize.large * 2
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHighest ?? Appearance.colors.colSurfaceVariant

                Layout.alignment: Qt.AlignVCenter

                MaterialSymbol {
                    id: symbol
                    anchors.centerIn: parent
                    fill: 0
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSurface
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                StyledText {
                    id: title
                    font {
                        pixelSize: Appearance.font.pixelSize.smaller
                        weight: Font.Normal
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                }

                StyledText {
                    id: value
                    font {
                        pixelSize: Appearance.font.pixelSize.small
                        weight: Font.Bold
                    }
                    color: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                StyledText {
                    id: subtitle
                    Layout.alignment: Qt.AlignRight
                    font {
                        pixelSize: Appearance.font.pixelSize.smaller
                        weight: Font.Normal
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                }

                StyledText {
                    id: subtitle2
                    visible: text.length > 0
                    Layout.alignment: Qt.AlignRight
                    font {
                        pixelSize: Appearance.font.pixelSize.smaller
                        weight: Font.Normal
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            id: barTrack
            Layout.fillWidth: true
            implicitHeight: 6
            radius: height / 2
            color: Appearance.colors.colSurfaceContainerHighest

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.percentage))
                height: parent.height
                radius: height / 2
                color: root.warning ? Appearance.colors.colError : Appearance.colors.colPrimary

                Behavior on width {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }
    }
}
