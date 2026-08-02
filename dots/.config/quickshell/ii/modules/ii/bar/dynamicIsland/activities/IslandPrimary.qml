import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var activity
    readonly property string leadingKind: activity ? (activity.leadingKind || "icon") : "icon"
    readonly property string leadingIcon: activity ? (activity.leadingIcon || "") : ""
    readonly property color leadingIconColor: activity ? (activity.leadingIconColor || Appearance.m3colors.m3onSecondaryContainer) : Appearance.m3colors.m3onSecondaryContainer
    readonly property string leadingImage: activity ? (activity.leadingImage || "") : ""
    readonly property int leadingImageNotificationId: activity ? (activity.leadingImageNotificationId ?? -1) : -1
    readonly property string appIcon: activity ? (activity.appIcon || "") : ""
    readonly property string appIconImage: activity ? (activity.appIconImage || "") : ""
    readonly property string appIconUrl: activity ? (activity.appIconUrl || "") : ""
    readonly property string metadataText: activity ? (activity.metadataText || "") : ""
    readonly property string primaryText: activity ? (activity.primaryText || "") : ""
    readonly property bool primaryMarquee: activity ? !!activity.primaryMarquee : false
    readonly property string actionIcon: activity ? (activity.actionIcon || "") : ""
    readonly property bool hasSecondaryPressAction: activity && !!activity.hasSecondaryPressAction

    function triggerPrimaryAction() {
        if (root.activity && root.activity.primaryAction)
            root.activity.primaryAction();

    }

    implicitHeight: primaryRow.implicitHeight
    clip: true

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton
        onPressed: (event) => {
            if (root.hasSecondaryPressAction)
                root.activity.secondaryPressAction(event);

        }
    }

    RowLayout {
        id: primaryRow

        spacing: 6

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        IslandLeadingSlot {
            Layout.alignment: Qt.AlignVCenter
            leadingKind: root.leadingKind
            leadingIcon: root.leadingIcon
            leadingIconColor: root.leadingIconColor
            leadingImage: root.leadingImage
            notificationId: root.leadingImageNotificationId
            appIcon: root.appIcon
            appIconImage: root.appIconImage
            appIconUrl: root.appIconUrl
        }

        Row {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: Math.max(primaryTextSlot.implicitHeight, primaryActionSlot.implicitHeight)
            spacing: 6
            clip: true

            IslandTextStack {
                id: primaryTextSlot

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - primaryActionSlot.width - (primaryActionSlot.visible ? parent.spacing : 0))
                metadataText: root.metadataText
                primaryText: root.primaryText
                primaryMarquee: root.primaryMarquee
            }

            IslandActionSlot {
                id: primaryActionSlot

                anchors.verticalCenter: parent.verticalCenter
                iconName: root.actionIcon
                action: root.triggerPrimaryAction
            }

        }

    }

}
