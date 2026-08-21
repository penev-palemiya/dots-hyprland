import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Scrollable body of one settings page: a title header, then groups of settings.
 *
 * Publishes settingsPageIndex/settingsPageName so rows nested anywhere inside
 * can attribute themselves to this page when registering for search.
 */
StyledFlickable {
    id: root

    property string pageTitle: ""
    property int settingsPageIndex: -1
    property string settingsPageName: root.pageTitle
    property real sidePadding: 24
    property real bottomPadding: 60

    default property alias pageContent: contentColumn.data

    clip: true
    contentHeight: contentColumn.implicitHeight + root.bottomPadding

    // Brings a row registered in search into view, then pulses it.
    function revealRow(row) {
        if (!row)
            return;
        const rowY = row.mapToItem(contentColumn, 0, 0).y;
        const target = Math.max(0, Math.min(rowY - height / 3, Math.max(0, contentHeight - height)));
        root.contentY = target;
        row.flashHighlight();
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 28
            leftMargin: root.sidePadding
            rightMargin: root.sidePadding
        }
        spacing: 28

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            Layout.leftMargin: 4
            visible: root.pageTitle.length > 0
            text: root.pageTitle
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.huge
                variableAxes: Appearance.font.variableAxes.title
            }
            color: Appearance.colors.colOnSurface
        }
    }
}
