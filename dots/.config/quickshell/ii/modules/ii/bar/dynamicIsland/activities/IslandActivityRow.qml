import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Shared skeleton for a primary activity row: an icon chip on the left,
 * then whatever activity-specific content fills the rest of the width.
 * This lives INSIDE the bar's fixed-height pill, so icon-chip sizing must
 * follow the bar-scale convention — matched to Workspaces.qml's
 * workspaceButtonWidth (26px), not the popup-card scale (WeatherCard/
 * ResourceCard use a bigger chip because popups have much more room —
 * see docs/design/bar-popups.md).
 */
RowLayout {
    id: root

    default property alias content: contentSlot.data
    property alias icon: iconSymbol.text
    property alias iconColor: iconSymbol.color
    // When set, replaces the MaterialSymbol glyph entirely (e.g. a real
    // notification app icon/avatar instead of an icon-font symbol). Every
    // existing row (Media/CapsLock/Mic) leaves this unset and is unaffected.
    property Component iconOverride: null

    spacing: 6

    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        radius: Appearance.rounding.full
        color: Appearance.colors.colSecondaryContainer
        implicitWidth: 26
        implicitHeight: implicitWidth
        clip: true

        Loader {
            anchors.fill: parent
            active: !!root.iconOverride
            sourceComponent: root.iconOverride
        }

        MaterialSymbol {
            visible: !root.iconOverride
            id: iconSymbol
            anchors.centerIn: parent
            fill: 1
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSecondaryContainer

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(iconSymbol)
            }

            // Icon swap within the same row (e.g. media play/pause): crossfade
            // only, no position change — see docs/design/motion.md#recipes.
            opacity: 1
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(iconSymbol)
            }
            onTextChanged: {
                opacity = 0;
                iconFadeBackTimer.restart();
            }
            Timer {
                id: iconFadeBackTimer
                interval: 1
                onTriggered: iconSymbol.opacity = 1
            }
        }
    }

    Item {
        id: contentSlot
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: childrenRect.height
    }
}
