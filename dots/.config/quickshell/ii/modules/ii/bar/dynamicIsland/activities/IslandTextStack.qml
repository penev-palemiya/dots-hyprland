import QtQuick
import qs.modules.common

Item {
    id: root

    property string metadataText: ""
    property string primaryText: ""
    property bool primaryMarquee: false
    readonly property string textKey: `${metadataText}:${primaryText}`
    property bool initialized: false
    property string displayedMetadataText: metadataText
    property string displayedPrimaryText: primaryText
    property bool displayedPrimaryMarquee: primaryMarquee
    property string outgoingMetadataText: ""
    property string outgoingPrimaryText: ""
    property bool outgoingPrimaryMarquee: false
    property real incomingOpacity: 1
    property real outgoingOpacity: 0
    property real incomingOffset: 0
    property real outgoingOffset: 0

    implicitHeight: incomingText.implicitHeight
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
            swapAnimation.restart();
        } else {
            displayedMetadataText = metadataText;
            displayedPrimaryText = primaryText;
            displayedPrimaryMarquee = primaryMarquee;
        }
    }

    IslandCompactText {
        id: outgoingText

        width: parent.width
        opacity: root.outgoingOpacity
        metadataText: root.outgoingMetadataText
        primaryText: root.outgoingPrimaryText
        primaryMarquee: root.outgoingPrimaryMarquee

        transform: Translate {
            y: root.outgoingOffset
        }

    }

    IslandCompactText {
        id: incomingText

        width: parent.width
        opacity: root.incomingOpacity
        metadataText: root.displayedMetadataText
        primaryText: root.displayedPrimaryText
        primaryMarquee: root.displayedPrimaryMarquee

        transform: Translate {
            y: root.incomingOffset
        }

    }

    ParallelAnimation {
        id: swapAnimation

        PropertyAction {
            target: root
            property: "incomingOpacity"
            value: 0
        }

        PropertyAction {
            target: root
            property: "incomingOffset"
            value: 5
        }

        PropertyAction {
            target: root
            property: "outgoingOpacity"
            value: 0.65
        }

        PropertyAction {
            target: root
            property: "outgoingOffset"
            value: 0
        }

        NumberAnimation {
            target: root
            property: "incomingOpacity"
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "incomingOffset"
            to: 0
            duration: Appearance.animation.elementMoveSmall.duration
            easing.type: Appearance.animation.elementMoveSmall.type
            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "outgoingOpacity"
            to: 0
            duration: Appearance.animation.elementMoveFast.duration / 2
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "outgoingOffset"
            to: -5
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }

    }

}
