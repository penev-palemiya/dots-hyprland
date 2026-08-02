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
    readonly property string appIcon: activity ? (activity.appIcon || "") : ""
    readonly property string metadataText: activity ? (activity.metadataText || "") : ""
    readonly property string primaryText: activity ? (activity.primaryText || "") : ""
    readonly property bool primaryMarquee: activity ? !!activity.primaryMarquee : false
    readonly property string actionIcon: activity ? (activity.actionIcon || "") : ""
    readonly property bool hasAction: actionIcon.length > 0 && activity && !!activity.primaryAction
    readonly property bool hasSecondaryPressAction: activity && !!activity.secondaryPressAction
    property real actionScale: hasAction ? 1 : 0

    implicitHeight: primaryRow.implicitHeight
    clip: true
    onHasActionChanged: actionScale = hasAction ? 1 : 0

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
            appIcon: root.appIcon
        }

        Row {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: Math.max(primaryTextSlot.implicitHeight, primaryActionButton.implicitHeight)
            spacing: 6
            clip: true

            IslandTextStack {
                id: primaryTextSlot

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - (primaryActionButton.visible ? primaryActionButton.width + parent.spacing : 0))
                metadataText: root.metadataText
                primaryText: root.primaryText
                primaryMarquee: root.primaryMarquee
            }

            RippleButton {
                id: primaryActionButton

                visible: root.hasAction || root.actionScale > 0.01
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: implicitHeight
                implicitHeight: 22
                scale: root.actionScale
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                onClicked: {
                    if (root.activity && root.activity.primaryAction)
                        root.activity.primaryAction();

                }

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    fill: 0
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSecondaryContainer
                    text: root.actionIcon
                }

            }

        }

    }

    Behavior on actionScale {
        NumberAnimation {
            duration: Appearance.animation.elementMoveSmall.duration
            easing.type: Appearance.animation.elementMoveSmall.type
            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
        }

    }

}
