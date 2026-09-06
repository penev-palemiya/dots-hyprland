import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A plain list of actions, not the app's SysTrayMenu.qml (which is a
// PopupWindow driven by a QsMenuHandle - a system tray menu handle, which
// nothing here has). This is the file explorer's own right-click menu: open/
// copy/cut/paste/rename/delete on a file, or navigate/copy-path/paste-into on
// a breadcrumb segment. Both call sites build their own `actions` list and
// share this one popup shell.
Popup {
    id: root

    // List of { text, icon, enabled (optional, default true), onTriggered }.
    // A plain JS array rather than a model type of its own - the two call
    // sites (file entries, breadcrumb segments) have different actions with
    // nothing structural in common beyond "a list of clickable rows", so a
    // dedicated model would be pure ceremony.
    property var actions: []

    padding: 4
    margins: 0
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    function openAt(x, y, forItem) {
        root.parent = forItem;
        root.x = x;
        root.y = y;
        root.open();
    }

    // m3colors.* (raw opaque), not colors.col* (composited/transparentized
    // for glass-over-wallpaper surfaces) - this is a floating layer-shell/
    // window popup, not something meant to look like frosted glass over the
    // wallpaper, so it needs a genuinely solid background.
    background: Rectangle {
        color: Appearance.m3colors.m3surfaceContainer
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant
    }

    contentItem: ColumnLayout {
        spacing: 0
        Repeater {
            model: root.actions
            delegate: MenuButton {
                id: actionButton
                required property var modelData
                Layout.fillWidth: true
                enabled: modelData.enabled ?? true
                buttonRadius: Appearance.rounding.normal - root.padding

                // implicitWidth/Height overridden rather than left at
                // MenuButton's defaults: those defaults measure an internal
                // `buttonTextWidget` id that lives inside MenuButton's OWN
                // default contentItem, which this replaces below - that id
                // does not exist in this delegate's tree, so inheriting the
                // binding would reference something that was never created.
                implicitWidth: rowLayout.implicitWidth + leftPadding + rightPadding
                implicitHeight: 36
                leftPadding: 14
                rightPadding: 14

                // No anchors.fill here - Control (RippleButton's base)
                // already positions contentItem within its own padding box
                // via leftPadding/rightPadding/topPadding/bottomPadding
                // above, the same as MenuButton's own default contentItem
                // does. Anchoring this to `parent` a second time fights that
                // instead of matching it.
                contentItem: RowLayout {
                    id: rowLayout
                    spacing: 10
                    MaterialSymbol {
                        text: actionButton.modelData.icon ?? ""
                        visible: text.length > 0
                        iconSize: Appearance.font.pixelSize.larger
                        color: actionButton.enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: actionButton.modelData.text
                        color: actionButton.enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline
                    }
                }

                onClicked: {
                    root.close();
                    modelData.onTriggered();
                }
            }
        }
    }
}
