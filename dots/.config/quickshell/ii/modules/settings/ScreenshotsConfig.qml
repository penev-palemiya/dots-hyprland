import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.utils
import qs.modules.settings.components

SettingsSubPage {
    id: root

    FolderDialog {
        id: folderDialog
        title: Translation.tr("Choose screenshot folder")
        // Start from an existing directory; the default ~/Screenshots folder
        // is intentionally created only when the first screenshot is saved.
        currentFolder: Qt.resolvedUrl(Directories.home)
        onAccepted: {
            const selected = FileUtils.trimFileProtocol(decodeURIComponent(selectedFolder.toString()));
            if (selected.length > 0)
                Config.options.screenSnip.saveDirectory = ScreenshotAction.normalizeDirectory(selected);
        }
    }

    SettingsGroup {
        title: Translation.tr("Saving")

        SettingsToggleRow {
            icon: "crop_free"
            title: Translation.tr("Save selected-area screenshots")
            description: Translation.tr("Save normal region screenshots in addition to copying them.")
            checked: Config.options.screenSnip.saveRegion
            onToggled: checked => Config.options.screenSnip.saveRegion = checked
        }

        SettingsRow {
            icon: "folder"
            title: Translation.tr("Save screenshots to")
            description: Translation.tr("Used by monitor and saved region screenshots.")

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: ScreenshotAction.effectiveSaveDirectory
                    elide: Text.ElideMiddle
                    color: Appearance.colors.colOnSurfaceVariant
                }

                DialogButton {
                    buttonText: Translation.tr("Choose")
                    onClicked: folderDialog.open()
                }
            }
        }

        SettingsToggleRow {
            icon: "content_copy"
            title: Translation.tr("Copy saved screenshots to clipboard")
            description: Translation.tr("Does not change the dedicated Print clipboard action.")
            checked: Config.options.screenSnip.copySavedToClipboard
            onToggled: checked => Config.options.screenSnip.copySavedToClipboard = checked
        }

        SettingsRow {
            visible: ScreenshotAction.lastError.length > 0
            icon: "error"
            title: Translation.tr("Screenshot error")
            description: ScreenshotAction.lastError
            registerInSearch: false
        }
    }
}
