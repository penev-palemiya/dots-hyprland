import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar.weather

StyledPopup {
    id: root

    property string weekday: Qt.locale().toString(DateTime.clock.date, "dddd")
    property string fullDate: Qt.locale().toString(DateTime.clock.date, "MMMM dd, yyyy")
    property var pendingTodos: Todo.list.filter(item => !item.done)

    Item {
        anchors.centerIn: parent
        implicitWidth: columnLayout.implicitWidth + 8
        implicitHeight: columnLayout.implicitHeight + 8

        ColumnLayout {
            id: columnLayout
            anchors.centerIn: parent
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                ColumnLayout {
                    Layout.alignment: Qt.AlignLeft
                    spacing: 0

                    StyledText {
                        text: root.weekday
                        font {
                            weight: Font.Bold
                            pixelSize: Appearance.font.pixelSize.small
                        }
                        color: Appearance.colors.colOnSurface
                    }

                    StyledText {
                        text: root.fullDate
                        font {
                            weight: Font.Normal
                            pixelSize: Appearance.font.pixelSize.smaller
                        }
                        color: Appearance.colors.colOutline
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: DateTime.time
                    font {
                        weight: Font.Bold
                        pixelSize: Appearance.font.pixelSize.small * 2
                    }
                    color: Appearance.colors.colOnSurface
                }
            }

            WeatherCard {
                Layout.fillWidth: true
                title: Translation.tr("System uptime")
                symbol: "timelapse"
                value: DateTime.uptime
            }

            // To Do card
            Rectangle {
                Layout.fillWidth: true
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHigh
                implicitWidth: todoColumn.implicitWidth + 24
                implicitHeight: todoColumn.implicitHeight + 20

                ColumnLayout {
                    id: todoColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialSymbol {
                            text: "checklist"
                            fill: 0
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            text: Translation.tr("To Do")
                            font {
                                weight: Font.Bold
                                pixelSize: Appearance.font.pixelSize.small
                            }
                            color: Appearance.colors.colOnSurface
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            visible: root.pendingTodos.length > 0
                            text: root.pendingTodos.length
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOutline
                        }
                    }

                    StyledText {
                        visible: root.pendingTodos.length === 0
                        text: Translation.tr("No pending tasks")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOutline
                    }

                    Repeater {
                        model: root.pendingTodos.slice(0, 5)
                        delegate: RowLayout {
                            id: todoRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "radio_button_unchecked"
                                fill: 0
                                iconSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOutline
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: todoRow.modelData.content
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSurface
                            }
                        }
                    }

                    StyledText {
                        visible: root.pendingTodos.length > 5
                        text: Translation.tr("... and %1 more").arg(root.pendingTodos.length - 5)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOutline
                    }
                }
            }
        }
    }
}
