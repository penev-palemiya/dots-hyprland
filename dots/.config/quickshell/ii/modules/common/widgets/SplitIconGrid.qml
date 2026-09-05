import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions

/**
 * A single workspace slot's icon, split into wedges when the workspace holds
 * more than one window - so the bar shows "there are 3 windows here" instead
 * of silently collapsing to whichever one happens to be biggest.
 *
 * Occupies the same circular footprint (`diameter`) that the single-icon case
 * in Workspaces.qml already uses, so switching between the two never resizes
 * or reflows the workspace slot around it:
 *
 *   1 window  -> one full circle (all 4 corners show the same window)
 *   2 windows -> left/right halves
 *   3-4       -> a 2x2 grid, one quarter-circle wedge per window
 *
 * ANIMATING 1<->2<->3<->4, carefully, not just "add a Behavior":
 *
 * There are always exactly 4 corner slots (TL/TR/BL/BR), never a Repeater
 * over a variable-length model. A Repeater destroys and recreates delegates
 * whenever the model's length changes, and a destroyed delegate has no
 * "previous state" to animate from - so nothing built that way can ever
 * animate a count change, only fade one static picture into another.
 *
 * There are always exactly 4 corner slots (TL/TR/BL/BR). Which window each
 * one shows, and whether it's merged with its vertical and/or horizontal
 * neighbour, changes with `count` - but no corner is ever destroyed, so a
 * plain Behavior on its geometry is honestly sufficient to animate any
 * transition between any two counts.
 *
 * Each corner can independently merge on two axes: vertically (TL<->BL,
 * TR<->BR) when they show the same window, and horizontally (TL<->TR,
 * BL<->BR) likewise. Both axes are needed, not just the vertical one: at
 * count<=1 every corner shows the same window, so both seams have to close,
 * or a single-window "circle" would still show a 1px cross-shaped gap
 * through its middle. A merged corner stretches to the FULL diameter on that
 * axis, overlapping its neighbour exactly (two identical circles' worth of
 * colour on top of each other is harmless) rather than the two staying
 * `half`-sized and touching at a seam - real overlap is what a rounded-corner
 * mask needs to line up correctly (see next paragraph).
 *
 * The mask shape morphs continuously too, not just position, but NOT via a
 * fixed corner + rotation transform - that was tried first and is wrong once
 * merging changes a wedge's own size: rotating a shape that has grown from
 * half x half to full diameter x diameter still only rounds the one corner
 * the rotation points at, leaving the rectangle's other 3 corners sharp
 * (verified by hand before it was ever fixed - overlaying 4 such
 * one-rounded-corner squares does not reproduce a circle, it reproduces
 * something much closer to a full square with 4 barely-rounded corners).
 * What each corner actually needs is an explicit, independent decision per
 * rectangle corner (topLeft/topRight/bottomLeft/bottomRight) - see
 * round{TL,TR,BL,BR} below - all sharing one FIXED radius equal to the full
 * circle's own radius (diameter/2). Because the radius never changes,
 * shrinking a side below that radius is what naturally turns a clean arc into
 * a flat inner edge.
 *
 * Each wedge is masked with the same Colorizer + MultiEffect recipe the
 * single-icon path uses (colorize to the theme's on-container color, mask to
 * the wedge shape) so a split icon and a single icon look like the same
 * material, not two different treatments bolted together.
 */
Item {
    id: root

    property real diameter: 26
    property var windows: []
    readonly property int count: Math.min(windows.length, 4)

    // Fixed regardless of diameter, not a proportion of it - the gap should
    // read the same "there are two separate icons here" cut whether this is a
    // 18px workspace slot or a larger one, not shrink into invisibility on
    // the small end or balloon on the large one.
    readonly property real gap: 1
    readonly property real half: (root.diameter - root.gap) / 2

    implicitWidth: diameter
    implicitHeight: diameter

    // Which window index (into `windows`) each fixed corner shows, for the
    // current count. Corners sharing a value are the ones that visually
    // merge into one half.
    readonly property var cornerWindow: {
        const c = root.count;
        if (c <= 1) return [0, 0, 0, 0]; // TL,TR,BL,BR all -> window 0
        if (c === 2) return [0, 1, 0, 1]; // left pair -> 0, right pair -> 1
        if (c === 3) return [0, 1, 2, 2]; // BL+BR merge into the bottom half
        return [0, 1, 2, 3];
    }

    // Two independent merge axes per corner, both needed - not just the
    // vertical one: at count<=1 every corner shows the same window, so BOTH
    // the vertical seam (TL/BL, TR/BR) and the horizontal seam (TL/TR, BL/BR)
    // have to close, or one full-circle icon would still show a 1px vertical
    // gap straight down its middle even though there's only one window.
    readonly property bool leftMerged: root.cornerWindow[0] === root.cornerWindow[2] // TL<->BL (vertical)
    readonly property bool rightMerged: root.cornerWindow[1] === root.cornerWindow[3] // TR<->BR (vertical)
    readonly property bool topMerged: root.cornerWindow[0] === root.cornerWindow[1] // TL<->TR (horizontal)
    readonly property bool bottomMerged: root.cornerWindow[2] === root.cornerWindow[3] // BL<->BR (horizontal)

    // The 4 fixed corners: which side/row they're pinned to (via `corner`,
    // parsed into isLeft/onTopRow inside the component), and whether they're
    // currently merged with their vertical and/or horizontal neighbour.
    Corner {
        corner: "TL"
        diameter: root.diameter
        half: root.half
        gap: root.gap
        onTopRow: true
        vMerged: root.leftMerged
        hMerged: root.topMerged
        windowIndex: root.cornerWindow[0]
        windowData: root.windows[windowIndex]
    }
    Corner {
        corner: "TR"
        diameter: root.diameter
        half: root.half
        gap: root.gap
        onTopRow: true
        vMerged: root.rightMerged
        hMerged: root.topMerged
        windowIndex: root.cornerWindow[1]
        windowData: root.windows[windowIndex]
    }
    Corner {
        corner: "BL"
        diameter: root.diameter
        half: root.half
        gap: root.gap
        onTopRow: false
        vMerged: root.leftMerged
        hMerged: root.bottomMerged
        windowIndex: root.cornerWindow[2]
        windowData: root.windows[windowIndex]
    }
    Corner {
        corner: "BR"
        diameter: root.diameter
        half: root.half
        gap: root.gap
        onTopRow: false
        vMerged: root.rightMerged
        hMerged: root.bottomMerged
        windowIndex: root.cornerWindow[3]
        windowData: root.windows[windowIndex]
    }

    /**
     * One fixed corner wedge. Both its width/x (horizontal) and height/y
     * (vertical) animate independently, each stretching to the full diameter
     * and overlapping its neighbour exactly when merged on that axis - a
     * corner can be merged on one axis, both, or neither, since at count<=1
     * every corner needs to close its seam in both directions to read as one
     * uninterrupted circle rather than a circle with a cross-shaped gap
     * through the middle. Its mask's rounded corners (round{TL,TR,BL,BR}
     * below) are computed explicitly from which axes are merged - see the
     * parent doc comment for why a fixed corner + rotation transform doesn't
     * work once the rectangle's own size changes with merging.
     */
    component Corner: Item {
        id: wedge

        required property string corner
        required property real diameter
        required property real half
        required property real gap
        required property bool onTopRow
        required property bool vMerged
        required property bool hMerged
        required property int windowIndex
        property var windowData
        readonly property bool isLeft: corner === "TL" || corner === "BL"

        readonly property string iconSource: Quickshell.iconPath(AppSearch.guessIcon(windowData?.class), "image-missing")

        // hMerged: full width, x=0 - overlaps the horizontal neighbour
        // exactly. Split: half width, pinned to this corner's own side.
        width: hMerged ? diameter : half
        x: hMerged ? 0 : (isLeft ? 0 : half + gap)
        // vMerged: full height, y=0 - overlaps the vertical neighbour
        // exactly. Split: half height, pinned to this corner's own edge.
        height: vMerged ? diameter : half
        y: vMerged ? 0 : (onTopRow ? 0 : half + gap)
        clip: true

        // Which of the rectangle's 4 corners should be rounded, given this
        // wedge's own corner and which neighbour(s) it's currently merged
        // with. This can't be done with a single fixed corner + a rotation
        // transform once the rect's own size is changing: rotating a
        // half x half square that has grown to full diameter x diameter still
        // only rounds the one corner the rotation points at, leaving the
        // other 3 sharp - a real circle (or a real half/quarter arc) needs
        // whichever set of corners actually sits on the shape's outer edge
        // at that moment, which changes as neighbours merge or split.
        //
        // Own corner is always rounded. Merging vertically also rounds the
        // corner directly above/below it (same side, other row); merging
        // horizontally also rounds the corner directly across (same row,
        // other side); merging on BOTH axes rounds all 4. Written as one
        // explicit truth table per corner rather than a combined formula -
        // an earlier combined-formula version was verified against this same
        // table by hand and found wrong for the "one axis merged" cases
        // before ever reaching the file, which is why this is spelled out
        // longhand instead of condensed further.
        readonly property bool roundTL: (isLeft && onTopRow)
            || (vMerged && hMerged)
            || (vMerged && isLeft && !onTopRow)   // BL merging up into TL
            || (hMerged && !isLeft && onTopRow)   // TR merging left into TL
        readonly property bool roundTR: (!isLeft && onTopRow)
            || (vMerged && hMerged)
            || (vMerged && !isLeft && !onTopRow)  // BR merging up into TR
            || (hMerged && isLeft && onTopRow)    // TL merging right into TR
        readonly property bool roundBL: (isLeft && !onTopRow)
            || (vMerged && hMerged)
            || (vMerged && isLeft && onTopRow)    // TL merging down into BL
            || (hMerged && !isLeft && !onTopRow)  // BR merging left into BL
        readonly property bool roundBR: (!isLeft && !onTopRow)
            || (vMerged && hMerged)
            || (vMerged && !isLeft && onTopRow)   // TR merging down into BR
            || (hMerged && isLeft && !onTopRow)   // BL merging right into BR

        Behavior on width { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
        Behavior on x { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
        Behavior on height { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
        Behavior on y { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }

        // The icon, the mask, and the colorized result are all built at FULL
        // circle size (diameter) and positioned in root's coordinate space
        // (hence the `-wedge.x/-wedge.y` offset, since these are children of
        // `wedge`, which is itself offset within root). `wedge`'s own
        // clip:true is what then keeps only this corner's slice on screen.
        AppIcon {
            id: wedgeIcon
            visible: false // colorizer below copies it; avoid drawing twice
            x: -wedge.x
            y: -wedge.y
            implicitSize: NumberUtils.roundToEven(wedge.diameter)
            source: wedge.iconSource
            animated: false
        }

        Item {
            id: wedgeMaskHost
            visible: false
            layer.enabled: true
            x: -wedge.x
            y: -wedge.y
            width: wedge.diameter
            height: wedge.diameter

            // Fixed radius = the full circle's own radius; which of the 4
            // corners actually use it comes from wedge.round{TL,TR,BL,BR}
            // (see the wedge-level comment on those for why a fixed corner +
            // rotation transform doesn't work once the rect's own size
            // changes with merging). Matches wedge's geometry exactly, offset
            // back into root's coordinate space.
            Rectangle {
                x: wedge.x
                y: wedge.y
                width: wedge.width
                height: wedge.height
                readonly property real r: wedge.diameter / 2
                topLeftRadius: wedge.roundTL ? r : 0
                topRightRadius: wedge.roundTR ? r : 0
                bottomLeftRadius: wedge.roundBL ? r : 0
                bottomRightRadius: wedge.roundBR ? r : 0

                Behavior on width { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                Behavior on x { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                Behavior on height { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                Behavior on y { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
            }
        }

        Loader { // Matches the "put the MultiEffect in a Loader" workaround
                 // the single-icon path already relies on to render at all.
            x: -wedge.x
            y: -wedge.y
            width: wedge.diameter
            height: wedge.diameter
            sourceComponent: Colorizer {
                implicitWidth: wedge.diameter
                implicitHeight: wedge.diameter
                colorizationColor: Appearance.m3colors.darkmode ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                colorization: Config.options.bar.workspaces.monochromeIcons ? 0.8 : 0.5
                brightness: 0
                source: wedgeIcon

                maskEnabled: true
                maskSource: wedgeMaskHost
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }
    }
}
