import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

// Fork of AddressBar.qml (the shared widget the wallpaper picker also uses),
// not a shared base class - same reasoning as FileExplorerPane's fork of
// Wallpapers.qml: a size/behaviour tweak made here (back/forward buttons,
// copy-path, denser padding) must not risk the wallpaper picker's address
// bar, and vice versa.
//
// Adds over the shared AddressBar: back/forward navigation (the shared one
// only ever had "up"), a "copy path" button next to "edit", and denser
// tokens (smaller padding/implicit sizes) sized for a file manager's
// toolbar rather than the wallpaper picker's more spacious header.
//
// z: 10, well above the rubber-band MouseArea in FileExplorerContent.qml
// (z: 1). Both used to be siblings, with no ordering between an item at the
// ColumnLayout level (this) and one nested inside a different Item several
// levels down (the rubber-band area) - QML's z comparison only orders
// siblings within the SAME parent, so a z on one had no defined relationship
// to a z on the other. Reported as "drag-select overlaps the search bar,
// though the search bar should be above everything" - giving this bar its
// own unambiguously-high z (rather than tuning the rubber-band's number and
// hoping it stays lower forever) is what actually pins the ordering.
Rectangle {
    id: root
    required property var directory
    property bool showBreadcrumb: true
    onShowBreadcrumbChanged: {
        addressInput.text = root.directory;
    }

    signal navigateToDirectory(string path)
    signal navigateBack()
    signal navigateForward()
    signal pasteIntoRequested(string path)
    property bool canGoBack: false
    property bool canGoForward: false

    z: 10

    property real padding: 4
    implicitWidth: mainLayout.implicitWidth + padding * 2
    implicitHeight: mainLayout.implicitHeight + padding * 2
    color: Appearance.colors.colLayer2

    function focusBreadcrumb() {
        root.showBreadcrumb = false;
        addressInput.forceActiveFocus();
    }

    RowLayout {
        id: mainLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 4

        RippleButton {
            id: backButton
            enabled: root.canGoBack
            implicitWidth: 32
            implicitHeight: 32
            downAction: () => root.navigateBack()
            contentItem: MaterialSymbol {
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: backButton.enabled ? Appearance.colors.colOnLayer2 : Appearance.m3colors.m3outline
            }
            StyledToolTip {
                text: Translation.tr("Back")
            }
        }

        RippleButton {
            id: forwardButton
            enabled: root.canGoForward
            implicitWidth: 32
            implicitHeight: 32
            downAction: () => root.navigateForward()
            contentItem: MaterialSymbol {
                text: "arrow_forward"
                iconSize: Appearance.font.pixelSize.large
                color: forwardButton.enabled ? Appearance.colors.colOnLayer2 : Appearance.m3colors.m3outline
            }
            StyledToolTip {
                text: Translation.tr("Forward")
            }
        }

        RippleButton {
            id: parentDirButton
            implicitWidth: 32
            implicitHeight: 32
            downAction: () => root.navigateToDirectory(FileUtils.parentDirectory(root.directory))
            contentItem: MaterialSymbol {
                text: "drive_folder_upload"
                iconSize: Appearance.font.pixelSize.large
            }
            StyledToolTip {
                text: Translation.tr("Up one folder")
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: directoryEntry
                visible: !root.showBreadcrumb
                anchors.fill: parent
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.full
                implicitWidth: addressInput.implicitWidth
                implicitHeight: addressInput.implicitHeight

                Keys.onPressed: event => {
                    if (directoryEntry.visible && event.key === Qt.Key_Escape) {
                        root.showBreadcrumb = true;
                        event.accepted = true;
                        return;
                    }
                    event.accepted = false;
                }

                StyledTextInput {
                    id: addressInput
                    anchors.fill: parent
                    padding: 8
                    text: root.directory

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.navigateToDirectory(text);
                            root.showBreadcrumb = true;
                            event.accepted = true;
                        }
                    }

                    MouseArea {
                        // I-beam cursor
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                    }
                }
            }

            Loader {
                id: breadcrumbLoader
                active: root.showBreadcrumb
                visible: root.showBreadcrumb
                anchors.fill: parent
                sourceComponent: FileExplorerAddressBreadcrumb {
                    directory: root.directory
                    onNavigateToDirectory: dir => {
                        root.navigateToDirectory(dir);
                    }
                    onPasteIntoRequested: path => root.pasteIntoRequested(path)
                }
            }
        }

        RippleButton {
            id: copyPathButton
            implicitWidth: 32
            implicitHeight: 32
            downAction: () => Quickshell.clipboardText = FileUtils.trimFileProtocol(root.directory)
            contentItem: MaterialSymbol {
                text: "content_copy"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer2
            }
            StyledToolTip {
                text: Translation.tr("Copy path")
            }
        }

        RippleButton {
            id: dirEditButton
            implicitWidth: 32
            implicitHeight: 32
            toggled: !root.showBreadcrumb
            downAction: () => root.showBreadcrumb = !root.showBreadcrumb
            contentItem: MaterialSymbol {
                text: "edit"
                iconSize: Appearance.font.pixelSize.large
                color: dirEditButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
            }

            StyledToolTip {
                text: Translation.tr("Edit directory")
            }
        }
    }
}
