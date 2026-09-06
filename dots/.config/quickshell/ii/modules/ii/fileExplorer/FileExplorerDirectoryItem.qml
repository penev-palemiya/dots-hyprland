import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
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

    signal activated()

    hoverEnabled: true
    onClicked: root.activated()

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
        }
    }
}
