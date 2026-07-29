import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: false
    property bool showPercentages: true
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight

    onClicked: BarPopups.toggle("resources")

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "developer_board"
            percentage: ResourceUsage.cpuUsage
            shown: Config.options.bar.resources.alwaysShowCpu ||
                !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                root.alwaysShowAllResources
            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            showPercentage: root.showPercentages
        }

        Resource {
            visible: GpuUsage.available && GpuUsage.statsAvailable
            iconName: "monitor"
            percentage: GpuUsage.usage
            Layout.leftMargin: 6
            warningThreshold: Config.options.bar.resources.gpuWarningThreshold
            showPercentage: root.showPercentages
        }

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            Layout.leftMargin: 6
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            showPercentage: root.showPercentages
        }

        Resource {
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: (Config.options.bar.resources.alwaysShowSwap && percentage > 0) ||
                (MprisController.activePlayer?.trackTitle == null) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.swapWarningThreshold
            showPercentage: root.showPercentages
        }

        Resource {
            visible: Battery.available
            iconName: Battery.isCharging ? "battery_charging_full" : Battery.isLow ? "battery_alert" : "battery_android_full"
            percentage: Battery.percentage
            Layout.leftMargin: 6
            warningThreshold: Config.options.battery.low
            invertWarning: true
            showPercentage: root.showPercentages
        }

    }

    ResourcesPopup {
        hoverTarget: root
        shown: BarPopups.activePopupId === "resources"
        onDismissRequested: BarPopups.close()
    }
}
