import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions

/**
 * One row of a grouped list, shaped like a card: small corners inside the
 * group, large corners on the group's first and last row, so a section reads
 * as one rounded block of separate items. Same corner scale as GroupedGrid
 * (4 inside, 16 outside), so lists and grids look like the same system.
 *
 * Colours here are chosen from measured contrast, not by eye, because this
 * palette is wallpaper-derived and can come out nearly monochrome. On the
 * shipped scheme:
 *
 * - A card on the dialog surface is only 1.16:1 — tonal layering alone cannot
 *   carry "this is a card", so the shape (rounded group + 4px gaps) does that
 *   job, not the fill.
 * - `colOutline` is the usual subtitle colour in this repo, but it measures
 *   2.72:1 on a selected row — a straight fail. Subtitles here use
 *   `colOnSurfaceVariant` instead: 7.28:1 normal, 5.10:1 selected.
 * - The strongest contrast available is reserved for the one thing that must
 *   never be missed — the selected row's accent border and marker
 *   (`colPrimary`, 5.06:1 on the selected fill).
 */
Rectangle {
    id: root

    // Position within its own section, which is what decides the corners.
    property int indexInSection: 0
    property int sectionCount: 1

    property bool selected: false
    property bool expanded: false
    property bool interactive: true

    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property string trailingIcon: ""
    property bool trailingRotated: false

    // Extra content revealed under the row (password field, action buttons).
    default property alias expandedData: expandedColumn.data

    signal clicked

    readonly property real innerRadius: 4
    readonly property real outerRadius: 16
    readonly property bool isFirst: root.indexInSection === 0
    readonly property bool isLast: root.indexInSection === root.sectionCount - 1

    topLeftRadius: root.isFirst ? root.outerRadius : root.innerRadius
    topRightRadius: root.isFirst ? root.outerRadius : root.innerRadius
    bottomLeftRadius: root.isLast ? root.outerRadius : root.innerRadius
    bottomRightRadius: root.isLast ? root.outerRadius : root.innerRadius

    color: root.selected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colSurfaceContainerHighest
    // No border. An outline on the selected row was tried and dropped: it
    // works when exactly one row is selected (Wi-Fi), but Bluetooth can have
    // several devices connected at once, and adjacent outlined cards read as
    // separate pills — destroying the grouped-block shape the corners exist
    // to create. The selected state is carried by the lighter fill plus an
    // accented, filled icon instead.

    implicitHeight: contentColumn.implicitHeight + 20
    clip: true

    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(root)
    }

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(root)
    }

    // M3 state layer rather than a ripple: these are list rows, and a ripple
    // spreading across a 16px-cornered group edge looks wrong.
    StateLayer {
        anchors.fill: parent
        radius: 0
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
        visible: root.interactive && (mouseArea.containsMouse || mouseArea.pressed)
        state: mouseArea.pressed ? StateLayer.State.Press : StateLayer.State.Hover
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    ColumnLayout {
        id: contentColumn

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 14
            rightMargin: 14
            topMargin: 10
        }
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: root.iconName.length > 0
                text: root.iconName
                iconSize: Appearance.font.pixelSize.larger
                fill: root.selected ? 1 : 0
                // colPrimary measures 5.06:1 on the selected fill — the
                // strongest signal this palette offers, spent on the one thing
                // that must not be missed.
                color: root.selected ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: root.title
                    font {
                        pixelSize: Appearance.font.pixelSize.small
                        weight: Font.Medium
                    }
                    color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: root.subtitle
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: root.trailingIcon.length > 0
                text: root.trailingIcon
                iconSize: Appearance.font.pixelSize.larger
                fill: root.selected ? 1 : 0
                color: root.selected ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                rotation: root.trailingRotated ? 180 : 0

                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }

        ColumnLayout {
            id: expandedColumn

            Layout.fillWidth: true
            Layout.topMargin: root.expanded ? 10 : 0
            visible: root.expanded
            spacing: 8
        }
    }
}
