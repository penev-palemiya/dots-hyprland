import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings

/**
 * One setting: leading icon, title, optional description, trailing control.
 *
 * The trailing control goes in the default slot, so any existing widget
 * (StyledSwitch, StyledComboBox, ConfigSpinBox, a button...) can be dropped in
 * without this component needing to know about it.
 *
 * Rows self-register into SettingsSearch, which is what makes settings
 * searchable without maintaining a separate index by hand.
 */
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string description: ""
    // Extra search terms that a user might type but which don't appear in the
    // visible text (e.g. "nsfw" for a safety toggle, "wifi" for network).
    property string keywords: ""

    property bool clickable: false
    property bool showTopDivider: false
    // Sub-rows inset their divider so it lines up with the text column instead
    // of running the full width of the card.
    property real dividerInset: 0
    property bool registerInSearch: true

    property real horizontalPadding: 20
    property real verticalPadding: 14
    property real iconColumnWidth: 34
    property real minimumHeight: 60

    property alias titleColor: titleText.color
    default property alias trailingContent: trailingContainer.data

    signal clicked()

    Layout.fillWidth: true
    implicitWidth: rowLayout.implicitWidth + root.horizontalPadding * 2
    implicitHeight: Math.max(root.minimumHeight, rowLayout.implicitHeight + root.verticalPadding * 2)

    // Pulsed by the search results list so a jumped-to setting is easy to spot.
    function flashHighlight() {
        highlightAnim.restart();
    }

    Rectangle { // Search-jump highlight
        id: highlightRect
        anchors.fill: parent
        color: Appearance.colors.colPrimaryContainer
        opacity: 0
        radius: Appearance.rounding.small

        SequentialAnimation {
            id: highlightAnim
            NumberAnimation {
                target: highlightRect
                property: "opacity"
                to: 0.7
                duration: 120
                easing.type: Easing.OutCubic
            }
            PauseAnimation { duration: 700 }
            NumberAnimation {
                target: highlightRect
                property: "opacity"
                to: 0
                duration: 600
                easing.type: Easing.InCubic
            }
        }
    }

    Rectangle { // Hover/press state layer
        anchors.fill: parent
        color: Appearance.colors.colOnSurface
        radius: Appearance.rounding.small
        visible: root.clickable && root.enabled
        opacity: rowMouseArea.containsMouse ? (rowMouseArea.pressed ? 0.1 : 0.06) : 0

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    MouseArea {
        id: rowMouseArea
        anchors.fill: parent
        hoverEnabled: root.clickable
        enabled: root.clickable && root.enabled
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Rectangle { // Separator from the row above
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: root.dividerInset
        }
        height: 1
        visible: root.showTopDivider
        color: Appearance.colors.colOutlineVariant
    }

    RowLayout {
        id: rowLayout
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 16

        Item { // Icon column, reserved even when empty so text stays aligned
            Layout.alignment: Qt.AlignVCenter
            visible: root.icon.length > 0
            implicitWidth: root.iconColumnWidth
            implicitHeight: iconWidget.implicitHeight

            MaterialSymbol {
                id: iconWidget
                anchors.centerIn: parent
                text: root.icon
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnSurfaceVariant
                opacity: root.enabled ? 1 : 0.4
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                id: titleText
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurface
                opacity: root.enabled ? 1 : 0.4
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                opacity: root.enabled ? 1 : 0.4
                wrapMode: Text.WordWrap
            }
        }

        Item { // Trailing control slot
            id: trailingContainer
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            opacity: root.enabled ? 1 : 0.4
        }
    }

    // Registration is synchronous, but deliberately records only the row itself
    // for locating it later. Which page and section it belongs to is resolved on
    // demand (see SettingsSearch.resolveContext), because the enclosing page
    // doesn't learn its own index until its Loader fires onLoaded - which is
    // after this point.
    Component.onCompleted: {
        if (!root.registerInSearch || root.title.length === 0)
            return;
        SettingsSearch.register({
            "title": root.title,
            "description": root.description,
            "keywords": root.keywords,
            "icon": root.icon,
            "target": root
        });
    }

    Component.onDestruction: {
        if (root.registerInSearch)
            SettingsSearch.unregister(root);
    }
}
