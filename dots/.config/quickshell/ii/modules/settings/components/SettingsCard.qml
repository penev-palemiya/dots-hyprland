import QtQuick
import QtQuick.Layouts
import qs.modules.common

/**
 * Rounded surface holding a stack of SettingsRows, with dividers drawn between
 * consecutive visible rows.
 *
 * Dividers are assigned by the card rather than each row deciding for itself,
 * because "am I the first visible row?" is not something a row can answer
 * reliably on its own. If a page toggles a row's visibility at runtime, call
 * updateDividers() so the top divider lands on the right row.
 */
Rectangle {
    id: root

    default property alias contentData: contentColumn.data

    Layout.fillWidth: true
    implicitHeight: contentColumn.implicitHeight
    color: Appearance.colors.colSurfaceContainerLow
    radius: Appearance.rounding.normal
    clip: true

    function updateDividers() {
        let seenVisibleRow = false;
        for (let i = 0; i < contentColumn.children.length; i++) {
            const child = contentColumn.children[i];
            if (child.showTopDivider === undefined)
                continue;
            if (!child.visible)
                continue;
            // Sub-rows always keep their divider: it separates them from the
            // row they belong to, so it's never the card's top edge.
            if (child.dividerInset > 0) {
                seenVisibleRow = true;
                continue;
            }
            child.showTopDivider = seenVisibleRow;
            seenVisibleRow = true;
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: 0

        onChildrenChanged: Qt.callLater(root.updateDividers)
    }

    Component.onCompleted: root.updateDividers()
}
