import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

// Fork of WallpaperDirectoryItem.qml, generalized for arbitrary files rather
// than only images: thumbnails are shown for images the same way, everything
// else falls back to DirectoryIcon's file/folder icon instead of Image trying
// (and failing) to decode it.
MouseArea {
    id: root
    required property var fileModelData
    property bool isDirectory: fileModelData.fileIsDir
    property bool useThumbnail: !isDirectory && Images.isValidImageByName(fileModelData.fileName)

    property alias colBackground: background.color
    property alias colText: itemName.color
    property alias radius: background.radius
    property alias margins: background.anchors.margins
    property alias padding: itemColumnLayout.anchors.margins
    margins: Appearance.sizes.fileExplorerItemMargins
    padding: Appearance.sizes.fileExplorerItemPadding

    // Inline rename (F2), Nautilus-style: the label swaps for an editable
    // field in place, rather than opening a separate dialog. `renaming` is
    // driven by the grid (it owns which single path is being renamed, since
    // only one can be at a time); commit/cancel are signals rather than the
    // item mutating FileExplorer directly, so the grid can decide what
    // "committed" even means (e.g. no-op if the name didn't change).
    property bool renaming: false
    signal renameCommitted(newName: string)
    signal renameCancelled()

    // selectRequested(modifiers) selects (single/ctrl/shift, per the caller's
    // own selection model); activated() opens the file or enters the
    // directory. Split this way to match Nautilus/Explorer: a single plain
    // click only selects, so multi-select survives clicking through a folder
    // - if a click both selected AND activated, selecting item N would always
    // also open it, making a several-item selection impossible to build by
    // click.
    //
    // Named selectRequested rather than reusing MouseArea's own `clicked`
    // signal: declaring `signal clicked(...)` here shadows the built-in
    // property-change/superclass signal of the same name and Qt logs it as
    // an invalid override (verified - it's a warning, not silently ignored,
    // but there's no reason to court it).
    signal selectRequested(modifiers: int)
    signal activated()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onClicked: mouse => root.selectRequested(mouse.modifiers)
    onDoubleClicked: root.activated()

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Appearance.rounding.normal
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        ColumnLayout {
            id: itemColumnLayout
            anchors.fill: parent
            spacing: 4

            Item {
                id: itemImageContainer
                Layout.fillHeight: true
                Layout.fillWidth: true

                Loader {
                    id: thumbnailShadowLoader
                    active: thumbnailImageLoader.active && thumbnailImageLoader.item.status === Image.Ready
                    anchors.fill: thumbnailImageLoader
                    sourceComponent: StyledRectangularShadow {
                        target: thumbnailImageLoader
                        anchors.fill: undefined
                        radius: Appearance.rounding.small
                    }
                }

                Loader {
                    id: thumbnailImageLoader
                    anchors.fill: parent
                    active: root.useThumbnail
                    sourceComponent: Image {
                        id: thumbnailImage
                        source: root.useThumbnail ? Qt.resolvedUrl(fileModelData.filePath) : ""
                        asynchronous: true
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        clip: true

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: itemImageContainer.width
                                height: itemImageContainer.height
                                radius: Appearance.rounding.small
                            }
                        }
                    }
                }

                Loader {
                    id: iconLoader
                    active: !root.useThumbnail
                    anchors.fill: parent
                    sourceComponent: DirectoryIcon {
                        fileModelData: root.fileModelData
                    }
                }
            }

            StyledText {
                id: itemName
                visible: !root.renaming
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                text: fileModelData.fileName
            }

            // Bare TextInput, not a styled field: this sits directly where
            // the label was, at label size, with no box/border of its own -
            // any visible container would misread as a second, nested card
            // inside the grid tile.
            TextInput {
                id: renameInput
                visible: root.renaming
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                horizontalAlignment: Text.AlignHCenter
                clip: true
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: itemName.color
                selectByMouse: true

                // (Re)seeded on becoming visible rather than bound to
                // fileModelData.fileName: a bound `text` would fight every
                // keystroke, since the model's fileName doesn't change until
                // the rename actually commits.
                onVisibleChanged: {
                    if (!visible) return;
                    text = fileModelData.fileName;
                    // Select the name only, not the extension - matches
                    // Nautilus/Explorer, and is almost always what someone
                    // renaming a file actually wants pre-selected.
                    const dot = text.lastIndexOf(".");
                    select(0, dot > 0 ? dot : text.length);
                    forceActiveFocus();
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.renameCommitted(renameInput.text);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.renameCancelled();
                        event.accepted = true;
                    }
                }
                onActiveFocusChanged: {
                    // Clicking away commits rather than silently discarding -
                    // losing focus is not the same gesture as pressing
                    // Escape, and treating it as a cancel would make an
                    // accidental click elsewhere throw away a typed rename.
                    if (!activeFocus && root.renaming)
                        root.renameCommitted(renameInput.text);
                }
            }
        }
    }
}
