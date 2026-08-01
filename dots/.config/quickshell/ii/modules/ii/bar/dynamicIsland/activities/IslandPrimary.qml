import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

IslandActivityRow {
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
    readonly property bool hasAction: actionIcon.length > 0 && activity && activity.primaryAction

    icon: leadingKind === "icon" ? leadingIcon : ""
    iconColor: leadingIconColor
    iconOverride: leadingKind === "avatar" ? avatarComponent : null

    Component {
        id: avatarComponent
        Item {
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Appearance.colors.colSecondaryContainer
                clip: true

                Image {
                    anchors.fill: parent
                    visible: root.leadingImage.length > 0
                    source: root.leadingImage
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: root.leadingImage.length === 0
                    fill: 1
                    text: root.leadingIcon || "person"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }

            Rectangle {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                width: 12
                height: 12
                radius: width / 2
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colLayer1
                clip: true
                visible: root.appIcon.length > 0

                IconImage {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: Quickshell.iconPath(root.appIcon, "image-missing")
                }
            }
        }
    }

    Row {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: Math.max(primaryTextSlot.implicitHeight, primaryActionButton.implicitHeight)
        spacing: 6
        clip: true

        IslandCompactText {
            id: primaryTextSlot
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - (primaryActionButton.visible ? primaryActionButton.width + parent.spacing : 0))
            metadataText: root.metadataText
            primaryText: root.primaryText
            primaryMarquee: root.primaryMarquee
        }

        RippleButton {
            id: primaryActionButton
            visible: root.hasAction
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: implicitHeight
            implicitHeight: 22
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                fill: 0
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSecondaryContainer
                text: root.actionIcon
            }

            onClicked: {
                if (root.activity && root.activity.primaryAction)
                    root.activity.primaryAction();
            }
        }
    }
}
