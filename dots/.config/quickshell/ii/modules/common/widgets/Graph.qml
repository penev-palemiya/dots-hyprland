import QtQuick
import qs.modules.common
import qs.modules.common.functions

/*
 * Simple one value line graph
 */
Canvas {
    id: root

    enum Alignment { Left, Right }

    required property list<real> values
    property int points: values.length
    property color color: Appearance.colors.colPrimary
    property real fillOpacity: 0.5
    property real lineWidth: 2
    // Dash pattern in canvas units, e.g. [4, 3]. Empty (the default) is a
    // solid line, i.e. exactly the previous behavior. Used when two graphs
    // are stacked in one chart and the palette is too desaturated for color
    // alone to tell them apart — see ResourcesPopup.qml.
    property list<real> dashPattern: []
    property var alignment: Graph.Alignment.Left

    onValuesChanged: root.requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!root.values || root.values.length < 2)
            return

        var n = root.points
        var dx = width / (n - 1)
        ctx.strokeStyle = root.color
        ctx.fillStyle = ColorUtils.transparentize(root.color, 1 - root.fillOpacity)
        ctx.lineWidth = root.lineWidth
        // Guarded: setLineDash isn't part of every Qt Quick Canvas build's
        // context2d, and a missing one would otherwise throw mid-paint and
        // leave the graph blank.
        if (ctx.setLineDash)
            ctx.setLineDash(root.dashPattern)
        ctx.beginPath()
        for (var i = 0; i < n; ++i) {
            var valueIndex = (root.alignment === Graph.Alignment.Right) ? root.values.length - n + i : i
            if (valueIndex < 0 || valueIndex >= root.values.length) {
                continue; // No data for this point
            }
            var x = i * dx
            var norm = root.values[valueIndex] // already in 0-1 range
            var y = height - norm * height
            if (valueIndex === 0) {
                ctx.moveTo(x, height)
                ctx.lineTo(x, y)
            } else {
                ctx.lineTo(x, y)
            }
        }
        ctx.stroke()
        ctx.lineTo(width, height)
        ctx.fill()
    }
}
