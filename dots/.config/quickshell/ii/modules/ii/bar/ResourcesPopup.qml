import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar.weather
import qs.services
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

/**
 * Resources popup, built on the same shape as WeatherPopup (which is the
 * reference implementation in docs/design/bar-popups.md): one hero card that
 * answers the question at a glance, a full-width strip of recent history, and
 * a grid of compact stat tiles for everything else.
 *
 * It used to be five visually identical full-width ResourceCards stacked in a
 * 220px column — nothing read as more important than anything else, and the
 * usage history the service already collects was never shown anywhere in the
 * bar. This is narrower in information-per-pixel terms but taller in
 * hierarchy: hero -> trend -> details.
 *
 * The hero is always CPU, deliberately. Promoting "whichever resource is
 * under most pressure" was tried and dropped: the hero changed subject as
 * values drifted, so the eye landed somewhere different every time the popup
 * opened. Warnings surface through the existing threshold colouring instead.
 */
StyledPopup {
    id: root

    // Reveal hero -> history -> tiles one after another rather than as a
    // single block. StyledPopup drives the timing; each section just declares
    // which step it is.
    staggerContent: true
    sectionCount: 6 // hero, history strip, and the four tiles

    // Draw across however many samples actually exist rather than always
    // assuming a full historyLength buffer: on a fresh shell the buffer is
    // empty and fills one sample per updateInterval, so a fixed point count
    // squeezed the whole line into the right-hand sliver of the chart and
    // left most of the box looking broken. Both series are appended in the
    // same tick, so one shared count keeps them aligned.
    readonly property int historyPoints: Math.max(2,
        Math.min(ResourceUsage.historyLength, ResourceUsage.cpuUsageHistory.length))
    readonly property real graphRangeSeconds: historyPoints
        * ((Config.options?.resources?.updateInterval ?? 3000) / 1000)
    // ...and label it with the range that's really on screen, not the range
    // the buffer would hold once full.
    readonly property string graphRangeText: graphRangeSeconds >= 90
        ? Translation.tr("Last %1 min").arg(Math.round(graphRangeSeconds / 60))
        : Translation.tr("Last %1 s").arg(Math.round(graphRangeSeconds))

    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    // Swap/GPU/battery are all machine-dependent, so this grid's tile count
    // varies between 1 and 4. docs/design/bar-popups.md flags exactly this:
    // a 2-column grid whose last row holds a single tile leaves it stranded at
    // half width next to a hole. Rather than fall back to a vertical list (and
    // lose the compact two-up shape this popup is built around), the last
    // visible tile spans both columns whenever the count is odd.
    readonly property bool hasSwap: ResourceUsage.swapTotal > 0
    readonly property bool hasGpu: GpuUsage.available
    readonly property bool hasBattery: Battery.available
    readonly property int tileCount: 1 + (hasSwap ? 1 : 0) + (hasGpu ? 1 : 0) + (hasBattery ? 1 : 0)
    readonly property bool oddTileCount: tileCount % 2 === 1
    readonly property string lastTile: hasBattery ? "battery" : hasGpu ? "gpu" : hasSwap ? "swap" : "ram"

    function tileSpan(id) {
        return (root.oddTileCount && root.lastTile === id) ? 2 : 1;
    }

    function loadWord(usage) {
        if (usage < 0.3)
            return Translation.tr("Idle");
        if (usage < 0.6)
            return Translation.tr("Moderate");
        if (usage < 0.85)
            return Translation.tr("Busy");
        return Translation.tr("Heavy");
    }

    readonly property bool cpuWarning: (ResourceUsage.cpuUsage * 100 >= Config.options.bar.resources.cpuWarningThreshold)
        || (ResourceUsage.cpuTempAvailable && ResourceUsage.cpuTemp >= Config.options.bar.resources.cpuTempWarningThreshold)

    // Both halves are resolved lazily — the CPU model string by a probe that
    // only starts once this popup opens, the temperature by a hwmon path that
    // may not exist at all. Build the line from whichever parts are actually
    // known so it doesn't render as a bare "--" placeholder on first open.
    readonly property string cpuSubtitle: {
        const parts = [];
        const model = ResourceUsage.maxAvailableCpuString;
        if (model && model !== "--")
            parts.push(model);
        if (ResourceUsage.cpuTempAvailable)
            parts.push(`${Math.round(ResourceUsage.cpuTemp)}°C`);
        return parts.join(" • ");
    }

    Item {
        anchors.centerIn: parent
        implicitWidth: 392
        implicitHeight: columnLayout.implicitHeight + 8

        ColumnLayout {
            id: columnLayout
            anchors.centerIn: parent
            width: parent.implicitWidth - 8
            spacing: 8

            // ---- Hero: CPU ----
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: heroContent.implicitHeight + 24
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHigh
                opacity: root.sectionOpacity(0)
                transform: Translate { y: root.sectionOffset(0) }

                RowLayout {
                    id: heroContent
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 14
                        rightMargin: 14
                    }
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("CPU")
                            font {
                                weight: Font.Normal
                                pixelSize: Appearance.font.pixelSize.smaller
                            }
                            color: Appearance.colors.colOutline
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.loadWord(ResourceUsage.cpuUsage)
                            font {
                                weight: Font.Bold
                                pixelSize: Appearance.font.pixelSize.small
                            }
                            color: Appearance.colors.colOnSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: root.cpuSubtitle
                            font {
                                weight: Font.Normal
                                pixelSize: Appearance.font.pixelSize.smaller
                            }
                            color: Appearance.colors.colOutline
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8

                        StyledText {
                            text: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                            font {
                                weight: Font.Bold
                                pixelSize: Appearance.font.pixelSize.small * 2
                            }
                            color: root.cpuWarning ? Appearance.colors.colError : Appearance.colors.colOnSurface
                        }

                        MaterialSymbol {
                            text: "developer_board"
                            fill: 0
                            font.weight: Font.Normal
                            iconSize: Appearance.font.pixelSize.small * 2
                            color: root.cpuWarning ? Appearance.colors.colError : Appearance.colors.colOnSurface
                        }
                    }
                }
            }

            // ---- History strip ----
            // ResourceUsage keeps historyLength samples of CPU/RAM/Swap on its
            // existing poll tick — until now nothing in the bar displayed them.
            // Graph.qml is the same renderer the resources overlay uses.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: graphColumn.implicitHeight + 20
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHigh
                opacity: root.sectionOpacity(1)
                transform: Translate { y: root.sectionOffset(1) }

                ColumnLayout {
                    id: graphColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        StyledText {
                            text: root.graphRangeText
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOutline
                        }

                        Item { Layout.fillWidth: true }

                        // Legend. The dash on the RAM swatch matches the dashed
                        // line in the graph — the shell's palette is
                        // wallpaper-derived and can come out nearly monochrome,
                        // in which case colour alone doesn't separate the two
                        // series.
                        RowLayout {
                            spacing: 5
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 10
                                implicitHeight: 2
                                radius: 1
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                text: Translation.tr("CPU")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOutline
                            }
                        }

                        RowLayout {
                            spacing: 5
                            Row {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        width: 3
                                        height: 2
                                        radius: 1
                                        color: Appearance.colors.colOutline
                                    }
                                }
                            }
                            StyledText {
                                text: Translation.tr("RAM")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOutline
                            }
                        }
                    }

                    Rectangle {
                        id: graphBg
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Appearance.rounding.verysmall
                        color: Appearance.colors.colSurfaceContainerHighest
                        // clip: true would be a rectangular clip and would cut
                        // the rounded corners off, so mask instead.
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: graphBg.width
                                height: graphBg.height
                                radius: graphBg.radius
                            }
                        }

                        // RAM first so CPU's fill draws on top of it.
                        Graph {
                            anchors.fill: parent
                            values: ResourceUsage.memoryUsageHistory
                            points: root.historyPoints
                            alignment: Graph.Alignment.Right
                            color: Appearance.colors.colOutline
                            fillOpacity: 0
                            lineWidth: 1.5
                            dashPattern: [4, 3]
                        }

                        Graph {
                            anchors.fill: parent
                            values: ResourceUsage.cpuUsageHistory
                            points: root.historyPoints
                            alignment: Graph.Alignment.Right
                            color: Appearance.colors.colPrimary
                            fillOpacity: 0.45
                        }
                    }
                }
            }

            // ---- Details ----
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                uniformCellWidths: true

                // CPU is deliberately absent — it's the hero, and repeating the
                // same number twice in one popup is what WeatherPopup avoids
                // (its temperature is in the hero and nowhere in the grid).

                WeatherCard {
                    Layout.columnSpan: root.tileSpan("ram")
                    opacity: root.sectionOpacity(2)
                    transform: Translate { y: root.sectionOffset(2) }
                    title: Translation.tr("RAM")
                    symbol: "memory"
                    value: `${root.formatKB(ResourceUsage.memoryUsed)} / ${root.formatKB(ResourceUsage.memoryTotal)}`
                    percentage: ResourceUsage.memoryUsedPercentage
                    warning: ResourceUsage.memoryUsedPercentage * 100 >= Config.options.bar.resources.memoryWarningThreshold
                }

                WeatherCard {
                    visible: root.hasSwap
                    Layout.columnSpan: root.tileSpan("swap")
                    opacity: root.sectionOpacity(3)
                    transform: Translate { y: root.sectionOffset(3) }
                    title: Translation.tr("Swap")
                    symbol: "storage"
                    value: `${root.formatKB(ResourceUsage.swapUsed)} / ${root.formatKB(ResourceUsage.swapTotal)}`
                    percentage: ResourceUsage.swapUsedPercentage
                    warning: ResourceUsage.swapUsedPercentage * 100 >= Config.options.bar.resources.swapWarningThreshold
                }

                WeatherCard {
                    visible: root.hasGpu
                    Layout.columnSpan: root.tileSpan("gpu")
                    opacity: root.sectionOpacity(4)
                    transform: Translate { y: root.sectionOffset(4) }
                    title: Translation.tr("GPU")
                    symbol: "monitor"
                    value: GpuUsage.statsAvailable
                        ? `${Math.round(GpuUsage.usage * 100)}% • ${Math.round(GpuUsage.temp)}°C`
                        : Translation.tr("Stats unavailable")
                    percentage: GpuUsage.statsAvailable ? GpuUsage.usage : -1
                    warning: GpuUsage.statsAvailable && GpuUsage.usage * 100 >= Config.options.bar.resources.gpuWarningThreshold
                }

                WeatherCard {
                    visible: root.hasBattery
                    Layout.columnSpan: root.tileSpan("battery")
                    opacity: root.sectionOpacity(5)
                    transform: Translate { y: root.sectionOffset(5) }
                    title: Battery.isCharging ? Translation.tr("Charging") : Translation.tr("Battery")
                    symbol: Battery.isCharging ? "battery_charging_full" : "battery_android_full"
                    value: `${Math.round(Battery.percentage * 100)}%`
                    percentage: Battery.percentage
                    warning: Battery.isLow && !Battery.isCharging
                }
            }
        }
    }
}
