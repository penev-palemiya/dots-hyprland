import QtQuick
import QtQuick.Layouts
import qs.modules.common

/**
 * A GridLayout whose children can round their *outer* corners more than their
 * inner ones, so a grid of separate cards reads as one rounded block without
 * actually being merged into a single card.
 *
 * Each child asks for its own corners:
 *
 *     GroupedGrid {
 *         id: grid
 *         columns: 2
 *
 *         WeatherCard { id: rain; corners: grid.cornersFor(rain) }
 *         WeatherCard { id: wind; corners: grid.cornersFor(wind) }
 *     }
 *
 * The answer is derived from where each child actually ended up, not from its
 * index. That matters because a grid's corners aren't simply "first and last
 * item": tiles can be conditionally invisible, and the last one may span both
 * columns (ResourcesPopup does exactly this when its tile count is odd), in
 * which case one card owns both bottom corners. Reading real geometry handles
 * all of that for free.
 *
 * `cornersFor` reads its siblings' positions, and QML's binding engine records
 * those reads as dependencies — so a card re-evaluates its corners whenever
 * the layout moves anything, with no manual invalidation. (Verified: hiding a
 * sibling re-ran the binding and the remaining card correctly became the
 * leftmost one.)
 */
GridLayout {
    id: root

    // Deliberately tighter than Appearance.rounding.small: a card inside a
    // group reads as a segment of one shape, not as a standalone card, so its
    // own corners want to be nearly square. Only the group's four outer
    // corners carry real rounding.
    property real innerRadius: 4
    property real outerRadius: 16

    // The gap wants to be small for the same reason — at 8px the cards read as
    // scattered tiles, at 4 they read as one block that happens to be divided.
    rowSpacing: 4
    columnSpacing: 4

    /**
     * Corner radii for one child, as {topLeft, topRight, bottomLeft, bottomRight}.
     * A child is on an edge of the group when its own edge sits at the extreme
     * of every visible sibling's, within a pixel of slack for layout rounding.
     */
    function cornersFor(item) {
        const inner = root.innerRadius;
        const fallback = {
            topLeft: inner,
            topRight: inner,
            bottomLeft: inner,
            bottomRight: inner
        };
        if (!item || !item.visible)
            return fallback;

        let minX = Infinity;
        let minY = Infinity;
        let maxRight = -Infinity;
        let maxBottom = -Infinity;
        let seen = 0;

        for (let i = 0; i < root.children.length; i++) {
            const child = root.children[i];
            // Zero-sized children are items the layout is still settling or has
            // collapsed; counting them would put the group's edge in the wrong
            // place.
            if (!child.visible || child.width <= 0 || child.height <= 0)
                continue;
            seen += 1;
            minX = Math.min(minX, child.x);
            minY = Math.min(minY, child.y);
            maxRight = Math.max(maxRight, child.x + child.width);
            maxBottom = Math.max(maxBottom, child.y + child.height);
        }

        if (seen === 0)
            return fallback;

        const eps = 1;
        const onLeft = Math.abs(item.x - minX) <= eps;
        const onTop = Math.abs(item.y - minY) <= eps;
        const onRight = Math.abs(item.x + item.width - maxRight) <= eps;
        const onBottom = Math.abs(item.y + item.height - maxBottom) <= eps;
        const outer = root.outerRadius;

        return {
            topLeft: (onLeft && onTop) ? outer : inner,
            topRight: (onRight && onTop) ? outer : inner,
            bottomLeft: (onLeft && onBottom) ? outer : inner,
            bottomRight: (onRight && onBottom) ? outer : inner
        };
    }
}
