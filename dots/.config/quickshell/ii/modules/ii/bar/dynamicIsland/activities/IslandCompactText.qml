import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string metadataText: ""
    property string primaryText: ""
    property bool primaryMarquee: false
    readonly property bool primaryOverflowing: primaryLabel.implicitWidth > primaryClip.width + 1
    readonly property real marqueeDistance: Math.max(0, primaryLabel.implicitWidth - primaryClip.width + 24)

    implicitHeight: textColumn.implicitHeight
    clip: true

    onPrimaryOverflowingChanged: root.resetMarquee()
    onPrimaryTextChanged: root.resetMarquee()
    onWidthChanged: root.resetMarquee()

    function singleLine(text) {
        return String(text ?? "").replace(/\s+/g, " ").trim();
    }

    function resetMarquee() {
        marqueeAnimation.stop();
        primaryLabel.x = 0;
        if (primaryMarquee && primaryOverflowing)
            marqueeAnimation.restart();
    }

    ColumnLayout {
        id: textColumn
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: -4

        StyledText {
            Layout.fillWidth: true
            visible: root.metadataText.length > 0
            elide: Text.ElideRight
            maximumLineCount: 1
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            text: root.singleLine(root.metadataText)
        }

        Item {
            id: primaryClip
            Layout.fillWidth: true
            implicitHeight: primaryLabel.implicitHeight
            clip: true

            StyledText {
                id: primaryLabel
                anchors.verticalCenter: parent.verticalCenter
                width: root.primaryMarquee ? implicitWidth : parent.width
                elide: root.primaryMarquee ? Text.ElideNone : Text.ElideRight
                maximumLineCount: 1
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.smaller
                text: root.singleLine(root.primaryText)
            }
        }
    }

    SequentialAnimation {
        id: marqueeAnimation
        running: root.primaryMarquee && root.primaryOverflowing
        // Play through once per text/overflow change, then stop (rather than
        // looping forever) — an infinite loop here is a continuous
        // GPU-composited animation for as long as a long title is shown in
        // the always-visible compact pill, which is wasteful on battery.
        loops: 1

        PauseAnimation {
            duration: 900
        }
        NumberAnimation {
            target: primaryLabel
            property: "x"
            to: -root.marqueeDistance
            duration: Math.max(2200, root.marqueeDistance * 38)
            easing.type: Easing.InOutQuad
        }
        PauseAnimation {
            duration: 700
        }
        PropertyAction {
            target: primaryLabel
            property: "x"
            value: 0
        }
    }
}
