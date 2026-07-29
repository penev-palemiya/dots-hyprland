pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Manages a HyprlandFocusGrab that's to be shared by all windows.
 * "Persistent" is for windows that should always be included but not closed on dismiss, like bar and onscreen keyboard.
 * "Dismissable" is for stuff like sidebars
 */ 
Singleton {
    id: root

    signal dismissed()

    property list<var> persistent: []
    property list<var> dismissable: []

    function dismiss() {
        root.dismissable = [];
        root.dismissed();
    }

    Component.onCompleted: {
        console.log("[GlobalFocusGrab] Initialized");
    }

    function addPersistent(window) {
        if (root.persistent.indexOf(window) === -1) {
            var next = root.persistent.slice();
            next.push(window);
            root.persistent = next;
        }
    }

    function removePersistent(window) {
        var index = root.persistent.indexOf(window);
        if (index !== -1) {
            var next = root.persistent.slice();
            next.splice(index, 1);
            root.persistent = next;
        }
    }

    function addDismissable(window) {
        if (root.dismissable.indexOf(window) === -1) {
            var next = root.dismissable.slice();
            next.push(window);
            root.dismissable = next;
        }
    }

    function removeDismissable(window) {
        var index = root.dismissable.indexOf(window);
        if (index !== -1) {
            var next = root.dismissable.slice();
            next.splice(index, 1);
            root.dismissable = next;
        }
    }

    function hasActive(element) {
        if (!element)
            return false;
        if (element.activeFocus)
            return true;
        var children = Array.from(element.children);
        for (var i = 0; i < children.length; i++) {
            if (hasActive(children[i]))
                return true;
        }
        return false;
    }

    function isFocusable(window) {
        return window ? window.focusable : false;
    }

    function windowHasActive(window) {
        return hasActive(window ? window.contentItem : null);
    }

    function focusGrabWindows() {
        var includePersistent = true;
        for (var i = 0; i < root.dismissable.length; i++) {
            if (isFocusable(root.dismissable[i])) {
                includePersistent = false;
                break;
            }
        }
        if (!includePersistent) {
            for (var j = 0; j < root.dismissable.length; j++) {
                if (windowHasActive(root.dismissable[j])) {
                    includePersistent = true;
                    break;
                }
            }
        }

        if (!includePersistent)
            return root.dismissable.slice();

        var result = root.dismissable.slice();
        for (var k = 0; k < root.persistent.length; k++) {
            result.push(root.persistent[k]);
        }
        return result;
    }

    HyprlandFocusGrab {
        id: grab
        windows: root.focusGrabWindows()
        active: root.dismissable.length > 0
        onCleared: {
            root.dismiss();
        }
    }

}
