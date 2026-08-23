import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    FolderDialog {
        id: folderDialog
        title: Translation.tr("Choose recording folder")
        currentFolder: Qt.resolvedUrl(Directories.home)
        onAccepted: {
            const selected = FileUtils.trimFileProtocol(decodeURIComponent(selectedFolder.toString()));
            if (selected.length > 0)
                Config.options.screenRecord.saveDirectory = ScreenRecording.normalizeDirectory(selected);
        }
    }

    SettingsGroup {
        title: Translation.tr("Screen recording")

        SettingsRow {
            icon: "folder"
            title: Translation.tr("Save recordings to")
            description: Translation.tr("Where new screen recordings are saved.")

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: Config.options.screenRecord.saveDirectory
                    elide: Text.ElideMiddle
                    color: Appearance.colors.colOnSurfaceVariant
                }

                DialogButton {
                    buttonText: Translation.tr("Choose")
                    onClicked: folderDialog.open()
                }
            }
        }

        SettingsRow {
            visible: ScreenRecording.active
            icon: "fiber_manual_record"
            title: Translation.tr("Recording now")
            description: {
                const total = ScreenRecording.elapsedSeconds;
                return Math.floor(total / 60).toString().padStart(2, "0")
                    + ":" + (total % 60).toString().padStart(2, "0");
            }

            DialogButton {
                buttonText: Translation.tr("Stop recording")
                onClicked: ScreenRecording.stop()
            }
        }

        SettingsRow {
            visible: ScreenRecording.lastError.length > 0
            icon: "error"
            title: Translation.tr("Recording error")
            description: ScreenRecording.lastError
            registerInSearch: false
        }
    }
}

