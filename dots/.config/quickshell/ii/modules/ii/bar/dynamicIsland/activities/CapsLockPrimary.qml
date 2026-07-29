import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

IslandActivityRow {
    id: root

    readonly property bool capsLockOn: HyprlandXkb.capsLockOn
    readonly property string statusText: capsLockOn ? Translation.tr("Caps Lock activated") : Translation.tr("Caps Lock deactivated")

    icon: capsLockOn ? "keyboard_capslock" : "keyboard"
    iconColor: capsLockOn ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext

    Item {
        id: statusSlot
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: parent.right
        }
        implicitHeight: incomingStatus.implicitHeight
        clip: true

        property bool initialized: false
        property bool transitionRunning: false
        property string displayedText: root.statusText
        property string outgoingText: ""
        property real incomingOpacity: 1
        property real outgoingOpacity: 0
        property real incomingOffset: 0
        property real outgoingOffset: 0
        readonly property real transitionDistance: 7

        function setStatus(nextText) {
            if (displayedText === nextText)
                return;

            if (!initialized) {
                displayedText = nextText;
                return;
            }

            statusTransition.stop();
            outgoingText = displayedText;
            displayedText = nextText;
            transitionRunning = true;
            incomingOpacity = 0;
            outgoingOpacity = 1;
            incomingOffset = transitionDistance;
            outgoingOffset = 0;
            statusTransition.restart();
        }

        Component.onCompleted: {
            initialized = true;
            setStatus(root.statusText);
        }

        Connections {
            target: root
            function onStatusTextChanged() {
                statusSlot.setStatus(root.statusText);
            }
        }

        StyledText {
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            visible: statusSlot.transitionRunning
            elide: Text.ElideRight
            color: Appearance.colors.colOnLayer1
            text: statusSlot.outgoingText
            opacity: statusSlot.outgoingOpacity
            transform: Translate {
                y: statusSlot.outgoingOffset
            }
        }

        StyledText {
            id: incomingStatus
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            color: Appearance.colors.colOnLayer1
            text: statusSlot.displayedText
            opacity: statusSlot.incomingOpacity
            transform: Translate {
                y: statusSlot.incomingOffset
            }
        }

        ParallelAnimation {
            id: statusTransition

            NumberAnimation {
                target: statusSlot
                property: "incomingOpacity"
                to: 1
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
            NumberAnimation {
                target: statusSlot
                property: "outgoingOpacity"
                to: 0
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
            NumberAnimation {
                target: statusSlot
                property: "incomingOffset"
                to: 0
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Appearance.animation.elementMoveSmall.type
                easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
            }
            NumberAnimation {
                target: statusSlot
                property: "outgoingOffset"
                to: -statusSlot.transitionDistance
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Appearance.animation.elementMoveSmall.type
                easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
            }

            onStopped: {
                statusSlot.transitionRunning = false;
                statusSlot.outgoingText = "";
                statusSlot.incomingOpacity = 1;
                statusSlot.outgoingOpacity = 0;
                statusSlot.incomingOffset = 0;
                statusSlot.outgoingOffset = 0;
            }
        }
    }
}
