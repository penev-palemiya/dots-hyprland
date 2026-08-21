import QtQuick
import QtQuick.Layouts
import qs.modules.common

/**
 * Container for one section's rows, styled like the Wi-Fi/Bluetooth popup
 * lists: each row is its own small rounded block (see SettingsRow), gapped
 * 4px apart, with the first and last row getting the large outer radius so
 * the whole section still reads as one shape. A lone row gets outer radius
 * on all four corners - a single-item group is a full rounded card, not a
 * clipped fragment.
 *
 * Purely a layout wrapper - it draws nothing itself, since each row paints
 * its own background.
 */
Item {
    id: root

    default property alias contentData: contentColumn.data

    readonly property real innerRadius: 4
    readonly property real outerRadius: 16
    readonly property real rowSpacing: 4

    Layout.fillWidth: true
    implicitHeight: contentColumn.implicitHeight

    // Re-run whenever a row's visibility changes, not just when rows are
    // added/removed - a hidden row must not claim the outer radius.
    function updateCorners() {
        const rows = [];
        for (let i = 0; i < contentColumn.children.length; i++) {
            const child = contentColumn.children[i];
            if (child.topLeftRadius === undefined || !child.visible)
                continue;
            rows.push(child);
        }
        for (let i = 0; i < rows.length; i++) {
            const isFirst = i === 0;
            const isLast = i === rows.length - 1;
            rows[i].topLeftRadius = isFirst ? root.outerRadius : root.innerRadius;
            rows[i].topRightRadius = isFirst ? root.outerRadius : root.innerRadius;
            rows[i].bottomLeftRadius = isLast ? root.outerRadius : root.innerRadius;
            rows[i].bottomRightRadius = isLast ? root.outerRadius : root.innerRadius;
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: root.rowSpacing

        onChildrenChanged: Qt.callLater(root.updateCorners)
    }

    Component.onCompleted: root.updateCorners()
}
