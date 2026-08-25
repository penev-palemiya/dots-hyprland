import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings

/**
 * One setting: leading icon, title, optional description, trailing control.
 *
 * Shaped like a row of the Wi-Fi/Bluetooth popup lists (GroupedListCard): its
 * own small rounded block, gapped from its neighbours, with the group's first
 * and last row getting the large outer radius so the section still reads as
 * one shape. SettingsCard assigns the corner radii from each row's position -
 * this component just exposes them.
 *
 * The trailing control goes in the default slot, so any existing widget
 * (StyledSwitch, StyledComboBox, ConfigSpinBox, a button...) can be dropped in
 * without this component needing to know about it.
 *
 * Rows self-register into SettingsSearch, which is what makes settings
 * searchable without maintaining a separate index by hand.
 */
Rectangle {
    id: root

    property string icon: ""
    // Optional application/icon-theme image used by app-oriented settings rows.
    // The symbol remains the fallback when the image cannot be loaded.
    property string iconSource: ""
    property string title: ""
    property string description: ""
    // Extra search terms that a user might type but which don't appear in the
    // visible text (e.g. "nsfw" for a safety toggle, "wifi" for network).
    property string keywords: ""

    property bool clickable: false
    property bool registerInSearch: true

    // Split so a sub-row can push its text in from the left (to line up under
    // the row above) without also pushing its trailing control in from the
    // right - the two edges have no reason to move together.
    property real horizontalPadding: 20
    property real leftPadding: root.horizontalPadding
    property real rightPadding: root.horizontalPadding
    property real verticalPadding: 14
    property real iconColumnWidth: 34
    property real minimumHeight: 60

    property alias titleColor: titleText.color
    default property alias trailingContent: trailingContainer.data

    signal clicked()

    activeFocusOnTab: root.clickable && root.enabled
    Accessible.name: root.description.length > 0 ? `${root.title}, ${root.description}` : root.title
    Accessible.role: root.clickable ? Accessible.Button : Accessible.Text

    // Same radius scale as GroupedListCard/GroupedGrid (4 inside, 16 outside).
    // SettingsCard overwrites these once it knows the row's position; the
    // defaults just avoid a corner-radius pop on the first paint.
    readonly property real innerRadius: 4
    readonly property real outerRadius: 16
    topLeftRadius: root.innerRadius
    topRightRadius: root.innerRadius
    bottomLeftRadius: root.innerRadius
    bottomRightRadius: root.innerRadius

    color: Appearance.colors.colSurfaceContainerHighest
    clip: true

    Layout.fillWidth: true
    implicitWidth: rowLayout.implicitWidth + root.leftPadding + root.rightPadding
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

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Appearance.colors.colPrimary
        border.width: root.activeFocus ? 2 : 0
        radius: root.outerRadius
        z: 4
    }

    // M3 state layer rather than a ripple, matching GroupedListCard: a ripple
    // spreading across a 16px-cornered group edge looks wrong.
    Rectangle { // Hover/press state layer
        anchors.fill: parent
        // SettingsCard assigns outer corners to the first/last row and inner
        // corners between rows. The state layer must mirror them exactly;
        // rectangular clipping would visibly square off the hover treatment.
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Appearance.colors.colOnSurface
        visible: root.clickable && root.enabled
        opacity: rowMouseArea.containsMouse ? (rowMouseArea.pressed ? 0.1 : 0.06) : 0

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    MouseArea {
        id: rowMouseArea
        anchors.fill: parent
        // This must be above the trailing controls. Otherwise a Qt Control
        // such as StyledSwitch can receive hover while the row's state layer
        // remains owned by a neighbouring row.
        z: 3
        hoverEnabled: root.clickable
        enabled: root.clickable && root.enabled
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Keys.onEnterPressed: if (root.clickable && root.enabled) root.clicked()
    Keys.onReturnPressed: if (root.clickable && root.enabled) root.clicked()
    Keys.onSpacePressed: if (root.clickable && root.enabled) root.clicked()

    RowLayout {
        id: rowLayout
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: root.leftPadding
            rightMargin: root.rightPadding
        }
        spacing: 16

        Item { // Icon column, reserved even when empty so text stays aligned
            Layout.alignment: Qt.AlignVCenter
            visible: root.icon.length > 0 || root.iconSource.length > 0
            implicitWidth: root.iconColumnWidth
            implicitHeight: iconWidget.implicitHeight

            MaterialSymbol {
                id: iconWidget
                anchors.centerIn: parent
                text: root.icon
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnSurfaceVariant
                opacity: root.enabled ? 1 : 0.4
                visible: root.iconSource.length === 0 || appIcon.status === Image.Error
            }

            Image {
                id: appIcon
                anchors.centerIn: parent
                source: root.iconSource
                sourceSize.width: Appearance.font.pixelSize.huge
                sourceSize.height: Appearance.font.pixelSize.huge
                width: Appearance.font.pixelSize.huge
                height: Appearance.font.pixelSize.huge
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: root.iconSource.length > 0 && status !== Image.Error
                opacity: root.enabled ? 1 : 0.4
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            // Keep a real text column even when the trailing slot is empty or
            // its child reports only an implicit size. Without a preferred
            // width some Qt layout passes can collapse this fill item to 0.
            Layout.minimumWidth: 1
            Layout.preferredWidth: 1
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
                color: Appearance.colors.colOnSurfaceVariant
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
