pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    signal raiseRequested()
    property bool active: false
    property string route: ""

    function open(routeKey = "") {
        root.route = routeKey || "";
        if (root.active) {
            root.raiseRequested();
            return;
        }
        root.active = true;
    }

    function close() {
        root.active = false;
        root.route = "";
    }

    function toggle() {
        if (root.active)
            root.close();
        else
            root.open();
    }
}
