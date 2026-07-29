pragma Singleton
import QtQuick
import Quickshell

/**
 * Coordinates the bar's click-triggered popups (Weather, Resources,
 * Battery, Clock) so only one is ever open at a time. StyledPopup unmaps on
 * close to avoid transparent layer-shell windows eating clicks, so switching
 * is immediate: old popup is destroyed, new popup enters above everything else.
 */
Singleton {
    id: root

    property string activePopupId: ""
    readonly property bool weatherOpen: activePopupId === "weather"
    readonly property bool resourcesOpen: activePopupId === "resources"
    readonly property bool batteryOpen: activePopupId === "battery"
    readonly property bool clockOpen: activePopupId === "clock"
    readonly property bool anyOpen: activePopupId.length > 0

    function close() {
        root.activePopupId = "";
    }

    function toggle(popupId) {
        if (root.activePopupId === popupId) {
            root.close();
            return;
        }

        root.activePopupId = popupId;
    }
}
