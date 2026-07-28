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
                symbol: "storage"
                percentage: ResourceUsage.swapUsedPercentage
                valueText: `${Math.round(ResourceUsage.swapUsedPercentage * 100)}%`
                subtitleText: `${root.formatKB(ResourceUsage.swapUsed)} / ${root.formatKB(ResourceUsage.swapTotal)}`
                warning: ResourceUsage.swapUsedPercentage * 100 >= Config.options.bar.resources.swapWarningThreshold
            }

            ResourceCard {
                Layout.fillWidth: true
                title: "CPU"
                symbol: "developer_board"
                percentage: ResourceUsage.cpuUsage
                valueText: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                subtitleText: ResourceUsage.maxAvailableCpuString
                warning: ResourceUsage.cpuUsage * 100 >= Config.options.bar.resources.cpuWarningThreshold
            }
        }
    }
}
