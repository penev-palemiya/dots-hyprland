import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    property var timezones: []
    property string currentTimezone: ""
    property string query: ""
    signal selected(string timezone)
    signal canceled()

    Layout.fillWidth: true
    spacing: 12

    function offsetLabel(zone) {
        if (zone !== root.currentTimezone)
            return "";
        const minutes = -new Date().getTimezoneOffset();
        const sign = minutes >= 0 ? "+" : "-";
        const absolute = Math.abs(minutes);
        const hours = Math.floor(absolute / 60);
        const mins = absolute % 60;
        return `UTC${sign}${hours.toString().padStart(2, "0")}:${mins.toString().padStart(2, "0")}`;
    }

    function filtered() {
        const needle = root.query.trim().toLowerCase();
        return (root.timezones || []).filter(zone => {
            const value = String(zone);
            return needle.length === 0 || value.toLowerCase().includes(needle);
        });
    }

    RowLayout {
        Layout.fillWidth: true
        ToolButton {
            display: AbstractButton.IconOnly
            Accessible.name: Translation.tr("Back")
            onClicked: root.canceled()
            contentItem: MaterialSymbol {
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnSurface
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Select time zone")
            font.pixelSize: Appearance.font.pixelSize.title
            color: Appearance.colors.colOnSurface
        }
    }

    MaterialTextField {
        Layout.fillWidth: true
        placeholderText: Translation.tr("Search time zones")
        Accessible.name: Translation.tr("Search time zones")
        text: root.query
        onTextChanged: if (text !== root.query) root.query = text
    }

    StyledListView {
        id: timezoneList
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: root.filtered()
        clip: true
        spacing: 2
        delegate: ItemDelegate {
            required property string modelData
            width: timezoneList.width
            implicitHeight: 58
            background: Rectangle {
                radius: Appearance.rounding.small
                color: modelData === root.currentTimezone ? Appearance.colors.colSecondaryContainer : "transparent"
            }
            contentItem: RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
                MaterialSymbol {
                    text: "public"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData
                        color: Appearance.colors.colOnSurface
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.offsetLabel(modelData).length > 0
                        text: root.offsetLabel(modelData)
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }
                MaterialSymbol {
                    visible: modelData === root.currentTimezone
                    text: "check"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }
            }
            onClicked: root.selected(modelData)
        }
    }

    StyledText {
        visible: timezoneList.count === 0
        Layout.fillWidth: true
        text: root.timezones.length === 0
            ? Translation.tr("Time zones are unavailable.")
            : Translation.tr("No matching time zones.")
        color: Appearance.colors.colOnSurfaceVariant
    }

    Keys.onEscapePressed: root.canceled()
}
