import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    Component.onCompleted: OtherDevices.start()
    Component.onDestruction: OtherDevices.stop()

    SettingsGroup {
        title: Translation.tr("Other devices")

        SettingsRow {
            visible: OtherDevices.error.length > 0 && !OtherDevices.ready
            icon: "error"
            title: Translation.tr("Device monitor unavailable")
            description: OtherDevices.error
            registerInSearch: false
        }

        SettingsRow {
            visible: OtherDevices.ready && OtherDevices.devices.length === 0
            icon: "devices_other"
            title: Translation.tr("No other devices connected")
            description: Translation.tr("User-facing hardware outside the dedicated device pages will appear here.")
            registerInSearch: false
        }

        Repeater {
            model: OtherDevices.devices
            SettingsRow {
                required property var modelData
                icon: modelData.type === "Camera" ? "photo_camera" : modelData.type === "Security Device" ? "fingerprint" : "devices_other"
                title: modelData.name
                description: [modelData.type, modelData.connection].filter(value => value && value.length > 0).join(" · ")
                clickable: true
                onClicked: OtherDevices.select(modelData)

                DialogButton {
                    buttonText: Translation.tr("Details")
                    onClicked: OtherDevices.select(modelData)
                }
            }
        }
    }

    SettingsGroup {
        visible: OtherDevices.selectedDevice !== null
        title: Translation.tr("Device details")

        SettingsRow { title: Translation.tr("Name"); description: OtherDevices.selectedDevice?.name || ""; registerInSearch: false }
        SettingsRow { title: Translation.tr("Type"); description: OtherDevices.selectedDevice?.type || ""; registerInSearch: false }
        SettingsRow { title: Translation.tr("Manufacturer"); description: OtherDevices.selectedDevice?.manufacturer || Translation.tr("Unknown"); registerInSearch: false }
        SettingsRow { title: Translation.tr("Connection"); description: OtherDevices.selectedDevice?.connection || Translation.tr("Unknown"); registerInSearch: false }
        SettingsRow { title: Translation.tr("Driver"); description: OtherDevices.selectedDevice?.driver || Translation.tr("Unknown"); registerInSearch: false }
        SettingsRow { visible: Boolean(OtherDevices.selectedDevice?.vendorId || OtherDevices.selectedDevice?.productId); title: Translation.tr("Vendor / Product"); description: `${OtherDevices.selectedDevice?.vendorId || ""} / ${OtherDevices.selectedDevice?.productId || ""}`; registerInSearch: false }
    }
}
