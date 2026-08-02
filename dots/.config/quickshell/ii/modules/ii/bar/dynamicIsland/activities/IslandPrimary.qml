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
    readonly property bool valueIndicatorVisible: activity ? !!activity.valueIndicatorVisible : false
    readonly property real valueIndicatorValue: activity ? (activity.valueIndicatorValue ?? 0) : 0
    readonly property color valueIndicatorColor: activity ? (activity.valueIndicatorColor || Appearance.colors.colOnSecondaryContainer) : Appearance.colors.colOnSecondaryContainer
    readonly property color valueIndicatorTrackColor: activity ? (activity.valueIndicatorTrackColor || Appearance.colors.colSecondaryContainer) : Appearance.colors.colSecondaryContainer
    readonly property string actionIcon: activity ? (activity.actionIcon || "") : ""
    readonly property string secondaryActionIcon: activity ? (activity.secondaryActionIcon || "") : ""
    readonly property bool hasSecondaryPressAction: activity && !!activity.hasSecondaryPressAction

    function triggerPrimaryAction() {
        if (root.activity && root.activity.primaryAction)
            root.activity.primaryAction();

    }

    function triggerSecondaryAction() {
        if (root.activity && root.activity.secondaryAction)
            root.activity.secondaryAction();

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
            height: Math.max(primaryTextSlot.implicitHeight, primaryValueSlot.implicitHeight, primaryActionSlot.implicitHeight, secondaryActionSlot.implicitHeight)
            spacing: 6
            clip: true

            IslandTextStack {
                id: primaryTextSlot

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - primaryValueSlot.width - primaryActionSlot.width - secondaryActionSlot.width - (primaryValueSlot.visible ? parent.spacing : 0) - (primaryActionSlot.visible ? parent.spacing : 0) - (secondaryActionSlot.visible ? parent.spacing : 0))
                metadataText: root.metadataText
                primaryText: root.primaryText
                primaryMarquee: root.primaryMarquee
            }

            IslandValueSlot {
                id: primaryValueSlot

                anchors.verticalCenter: parent.verticalCenter
                active: root.valueIndicatorVisible
                value: root.valueIndicatorValue
                fillColor: root.valueIndicatorColor
                trackColor: root.valueIndicatorTrackColor
            }

            IslandActionSlot {
                id: primaryActionSlot

                anchors.verticalCenter: parent.verticalCenter
                iconName: root.actionIcon
                action: root.triggerPrimaryAction
            }

            IslandActionSlot {
                id: secondaryActionSlot

                anchors.verticalCenter: parent.verticalCenter
                iconName: root.secondaryActionIcon
                action: root.triggerSecondaryAction
            }

        }

    }

}
