import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    Item {
        anchors.centerIn: parent
        implicitWidth: columnLayout.implicitWidth + 8
        implicitHeight: columnLayout.implicitHeight + 8

        ColumnLayout {
            id: columnLayout
            anchors.centerIn: parent
            spacing: 8

            ResourceCard {
                Layout.fillWidth: true
                title: "CPU"
                symbol: "developer_board"
                percentage: ResourceUsage.cpuUsage
                valueText: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                subtitleText: ResourceUsage.maxAvailableCpuString
                subtitleText2: ResourceUsage.cpuTempAvailable ? `${Math.round(ResourceUsage.cpuTemp)}°C` : ""
                warning: (ResourceUsage.cpuUsage * 100 >= Config.options.bar.resources.cpuWarningThreshold) || (ResourceUsage.cpuTempAvailable && ResourceUsage.cpuTemp >= Config.options.bar.resources.cpuTempWarningThreshold)
            }

            ResourceCard {
                Layout.fillWidth: true
                visible: GpuUsage.available
                title: Translation.tr("GPU")
                symbol: "monitor"
                percentage: GpuUsage.statsAvailable ? GpuUsage.usage : 0
                valueText: GpuUsage.statsAvailable ? `${Math.round(GpuUsage.usage * 100)}%` : "—"
                subtitleText: GpuUsage.statsAvailable ? `${Math.round(GpuUsage.temp)}°C` : Translation.tr("Stats unavailable")
                warning: GpuUsage.statsAvailable && GpuUsage.usage * 100 >= Config.options.bar.resources.gpuWarningThreshold
            }

            ResourceCard {
                Layout.fillWidth: true
                title: "RAM"
                symbol: "memory"
                percentage: ResourceUsage.memoryUsedPercentage
                valueText: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`
                subtitleText: `${root.formatKB(ResourceUsage.memoryUsed)} / ${root.formatKB(ResourceUsage.memoryTotal)}`
                warning: ResourceUsage.memoryUsedPercentage * 100 >= Config.options.bar.resources.memoryWarningThreshold
            }

            ResourceCard {
                Layout.fillWidth: true
                visible: ResourceUsage.swapTotal > 0
                title: "Swap"
                symbol: "swap_horiz"
                percentage: ResourceUsage.swapUsedPercentage
                valueText: `${Math.round(ResourceUsage.swapUsedPercentage * 100)}%`
                subtitleText: `${root.formatKB(ResourceUsage.swapUsed)} / ${root.formatKB(ResourceUsage.swapTotal)}`
                warning: ResourceUsage.swapUsedPercentage * 100 >= Config.options.bar.resources.swapWarningThreshold
            }

            ResourceCard {
                Layout.fillWidth: true
                visible: Battery.available
                title: Translation.tr("Battery")
                symbol: Battery.isCharging ? "battery_charging_full" : "battery_android_full"
                percentage: Battery.percentage
                valueText: `${Math.round(Battery.percentage * 100)}%`
                subtitleText: Battery.isCharging ? Translation.tr("Charging") : Translation.tr("Discharging")
                warning: Battery.isLow && !Battery.isCharging
            }
        }
    }
}
