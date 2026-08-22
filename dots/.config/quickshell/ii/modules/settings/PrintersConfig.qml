import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property var selectedPrinter: null

    Component.onCompleted: Printers.refresh()

    function stateDescription(printer) {
        const parts = [printer.state || Translation.tr("Unknown")];
        if (printer.isDefault) parts.push(Translation.tr("Default"));
        parts.push(`${Number(printer.jobCount || 0)} ${Translation.tr("jobs")}`);
        return parts.join(" · ");
    }

    SettingsGroup {
        title: Translation.tr("Printers")

        SettingsRow {
            visible: !Printers.serverAvailable
            icon: "print_disabled"
            title: Translation.tr("Printing service unavailable")
            description: Translation.tr("Printer management requires the CUPS printing service.")
            registerInSearch: false

            DialogButton {
                buttonText: Printers.loading ? Translation.tr("Refreshing…") : Translation.tr("Refresh")
                enabled: !Printers.loading
                onClicked: Printers.refresh()
            }
        }

        SettingsRow {
            visible: Printers.serverAvailable && Printers.printers.length === 0
            icon: "print"
            title: Translation.tr("No printers configured")
            description: Translation.tr("Printers configured through CUPS will appear here.")
            registerInSearch: false

            DialogButton {
                buttonText: Printers.loading ? Translation.tr("Refreshing…") : Translation.tr("Refresh")
                enabled: !Printers.loading
                onClicked: Printers.refresh()
            }
        }

        Repeater {
            model: Printers.serverAvailable ? Printers.printers : []

            SettingsRow {
                required property var modelData
                icon: modelData.state === "Error" ? "error" : modelData.state === "Offline" ? "print_disabled" : "print"
                title: modelData.displayName || modelData.name
                description: root.stateDescription(modelData)
                clickable: true
                onClicked: root.selectedPrinter = modelData

                DialogButton {
                    buttonText: Translation.tr("Details")
                    onClicked: root.selectedPrinter = modelData
                }
            }
        }

        SettingsRow {
            visible: Printers.serverAvailable
            icon: "refresh"
            title: Translation.tr("Refresh")
            description: Printers.loading ? Translation.tr("Reading configured printers…") : Translation.tr("Reload printer and job status")
            registerInSearch: false
            DialogButton {
                buttonText: Printers.loading ? Translation.tr("Refreshing…") : Translation.tr("Refresh")
                enabled: !Printers.loading
                onClicked: Printers.refresh()
            }
        }
    }

    SettingsGroup {
        visible: root.selectedPrinter !== null
        title: Translation.tr("Printer details")

        SettingsRow { title: Translation.tr("Name"); description: root.selectedPrinter?.name || ""; registerInSearch: false }
        SettingsRow { title: Translation.tr("Model"); description: root.selectedPrinter?.model || Translation.tr("Unknown"); registerInSearch: false }
        SettingsRow { title: Translation.tr("Status"); description: root.selectedPrinter ? root.stateDescription(root.selectedPrinter) : ""; registerInSearch: false }
        SettingsRow { title: Translation.tr("Connection"); description: root.selectedPrinter?.deviceUri || Translation.tr("Unknown"); registerInSearch: false }
        SettingsRow { title: Translation.tr("Accepting jobs"); description: root.selectedPrinter?.accepting ? Translation.tr("Yes") : Translation.tr("No"); registerInSearch: false }
        SettingsRow { title: Translation.tr("Default printer"); description: root.selectedPrinter?.isDefault ? Translation.tr("Yes") : Translation.tr("No"); registerInSearch: false }
    }
}
