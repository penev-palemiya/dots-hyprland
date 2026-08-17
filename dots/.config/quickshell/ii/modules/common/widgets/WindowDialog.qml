import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    id: root

    property bool show: false
    default property alias contentData: contentColumn.data
    // Content-driven by default. Deliberately NOT `dialogBackground.implicitHeight`
    // — that was self-referential, which is why the height had to be assigned
    // imperatively below instead of bound, and that in turn meant the dialog
    // froze at whatever size it had when it opened.
    property real backgroundHeight: contentColumn.implicitHeight + root.contentPadding * 2
    property real backgroundWidth: 350
    // Was hard-coded to `dialogBackground.radius`, which happened to be 23 and
    // meant the padding could never be tuned without changing the corner. Same
    // default, so every existing dialog is unchanged.
    property real contentPadding: Appearance.rounding.large
    property real backgroundAnimationMovementDistance: 60

    // Opt-in staggered content reveal, the same model StyledPopup uses for the
    // bar popups: one shared window in which every section gets its own slice, so
    // later sections are still arriving while earlier ones have settled and the
    // cascade always ends at the same moment regardless of how many there are. A
    // dialog opts in by setting `staggerContent` and declaring how many steps it
    // has, then each of its sections reads `sectionOpacity(i)`/`sectionOffset(i)`.
    property bool staggerContent: false
    property int revealSections: 4
    readonly property real sectionMaxStart: 0.5
    readonly property real sectionSpan: 0.5
    // 0 while closed, 1 once the content has fully arrived.
    property real revealPhase: 0
    // True while the cascade is still running, so items created as part of it
    // don't also play their own entry animation on top of it.
    readonly property bool revealing: root.staggerContent && root.revealPhase < 1

    function sectionProgress(index: int): real {
        if (!root.staggerContent)
            return 1;
        const steps = Math.max(1, root.revealSections - 1);
        const start = Math.min(root.sectionMaxStart, (index / steps) * root.sectionMaxStart);
        return Math.max(0, Math.min(1, (root.revealPhase - start) / root.sectionSpan));
    }

    function sectionOpacity(index: int): real {
        return root.sectionProgress(index);
    }

    // A short slide in the direction the dialog grows from.
    function sectionOffset(index: int): real {
        return (1 - root.sectionProgress(index)) * 10;
    }

    // Content trails the shape by a beat on the way in and leaves without waiting
    // on the way out (docs/design/motion.md, container transform).
    SequentialAnimation {
        id: revealAnimation

        running: false

        PauseAnimation {
            duration: root.show ? 110 : 0
        }

        NumberAnimation {
            target: root
            property: "revealPhase"
            to: root.show ? 1 : 0
            duration: root.show ? 420 : Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    onShowChanged: if (root.staggerContent) revealAnimation.restart();


    signal dismiss()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.dismiss();
            event.accepted = true;
        }
    }

    color: root.show ? Appearance.colors.colScrim : ColorUtils.transparentize(Appearance.colors.colScrim)
    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }
    visible: dialogBackground.implicitHeight > 0

    radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

    MouseArea { // Clicking outside the dialog should dismiss
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: root.dismiss()
    }

    Rectangle {
        id: dialogBackground
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Appearance.rounding.large
        color: Appearance.m3colors.m3surfaceContainerHigh // Use opaque version of layer3
        // The content is full-size from the start and this growing shape is what
        // reveals it — the same arrangement as StyledPopup, for the same two
        // reasons. It used to be laid out against the animating height instead,
        // which re-ran the whole ColumnLayout (and the list inside it) on every
        // frame of the animation: that is the missing smoothness. And because a
        // layout doesn't clip, its rows stayed painted outside the collapsing
        // surface on the way out, which is the "content left floating on nothing"
        // desync. Rounded corners stay correct throughout because this is the
        // real shape, not a clip mask over one.
        clip: true

        property real targetY: root.height / 2 - root.backgroundHeight / 2
        y: root.show ? targetY : (targetY - root.backgroundAnimationMovementDistance)
        implicitWidth: root.backgroundWidth
        implicitHeight: root.show ? root.backgroundHeight : 0
        // The height is a binding, so a dialog whose content changes while it is
        // open — Bluetooth discovery finding devices, a Wi-Fi row expanding —
        // grows to fit instead of letting the extra rows spill out past its own
        // background. Height is spatial, so per docs/design/motion.md it gets an
        // expressive spring rather than the flat effects curve this used to have,
        // and opening (the hero moment) is slower than closing. Both directions
        // live in one static animation whose own properties switch: reassigning
        // a Behavior's `animation` per direction silently keeps the first one.
        Behavior on implicitHeight {
            NumberAnimation {
                id: dialogBackgroundHeightAnimation
                duration: root.show ? Appearance.animation.elementMove.duration : Appearance.animation.elementMoveSmall.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.show ? Appearance.animation.elementMove.bezierCurve : Appearance.animation.elementMoveSmall.bezierCurve
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: dialogBackgroundHeightAnimation.duration
                easing.type: dialogBackgroundHeightAnimation.easing.type
                easing.bezierCurve: dialogBackgroundHeightAnimation.easing.bezierCurve
            }
        }

        MouseArea { // So clicking inside the dialog won't dismiss
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }

        // Pinned to the edge the surface grows out of and sized by its own
        // content, so nothing shifts or re-measures while the shape animates.
        Item {
            id: contentHost

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.backgroundWidth
            height: root.backgroundHeight

            ColumnLayout {
                id: contentColumn
                anchors {
                    fill: parent
                    margins: root.contentPadding
                }
                spacing: 16
                // Dialogs that stagger drive their own sections' opacity, so the
                // block-level fade would only mush the cascade.
                opacity: root.staggerContent ? 1 : (root.show ? 1 : 0)

                // Content trails the shape on the way in; on the way out the
                // collapsing surface clips it away, so this fade only has to keep
                // it from being the last thing standing. Opacity is an effects
                // property, hence the flat curve.
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: root.show ? 120 : 0
                        }

                        NumberAnimation {
                            duration: root.show ? Appearance.animation.elementMoveFast.duration : Appearance.animation.elementMoveSmall.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }
            }
        }
    }
}
