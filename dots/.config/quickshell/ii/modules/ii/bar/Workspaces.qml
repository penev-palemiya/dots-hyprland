pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

ButtonMouseArea {
    id: root

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    WorkspaceModel {
        id: wsModel
        monitor: root.monitor
    }

    property real workspaceButtonWidth: 26
    property real activeWorkspaceMargin: 2
    property real activeWorkspaceSize: workspaceButtonWidth - activeWorkspaceMargin * 2
    property real workspaceIconSize: workspaceButtonWidth * 0.69
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.55
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: (monitor?.activeWorkspace?.id - 1) % wsModel.shownCount
    property real specialTextSize: workspaceButtonWidth * 0.5

    Layout.alignment: Qt.AlignVCenter
    Layout.fillWidth: false
    Layout.fillHeight: true
    readonly property real barThickness: Appearance.sizes.barHeight
    implicitWidth: occupiedIndicators.implicitWidth
    implicitHeight: barThickness

    property real specialBlur: (wsModel.specialWorkspaceActive && !containsMouse) ? 1 : 0
    Behavior on specialBlur {
        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
    }

    // Interactions
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.BackButton
    hoverEnabled: true
    property int hoverIndex: Math.floor(mouseX / root.workspaceButtonWidth)

    // Pinned hover slot: only advances while hovering, so the hover indicator
    // freezes in place (instead of flying back to the active workspace) once
    // the mouse leaves, and snaps instantly to the cursor's slot when hovering
    // starts (instead of sliding in from the active workspace).
    property int hoverPinnedIndex: workspaceIndexInGroup

    onContainsMouseChanged: {
        if (containsMouse) {
            interactionIndicator.animated = false;
            hoverPinnedIndex = hoverIndex;
            Qt.callLater(() => interactionIndicator.animated = true);
        }
    }
    onHoverIndexChanged: {
        if (containsMouse)
            hoverPinnedIndex = hoverIndex;
    }

    function switchWorkspaceToHovered() {
        Hyprland.dispatch(`hl.dsp.focus({workspace = ${wsModel.getWorkspaceIdAt(hoverIndex)}})`);
    }

    function toggleSpecial() {
        Hyprland.dispatch(`hl.dsp.workspace.toggle_special("special")`);
    }

    // Single source of truth: whether a workspace slot should render an app icon
    // (both the icon layer and the fallback dot layer must agree on this).
    function slotShowsIcon(index) {
        const wsId = wsModel.getWorkspaceIdAt(index);
        return !!(Config.options?.bar.workspaces.showAppIcons && wsModel.biggestWindow[index] && wsId !== wsModel.fakeWorkspace);
    }

    onPressed: mouse => {
        if (mouse.button == Qt.LeftButton)
            switchWorkspaceToHovered();
        else if (mouse.button == Qt.RightButton)
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        else if (mouse.button == Qt.BackButton) 
            toggleSpecial()
    }
    onWheel: event => {
        if (event.angleDelta.y < 0)
            Hyprland.dispatch(`hl.dsp.focus({workspace = "r+1"})`);
        else if (event.angleDelta.y > 0)
            Hyprland.dispatch(`hl.dsp.focus({workspace = "r-1"})`);
    }

    // Indications
    Item {
        id: regularWorkspaces
        anchors.fill: parent

        scale: 1 - 0.08 * root.specialBlur
        layer.smooth: true
        layer.enabled: root.specialBlur > 0
        layer.effect: MultiEffect {
            brightness: -0.1 * root.specialBlur
            blurEnabled: true
            blur: root.specialBlur
            blurMax: 32
        }

        /////////////////// Occupied indicators ///////////////////
        StyledRectangle {
            id: occupiedIndicatorsBg
            anchors.fill: parent
            contentLayer: StyledRectangle.ContentLayer.Group
            color: ColorUtils.transparentize(Appearance.m3colors.m3secondaryContainer, 0.4)
            visible: false
        }

        WorkspaceLayout {
            id: occupiedIndicators
            anchors.centerIn: parent

            layer.enabled: true
            visible: false

            Repeater {
                model: wsModel.shownCount
                delegate: Item {
                    id: wsBg
                    required property int index
                    readonly property int wsId: wsModel.getWorkspaceIdAt(index)
                    property bool currentOccupied: wsModel.occupied[index] && wsId != wsModel.fakeWorkspace
                    property bool previousOccupied: index > 0 && wsModel.occupied[index - 1] && (wsId - 1) != wsModel.fakeWorkspace
                    property bool nextOccupied: index < wsModel.shownCount - 1 && wsModel.occupied[index + 1] && (wsId + 1) != wsModel.fakeWorkspace
                    implicitWidth: root.workspaceButtonWidth
                    implicitHeight: root.workspaceButtonWidth

                    // The idea: over-stretch to occupied sides, animate this for a smooth transition.
                    //           masking already prevents weird overlaps
                    Pill {
                        property real undirectionalWidth: root.workspaceButtonWidth * wsBg.currentOccupied
                        property real undirectionalLength: root.workspaceButtonWidth * (1 + 0.5 * wsBg.previousOccupied + 0.5 * wsBg.nextOccupied) * currentOccupied
                        property real undirectionalOffset: (!wsBg.currentOccupied ? 0.5 : -0.5 * wsBg.previousOccupied) * root.workspaceButtonWidth
                        anchors.verticalCenter: parent.verticalCenter
                        x: undirectionalOffset
                        y: 0
                        implicitWidth: undirectionalLength
                        implicitHeight: undirectionalWidth

                        Behavior on undirectionalWidth {
                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                        }
                        Behavior on undirectionalLength {
                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                        }
                        Behavior on undirectionalOffset {
                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                        }
                    }
                }
            }
        }

        MaskMultiEffect {
            id: occupiedIndicatorsMultiEffect
            z: 1
            anchors.centerIn: parent
            implicitWidth: occupiedIndicators.implicitWidth
            implicitHeight: occupiedIndicators.implicitHeight
            source: occupiedIndicatorsBg
            maskSource: occupiedIndicators
        }

        /////////////////// Active indicator ///////////////////
        TrailingIndicator {
            id: activeIndicator
            anchors.fill: parent
            z: 2

            index: root.workspaceIndexInGroup
        }

        /////////////////// Hover ///////////////////
        TrailingIndicator {
            id: interactionIndicator
            z: 3
            index: root.hoverPinnedIndex
            color: "transparent"
            StateOverlay {
                id: hoverOverlay
                anchors.fill: interactionIndicator.indicatorRectangle
                radius: root.activeWorkspaceSize / 2
                hover: root.containsMouse
                press: root.containsPress
                drag: true // There are too many layers so we need to force this to be a lil more opaque
                contentColor: Appearance.colors.colPrimary

                transformOrigin: Item.Center
                scale: root.containsMouse ? 1 : 0
                Behavior on scale {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }

        /////////////////// Numbers ///////////////////
        WorkspaceLayout {
            id: numbersGrid
            z: 4
            layer.enabled: true // For the masking

            Repeater {
                model: wsModel.shownCount
                delegate: NumberWorkspaceItem {}
            }
        }
        Colorizer {
            z: 5
            anchors.fill: numbersGrid
            colorizationColor: Appearance.colors.colOnPrimary
            sourceColor: Appearance.colors.colOnSecondaryContainer

            source: activeIndicator
            maskEnabled: true
            maskSource: numbersGrid

            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        /////////////////// App icons ///////////////////
        WorkspaceLayout {
            id: appsGrid
            z: 6

            Repeater {
                model: wsModel.shownCount
                delegate: WorkspaceItem {
                    id: wsApp
                    property var windows: wsModel.windows[index] ?? []
                    property var biggestWindow: wsModel.biggestWindow[index]

                    // ONE grid for every window count, 0 included - not a
                    // single-icon path that gets swapped out for SplitIconGrid
                    // once a second window shows up. That swap used to be an
                    // instant cut between two different components (an
                    // AppIcon+Colorizer here, SplitIconGrid there), which
                    // could never be smoothed no matter how well the split
                    // grid's own internal 2<->3<->4 transitions animate.
                    // SplitIconGrid already collapses cleanly to one full
                    // circle at count<=1 (all four corners show window 0), so
                    // routing every count through it is what makes 1<->2 just
                    // another corner-resize like 2<->3, not a special case.
                    SplitIconGrid {
                        id: splitGrid
                        property real cornerMargin: (Config.options?.bar.workspaces.showAppIcons && wsApp.biggestWindow) ? (root.workspaceButtonWidth - root.workspaceIconSize) / 2 : root.workspaceIconMarginShrinked
                        anchors {
                            bottom: parent.bottom
                            right: parent.right
                            bottomMargin: (parent.implicitHeight - root.workspaceButtonWidth) / 2 + cornerMargin
                            rightMargin: (parent.implicitWidth - root.workspaceButtonWidth) / 2 + cornerMargin
                        }
                        diameter: NumberUtils.roundToEven(root.workspaceIconSize)
                        windows: wsApp.windows

                        opacity: !root.slotShowsIcon(wsApp.index) ? 0 : 1
                        visible: opacity > 0
                        scale: Config.options?.bar.workspaces.showAppIcons ? 1 : (root.workspaceIconSizeShrinked / root.workspaceIconSize)

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on scale {
                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                        }
                        Behavior on cornerMargin {
                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                        }
                    }
                }
            }
        }
    }

    FadeLoader {
        anchors.centerIn: parent
        shown: wsModel.specialWorkspaceActive
        scale: 0.8 + 0.2 * root.specialBlur

        opacity: root.specialBlur
        Behavior on opacity {} // Don't animate, as specialBlur is already animated

        sourceComponent: Pill {
            anchors.centerIn: parent
            property real undirectionalWidth: root.activeWorkspaceSize
            property real undirectionalLength: specialWsText.implicitWidth + undirectionalWidth
            color: Appearance.colors.colPrimary

            implicitWidth: undirectionalLength
            implicitHeight: undirectionalWidth

            StyledText {
                id: specialWsText
                anchors.centerIn: parent
                text: wsModel.specialWorkspaceName
                color: Appearance.colors.colOnPrimary
                font.pixelSize: root.specialTextSize
            }

            Behavior on undirectionalLength {
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }
        }
    }


    component WorkspaceLayout: Box {
        anchors {
            top: parent.top
            bottom: parent.bottom
        }

        rowSpacing: 0
        columnSpacing: 0
    }

    component WorkspaceItem: Item {
        required property int index
        readonly property int wsId: wsModel.getWorkspaceIdAt(index)
        implicitWidth: root.workspaceButtonWidth
        implicitHeight: root.barThickness
    }

    component NumberWorkspaceItem: WorkspaceItem {
        id: wsNum
        property bool hasBiggestWindow: !!wsModel.biggestWindow[index]
        property int wsId: wsModel.getWorkspaceIdAt(index)
        property color contentColor: (wsModel.occupied[wsNum.index] && wsId !== wsModel.fakeWorkspace) ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1Inactive
        property bool showingNumbers: {
            if (GlobalStates.screenLocked)
                return false;
            if (Config.options?.bar.workspaces.alwaysShowNumbers && (!Config.options?.bar.workspaces.showAppIcons || !wsNum.hasBiggestWindow))
                return true;
            return false;
        }

        FadeLoader {
            shown: !wsNum.showingNumbers && !root.slotShowsIcon(wsNum.index)
            anchors.centerIn: parent
            Circle {
                anchors.centerIn: parent
                diameter: root.workspaceButtonWidth * 0.18
                color: wsNum.contentColor
            }
        }
        FadeLoader {
            shown: wsNum.showingNumbers
            anchors.centerIn: parent
            StyledText {
                anchors.centerIn: parent
                font {
                    pixelSize: Appearance.font.pixelSize.small - ((text.length - 1) * (text !== "10") * 2)
                    family: Config.options?.bar.workspaces.useNerdFont ? Appearance.font.family.iconNerd : defaultFont
                }
                color: wsNum.contentColor
                text: Config.options?.bar.workspaces.numberMap[wsNum.wsId - 1] || wsNum.wsId
            }
        }
    }

    component TrailingIndicator: Item {
        id: trailingIndicator
        anchors.fill: parent
        required property int index
        property alias indicatorRectangle: indicatorRect
        property alias color: indicatorRect.color

        property var indexPair: AnimatedTabIndexPair {
            id: idxPair
            index: trailingIndicator.index
        }
        property alias animated: idxPair.animated

        StyledRectangle {
            id: indicatorRect

            anchors.verticalCenter: parent.verticalCenter

            property real indicatorPosition: Math.min(idxPair.idx1, idxPair.idx2) * root.workspaceButtonWidth + root.activeWorkspaceMargin
            property real indicatorLength: Math.abs(idxPair.idx1 - idxPair.idx2) * root.workspaceButtonWidth + root.activeWorkspaceSize
            property real indicatorThickness: root.activeWorkspaceSize

            contentLayer: StyledRectangle.ContentLayer.Group
            radius: indicatorThickness / 2
            color: Appearance.colors.colPrimary

            x: indicatorPosition
            implicitWidth: indicatorLength
            implicitHeight: indicatorThickness
        }
    }
}
