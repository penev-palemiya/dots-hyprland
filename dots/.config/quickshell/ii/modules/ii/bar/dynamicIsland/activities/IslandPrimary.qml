import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
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
    readonly property string visualKey: activity ? `${activity.activityId}:${leadingKind}:${leadingIcon}:${leadingImage}:${appIcon}` : ""
    readonly property string textKey: `${metadataText}:${primaryText}`
    property bool initialized: false
    property string displayedMetadataText: metadataText
    property string displayedPrimaryText: primaryText
    property bool displayedPrimaryMarquee: primaryMarquee
    property string outgoingMetadataText: ""
    property string outgoingPrimaryText: ""
    property bool outgoingPrimaryMarquee: false
    property real incomingTextOpacity: 1
    property real outgoingTextOpacity: 0
    property real incomingTextOffset: 0
    property real outgoingTextOffset: 0
    property real actionScale: hasAction ? 1 : 0
    property real leadingOpacity: 1
    property real leadingScale: 1

    implicitHeight: primaryRow.implicitHeight
    clip: true
    Component.onCompleted: {
        displayedMetadataText = metadataText;
        displayedPrimaryText = primaryText;
        displayedPrimaryMarquee = primaryMarquee;
        initialized = true;
    }
    onTextKeyChanged: {
        if (initialized) {
            outgoingMetadataText = displayedMetadataText;
            outgoingPrimaryText = displayedPrimaryText;
            outgoingPrimaryMarquee = displayedPrimaryMarquee;
            displayedMetadataText = metadataText;
            displayedPrimaryText = primaryText;
            displayedPrimaryMarquee = primaryMarquee;
            textSwapAnimation.restart();
        } else {
            displayedMetadataText = metadataText;
            displayedPrimaryText = primaryText;
            displayedPrimaryMarquee = primaryMarquee;
        }
    }
    onVisualKeyChanged: {
        if (initialized)
            leadingSwapAnimation.restart();

    }
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

        Rectangle {
            id: leadingSlot

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 26
            implicitHeight: 26
            radius: Appearance.rounding.full
            color: Appearance.colors.colSecondaryContainer
            clip: true
            opacity: root.leadingOpacity
            scale: root.leadingScale

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.leadingKind !== "avatar"
                fill: 1
                iconSize: Appearance.font.pixelSize.normal
                color: root.leadingIconColor
                text: root.leadingIcon

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

            }

            Item {
                anchors.fill: parent
                visible: root.leadingKind === "avatar"

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
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
                    width: 12
                    height: 12
                    radius: width / 2
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colLayer1
                    clip: true
                    visible: root.appIcon.length > 0

                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }

                    IconImage {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: Quickshell.iconPath(root.appIcon, "image-missing")
                    }

                }

            }

        }

        Row {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: Math.max(primaryTextSlot.implicitHeight, primaryActionButton.implicitHeight)
            spacing: 6
            clip: true

            Item {
                id: primaryTextStack

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - (primaryActionButton.visible ? primaryActionButton.width + parent.spacing : 0))
                height: primaryTextSlot.implicitHeight
                clip: true

                IslandCompactText {
                    id: outgoingPrimaryTextSlot

                    width: parent.width
                    opacity: root.outgoingTextOpacity
                    metadataText: root.outgoingMetadataText
                    primaryText: root.outgoingPrimaryText
                    primaryMarquee: root.outgoingPrimaryMarquee

                    transform: Translate {
                        y: root.outgoingTextOffset
                    }

                }

                IslandCompactText {
                    id: primaryTextSlot

                    width: parent.width
                    opacity: root.incomingTextOpacity
                    metadataText: root.displayedMetadataText
                    primaryText: root.displayedPrimaryText
                    primaryMarquee: root.displayedPrimaryMarquee

                    transform: Translate {
                        y: root.incomingTextOffset
                    }

                }

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

    SequentialAnimation {
        id: leadingSwapAnimation

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "leadingOpacity"
                to: 0.4
                duration: Appearance.animation.elementMoveFast.duration / 2
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }

            NumberAnimation {
                target: root
                property: "leadingScale"
                to: 0.86
                duration: Appearance.animation.elementMoveFast.duration / 2
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }

        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "leadingOpacity"
                to: 1
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Appearance.animation.elementMoveSmall.type
                easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
            }

            NumberAnimation {
                target: root
                property: "leadingScale"
                to: 1
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Appearance.animation.elementMoveSmall.type
                easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
            }

        }

    }

    ParallelAnimation {
        id: textSwapAnimation

        PropertyAction {
            target: root
            property: "incomingTextOpacity"
            value: 0
        }

        PropertyAction {
            target: root
            property: "incomingTextOffset"
            value: 5
        }

        PropertyAction {
            target: root
            property: "outgoingTextOpacity"
            value: 0.65
        }

        PropertyAction {
            target: root
            property: "outgoingTextOffset"
            value: 0
        }

        NumberAnimation {
            target: root
            property: "incomingTextOpacity"
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "incomingTextOffset"
            to: 0
            duration: Appearance.animation.elementMoveSmall.duration
            easing.type: Appearance.animation.elementMoveSmall.type
            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "outgoingTextOpacity"
            to: 0
            duration: Appearance.animation.elementMoveFast.duration / 2
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "outgoingTextOffset"
            to: -5
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
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
