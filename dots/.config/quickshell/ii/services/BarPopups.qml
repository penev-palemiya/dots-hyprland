pragma Singleton
import QtQuick
import Quickshell

/**
 * Coordinates the bar's click-triggered popups (Weather, Resources,
 * Battery, Clock) so only one is ever open at a time. Switching from one
 * to another gives the outgoing popup a moment to actually play its exit
 * animation (half of it) instead of either an instant hard swap or a full
 * wait for the old one to finish closing before the new one appears.
 */
Singleton {
    id: root

    property string activePopupId: ""
    property string pendingPopupId: ""

    function close() {
        root.activePopupId = "";
        root.pendingPopupId = "";
        switchTimer.stop();
    }

    function toggle(popupId) {
        if (root.activePopupId === popupId || (switchTimer.running && root.pendingPopupId === popupId)) {
            root.close();
            return;
        }

        if (root.activePopupId === "" && !switchTimer.running) {
            root.activePopupId = popupId;
        } else {
            root.activePopupId = "";
            root.pendingPopupId = popupId;
            if (!switchTimer.running)
                switchTimer.restart();
        }
    }

    Timer {
        id: switchTimer
        // Kept short and independent of the popup's own (now snappier, spring-
        // eased) exit timing in StyledPopup.qml — this is just enough of a gap
        // to read as "the old one left" before the new one grows in, not a
        // dead pause. Tune alongside StyledPopup.popupExitDuration if that
        // value changes meaningfully.
        interval: 60
        onTriggered: {
            root.activePopupId = root.pendingPopupId;
            root.pendingPopupId = "";
        }
    }
}
