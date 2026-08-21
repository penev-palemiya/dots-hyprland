//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.settings
import qs.modules.settings.components

ApplicationWindow {
    id: root

    property var pages: [
        {
            name: Translation.tr("Quick"),
            subtitle: Translation.tr("Wallpaper, colors, bar"),
            icon: "instant_mix",
            component: "modules/settings/QuickConfig.qml"
        },
        {
            name: Translation.tr("General"),
            subtitle: Translation.tr("Language, audio, battery, time"),
            icon: "browse",
            component: "modules/settings/GeneralConfig.qml"
        },
        {
            name: Translation.tr("Bar"),
            subtitle: Translation.tr("Position, tray, workspaces"),
            icon: "toast",
            iconRotation: 180,
            component: "modules/settings/BarConfig.qml"
        },
        {
            name: Translation.tr("Background"),
            subtitle: Translation.tr("Clock, weather, parallax"),
            icon: "texture",
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            name: Translation.tr("Interface"),
            subtitle: Translation.tr("Dock, lock screen, overlays"),
            icon: "bottom_app_bar",
            component: "modules/settings/InterfaceConfig.qml"
        },
        {
            name: Translation.tr("Services"),
            subtitle: Translation.tr("Search, network, updates"),
            icon: "settings",
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            name: Translation.tr("Advanced"),
            subtitle: Translation.tr("Color generation internals"),
            icon: "construction",
            component: "modules/settings/AdvancedConfig.qml"
        },
        {
            name: Translation.tr("About"),
            subtitle: Translation.tr("Distro and dotfiles info"),
            icon: "info",
            component: "modules/settings/About.qml"
        }
    ]
    property int currentPage: 0

    visible: true
    onClosing: Qt.quit()
    title: "illogical-impulse Settings"

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0; // Settings app always only sets one var at a time so delay isn't needed
    }

    minimumWidth: 900
    minimumHeight: 600
    width: 1250
    height: 820
    color: Appearance.m3colors.m3background

    function goToPage(index) {
        root.currentPage = Math.max(0, Math.min(index, root.pages.length - 1));
    }

    // Search hit selected: switch to its page, then scroll it into view. The
    // page has to be laid out at its new size before its position is meaningful,
    // hence the deferred reveal.
    function openSearchResult(entry) {
        if (!entry)
            return;
        const context = SettingsSearch.resolveContext(entry.target);
        if (context.pageIndex < 0)
            return;
        // Clear through the field, not the singleton: the field's onTextChanged
        // owns the query, so clearing only the singleton gets immediately undone.
        searchField.text = "";
        root.goToPage(context.pageIndex);
        Qt.callLater(() => {
            const pageItem = pageRepeater.itemAt(context.pageIndex)?.pageItem ?? null;
            if (pageItem?.revealRow)
                pageItem.revealRow(entry.target);
        });
    }

    Shortcut {
        sequences: ["Ctrl+F"]
        onActivated: searchField.forceSearchFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Keys.onPressed: event => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.goToPage(root.currentPage + 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.goToPage(root.currentPage - 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pages.length;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length;
                    event.accepted = true;
                }
            }
        }

        Item { // Header: title, search, window controls
            Layout.fillWidth: true
            implicitHeight: 78

            StyledText {
                anchors {
                    left: parent.left
                    leftMargin: 28
                    verticalCenter: parent.verticalCenter
                }
                text: Translation.tr("Settings")
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.huge
                    variableAxes: Appearance.font.variableAxes.title
                }
                color: Appearance.colors.colOnSurface
            }

            SettingsSearchField {
                id: searchField
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                width: Math.min(520, parent.width * 0.42)
                onTextChanged: SettingsSearch.query = text
                onEscaped: {
                    text = "";
                    focus = false;
                }
            }

            RippleButton { // Window controls: close only
                visible: Config.options?.windows.showTitlebar ?? true
                anchors {
                    right: parent.right
                    rightMargin: 16
                    verticalCenter: parent.verticalCenter
                }
                buttonRadius: Appearance.rounding.full
                implicitWidth: 38
                implicitHeight: 38
                onClicked: root.close()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "close"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        RowLayout { // Sidebar + content
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 16
            spacing: 16

            ColumnLayout { // Sidebar
                Layout.fillHeight: true
                Layout.fillWidth: false
                // Pin the width from all three sides: children are fillWidth, so
                // preferredWidth alone loses to their implicit sizing.
                Layout.minimumWidth: 268
                Layout.preferredWidth: 268
                Layout.maximumWidth: 268
                spacing: 12

                StyledFlickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: navColumn.implicitHeight

                    ColumnLayout {
                        id: navColumn
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: root.pages

                            SettingsNavItem {
                                required property var modelData
                                required property int index

                                icon: modelData.icon
                                iconRotation: modelData.iconRotation ?? 0
                                title: modelData.name
                                subtitle: modelData.subtitle ?? ""
                                selected: root.currentPage === index && !SettingsSearch.searching
                                onClicked: {
                                    searchField.text = "";
                                    root.goToPage(index);
                                }
                            }
                        }
                    }
                }

                FloatingActionButton {
                    id: fab
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    property bool justCopied: false
                    iconText: justCopied ? "check" : "edit"
                    buttonText: justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                    expanded: true
                    downAction: () => {
                        Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                    }
                    altAction: () => {
                        Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                        fab.justCopied = true;
                        revertTextTimer.restart();
                    }

                    Timer {
                        id: revertTextTimer
                        interval: 1500
                        onTriggered: fab.justCopied = false
                    }

                    StyledToolTip {
                        text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                    }
                }
            }

            Rectangle { // Content surface
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLowest
                radius: Appearance.rounding.windowRounding
                clip: true

                SettingsSearchResults {
                    anchors.fill: parent
                    visible: SettingsSearch.searching
                    onResultActivated: entry => root.openSearchResult(entry)
                }

                Item { // Page host
                    anchors.fill: parent
                    visible: !SettingsSearch.searching

                    Repeater {
                        id: pageRepeater
                        model: root.pages

                        // Every page stays loaded rather than swapping a single
                        // Loader: that's what lets the search index cover all of
                        // them, and it makes switching pages instant.
                        Item {
                            required property var modelData
                            required property int index
                            property alias pageItem: pageLoader.item

                            anchors.fill: parent
                            visible: root.currentPage === index
                            opacity: visible ? 1 : 0

                            Behavior on opacity {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }

                            Loader {
                                id: pageLoader
                                anchors.fill: parent
                                active: Config.ready
                                source: modelData.component

                                onLoaded: {
                                    if (item.settingsPageIndex !== undefined)
                                        item.settingsPageIndex = index;
                                    if (item.settingsPageName !== undefined)
                                        item.settingsPageName = modelData.name;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
