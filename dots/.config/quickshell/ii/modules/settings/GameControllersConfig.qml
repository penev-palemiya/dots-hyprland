import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    Component.onCompleted: GameControllers.start()
    Component.onDestruction: GameControllers.stop()

    function axis(name) { return Number(GameControllers.testerState.axes?.[name] ?? 0); }
    function pressed(name) { return Boolean(GameControllers.testerState.buttons?.[name]); }
    function details(controller) { GameControllers.select(controller.runtimeId); }

    SettingsGroup {
        title: Translation.tr("Controllers")

        SettingsRow {
            visible: GameControllers.error.length > 0 && !GameControllers.ready
            icon: "error"
            title: Translation.tr("Controller backend unavailable")
            description: GameControllers.error
            registerInSearch: false
        }

        SettingsRow {
            visible: GameControllers.ready && GameControllers.controllers.length === 0
            icon: "sports_esports"
            title: Translation.tr("No game controllers detected")
            description: Translation.tr("Connect a controller by USB or Bluetooth to test its inputs.")
            registerInSearch: false
        }

        Repeater {
            model: GameControllers.controllers
            SettingsRow {
                required property var modelData
                icon: modelData.mapped ? "sports_esports" : "joystick"
                title: modelData.name
                description: [modelData.transport, modelData.connected ? Translation.tr("Connected") : Translation.tr("Disconnected")].filter(value => value && value.length > 0).join(" · ")
                clickable: true
                onClicked: root.details(modelData)

                DialogButton {
                    buttonText: Translation.tr("Details")
                    onClicked: root.details(modelData)
                }
            }
        }
    }

    SettingsGroup {
        visible: GameControllers.selectedController !== null
        title: Translation.tr("Controller details")

        SettingsRow { title: Translation.tr("Name"); description: GameControllers.selectedController?.name || ""; registerInSearch: false }
        SettingsRow { title: Translation.tr("Type"); description: GameControllers.selectedController?.type || Translation.tr("Unknown"); registerInSearch: false }
        SettingsRow { title: Translation.tr("Connection"); description: GameControllers.selectedController?.transport || Translation.tr("Unknown"); registerInSearch: false }
        SettingsRow { title: Translation.tr("Mapping"); description: GameControllers.selectedController?.mapping || Translation.tr("Unknown"); registerInSearch: false }
        SettingsRow { visible: Boolean(GameControllers.selectedController?.batteryAvailable); title: Translation.tr("Battery"); description: `${GameControllers.selectedController?.battery ?? 0}%`; registerInSearch: false }
        SettingsRow { title: Translation.tr("Vendor / Product"); description: `${GameControllers.selectedController?.vendorId ?? 0} / ${GameControllers.selectedController?.productId ?? 0}`; registerInSearch: false }
        SettingsRow { title: Translation.tr("GUID"); description: GameControllers.selectedController?.guid || ""; registerInSearch: false }
    }

    SettingsGroup {
        visible: GameControllers.selectedController?.mapped === true
        title: Translation.tr("Test controller")

        SettingsRow {
            icon: "sports_esports"
            title: Translation.tr("Sticks")
            registerInSearch: false
            RowLayout {
                spacing: 12
                StickView { label: Translation.tr("Left stick"); xValue: root.axis("leftX"); yValue: root.axis("leftY") }
                StickView { label: Translation.tr("Right stick"); xValue: root.axis("rightX"); yValue: root.axis("rightY") }
            }
        }

        SettingsRow {
            icon: "linear_scale"
            title: Translation.tr("Triggers")
            registerInSearch: false
            ColumnLayout {
                Layout.preferredWidth: 300
                TriggerBar { label: Translation.tr("Left trigger"); amount: root.axis("leftTrigger") }
                TriggerBar { label: Translation.tr("Right trigger"); amount: root.axis("rightTrigger") }
            }
        }

        SettingsRow {
            icon: "gamepad"
            title: Translation.tr("Buttons")
            registerInSearch: false
            GridLayout {
                columns: 5
                columnSpacing: 8
                rowSpacing: 6
                Repeater {
                    model: [
                        { key: "south", label: "South" }, { key: "east", label: "East" },
                        { key: "west", label: "West" }, { key: "north", label: "North" },
                        { key: "back", label: "Back" }, { key: "guide", label: "Guide" },
                        { key: "start", label: "Start" }, { key: "leftShoulder", label: "LB" },
                        { key: "rightShoulder", label: "RB" }, { key: "dpadUp", label: "D-pad Up" },
                        { key: "dpadDown", label: "D-pad Down" }, { key: "dpadLeft", label: "D-pad Left" },
                        { key: "dpadRight", label: "D-pad Right" }
                    ]
                    Rectangle {
                        required property var modelData
                        implicitWidth: 82
                        implicitHeight: 30
                        radius: 8
                        color: root.pressed(modelData.key) ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3
                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.color === Appearance.colors.colPrimaryContainer ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer3
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }
        }
    }

    component StickView: ColumnLayout {
        required property string label
        required property real xValue
        required property real yValue
        Layout.preferredWidth: 130
        StyledText { text: parent.label; Layout.alignment: Qt.AlignHCenter; color: Appearance.colors.colOnSurfaceVariant }
        Item {
            Layout.alignment: Qt.AlignHCenter
            width: 110
            height: 110
            Rectangle { anchors.fill: parent; radius: width / 2; color: Appearance.colors.colLayer3; border.color: Appearance.colors.colOutlineVariant; border.width: 1 }
            Rectangle { anchors.centerIn: parent; width: 1; height: parent.height - 14; color: Appearance.colors.colOutlineVariant }
            Rectangle { anchors.centerIn: parent; width: parent.width - 14; height: 1; color: Appearance.colors.colOutlineVariant }
            Rectangle {
                width: 14; height: 14; radius: 7
                x: Math.max(0, Math.min(parent.width - width, (parent.width - width) / 2 + parent.width * xValue / 2))
                y: Math.max(0, Math.min(parent.height - height, (parent.height - height) / 2 + parent.height * yValue / 2))
                color: Appearance.colors.colPrimary
            }
        }
    }

    component TriggerBar: RowLayout {
        required property string label
        required property real amount
        Layout.fillWidth: true
        StyledText { text: parent.label; Layout.preferredWidth: 100; color: Appearance.colors.colOnSurfaceVariant }
        Rectangle {
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Appearance.colors.colLayer3
            Rectangle { width: parent.width * Math.max(0, Math.min(1, parent.parent.amount)); height: parent.height; radius: 4; color: Appearance.colors.colPrimary }
        }
    }
}
