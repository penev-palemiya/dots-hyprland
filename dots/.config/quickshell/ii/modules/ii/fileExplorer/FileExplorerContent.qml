import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

// Fork of WallpaperSelectorContent.qml. Same grid-browsing shell (address
// bar, quick-access sidebar, keyboard navigation, filter field); the
// wallpaper-only pieces (thumbnail generation, "select this as wallpaper",
// dark/light toggle) are gone. `activated()` opens directories, and opens
// files with `gio open`.
//
// Displays one FileExplorerPane (`pane`), passed in by whatever hosts this -
// a plain single window today, a split pane or tab once those exist. All
// directory/history/selection state lives on that pane, not here or in a
// global singleton, so several instances of this component can coexist
// showing different folders. The one thing genuinely shared across every
// pane is the copy/cut clipboard and openFile(), both on the FileExplorer
// singleton - see its doc comment for why those two stayed shared.
//
// Hosted in a normal ApplicationWindow (FileExplorerWindow.qml), not a
// layer-shell overlay - so closing means emitting closeRequested() for the
// window to act on, not flipping a GlobalStates flag, and Escape does NOT
// close the window: ordinary file managers (Nautilus, Dolphin) don't bind
// Escape to quit, and a window that vanishes on a stray Escape while
// navigating would be a surprise this component shouldn't spring on its own.
MouseArea {
    id: root
    // The pane this content displays - directory, history, selection all
    // come from here rather than a global singleton, so multiple instances
    // of this component (split view, tabs) each show their own independent
    // view. See FileExplorerPane.qml for why this had to move out of the
    // old services/FileExplorer.qml Singleton.
    required property FileExplorerPane pane
    property int columns: 4
    property real previewCellAspectRatio: 4 / 3

    signal closeRequested()
    // Fired on any pointer activity over this pane - used by
    // FileExplorerSplitView to track which side of a split is "active"
    // (gets keyboard shortcuts, determines the window title). A HoverHandler
    // below drives this rather than requiring an actual click: this
    // MouseArea's own acceptedButtons is deliberately just Back/Forward (see
    // onPressed below), so a plain left click never reaches an onPressed
    // here at all - it falls through to the grid/delegates underneath.
    signal pointerActive()

    function handleFilePasting(event) {
        // The explorer's own copy/cut clipboard (FileExplorer.clipboardPaths)
        // takes priority over Cliphist's "paste a path to navigate there"
        // trick below: after Ctrl+C/Ctrl+X on a selection, Ctrl+V pasting
        // files is the only sane reading of the keystroke. Falling through to
        // "navigate to this path instead" would silently discard a pending
        // file operation the user very deliberately just queued.
        if (FileExplorer.clipboardPaths.length > 0) {
            FileExplorer.pasteClipboard(root.pane);
            event.accepted = true;
            return;
        }
        const currentClipboardEntry = Cliphist.entries[0];
        if (/^\d+\tfile:\/\/\S+/.test(currentClipboardEntry)) {
            const url = StringUtils.cleanCliphistEntry(currentClipboardEntry);
            root.pane.setDirectory(FileUtils.trimFileProtocol(decodeURIComponent(url)));
            event.accepted = true;
        } else {
            event.accepted = false; // No path, let text pasting proceed
        }
    }

    function activateEntry(fileModelData) {
        if (!fileModelData) return;
        if (fileModelData.fileIsDir) {
            root.pane.setDirectory(fileModelData.filePath);
            filterField.text = "";
        } else {
            FileExplorer.openFile(fileModelData.filePath);
        }
    }

    acceptedButtons: Qt.BackButton | Qt.ForwardButton
    onPressed: event => {
        if (event.button === Qt.BackButton) {
            root.pane.navigateBack();
        } else if (event.button === Qt.ForwardButton) {
            root.pane.navigateForward();
        }
    }

    Keys.onPressed: event => {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) { // Intercept Ctrl+V to handle "paste to go to" in pickers
            root.handleFilePasting(event);
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Up) {
            root.pane.navigateUp();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) {
            root.pane.navigateBack();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Right) {
            root.pane.navigateForward();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            grid.moveSelection(-1, event.modifiers & Qt.ShiftModifier);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            grid.moveSelection(1, event.modifiers & Qt.ShiftModifier);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            grid.moveSelection(-grid.columns, event.modifiers & Qt.ShiftModifier);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            grid.moveSelection(grid.columns, event.modifiers & Qt.ShiftModifier);
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
            root.pane.selectedPaths = root.pane.entries.slice();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
            FileExplorer.copySelectionToClipboard(root.pane);
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_X) {
            FileExplorer.cutSelectionToClipboard(root.pane);
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete) {
            root.pane.deleteSelection();
            event.accepted = true;
        } else if (event.key === Qt.Key_F2) {
            grid.beginRenameCurrent();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            grid.activateCurrent();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            if (filterField.text.length > 0) {
                filterField.text = filterField.text.substring(0, filterField.text.length - 1);
            }
            filterField.forceActiveFocus();
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_L) {
            addressBar.focusBreadcrumb();
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash) {
            filterField.forceActiveFocus();
            event.accepted = true;
        } else {
            if (event.text.length > 0) {
                filterField.text += event.text;
                filterField.cursorPosition = filterField.text.length;
                filterField.forceActiveFocus();
            }
            event.accepted = true;
        }
    }

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: mainLayout.implicitWidth

    HoverHandler {
        onHoveredChanged: if (hovered) root.pointerActive()
    }

    // No StyledRectangularShadow/elevationMargin here, unlike
    // WallpaperSelectorContent: those exist to make an overlay floating on
    // top of the desktop read as a raised surface. Hosted in an ordinary
    // window, this content already IS the window - the window manager's own
    // decoration (or lack of it) is what frames it, so it fills the window
    // edge to edge with no border/radius/shadow of its own.
    Rectangle {
        id: gridBackground
        anchors.fill: parent
        focus: true
        color: Appearance.colors.colLayer0

        property int calculatedRows: Math.ceil(grid.count / grid.columns)

        implicitWidth: gridColumnLayout.implicitWidth
        implicitHeight: gridColumnLayout.implicitHeight

        RowLayout {
            id: mainLayout
            anchors.fill: parent
            spacing: -4

            Rectangle {
                Layout.fillHeight: true
                Layout.margins: 4
                implicitWidth: quickDirColumnLayout.implicitWidth
                implicitHeight: quickDirColumnLayout.implicitHeight
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.normal

                ColumnLayout {
                    id: quickDirColumnLayout
                    anchors.fill: parent
                    spacing: 0

                    StyledText {
                        Layout.margins: 12
                        font {
                            pixelSize: Appearance.font.pixelSize.normal
                            weight: Font.Medium
                        }
                        text: Translation.tr("Files")
                    }
                    ListView {
                        // Quick dirs
                        Layout.fillHeight: true
                        Layout.margins: 4
                        implicitWidth: 140
                        clip: true
                        model: [
                            {
                                icon: "home",
                                name: "Home",
                                path: Directories.home
                            },
                            {
                                icon: "docs",
                                name: "Documents",
                                path: Directories.documents
                            },
                            {
                                icon: "download",
                                name: "Downloads",
                                path: Directories.downloads
                            },
                            {
                                icon: "image",
                                name: "Pictures",
                                path: Directories.pictures
                            },
                            {
                                icon: "movie",
                                name: "Videos",
                                path: Directories.videos
                            },
                            {
                                icon: "library_music",
                                name: "Music",
                                path: Directories.music
                            }]
                        delegate: RippleButton {
                            id: quickDirButton
                            required property var modelData
                            anchors {
                                left: parent.left
                                right: parent.right
                            }
                            onClicked: root.pane.setDirectory(quickDirButton.modelData.path)
                            toggled: root.pane.directory === Qt.resolvedUrl(modelData.path)
                            colBackgroundToggled: Appearance.colors.colSecondaryContainer
                            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                            colRippleToggled: Appearance.colors.colSecondaryContainerActive
                            buttonRadius: height / 2
                            implicitHeight: 38

                            contentItem: RowLayout {
                                MaterialSymbol {
                                    color: quickDirButton.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                    iconSize: Appearance.font.pixelSize.larger
                                    text: quickDirButton.modelData.icon
                                    fill: quickDirButton.toggled ? 1 : 0
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                    color: quickDirButton.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                    text: quickDirButton.modelData.name
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: gridColumnLayout
                Layout.fillWidth: true
                Layout.fillHeight: true

                FileExplorerAddressBar {
                    id: addressBar
                    Layout.margins: 4
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    directory: root.pane.effectiveDirectory
                    canGoBack: root.pane.folderModel.currentFolderHistoryIndex > 0
                    canGoForward: root.pane.folderModel.currentFolderHistoryIndex < root.pane.folderModel.folderHistory.length - 1
                    onNavigateToDirectory: path => {
                        root.pane.setDirectory(path.length == 0 ? "/" : path);
                    }
                    onNavigateBack: root.pane.navigateBack()
                    onNavigateForward: root.pane.navigateForward()
                    onPasteIntoRequested: path => {
                        FileExplorer.pasteClipboard(root.pane, path);
                    }
                    radius: Appearance.rounding.normal
                }

                Item {
                    id: gridDisplayRegion
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridView {
                        id: grid
                        visible: root.pane.folderModel.count > 0

                        readonly property int columns: root.columns
                        readonly property int rows: Math.max(1, Math.ceil(count / columns))
                        property int currentIndex: 0

                        anchors.fill: parent
                        cellWidth: width / root.columns
                        cellHeight: cellWidth / root.previewCellAspectRatio
                        interactive: true
                        clip: true
                        keyNavigationWraps: true
                        boundsBehavior: Flickable.StopAtBounds
                        bottomMargin: extraOptions.implicitHeight
                        ScrollBar.vertical: StyledScrollBar {}

                        // Despite the name (kept from WallpaperSelectorContent,
                        // where there was only ever one selectable thing),
                        // this moves the keyboard CURSOR - currentIndex. It
                        // also drives FileExplorer's selection model so arrow
                        // navigation behaves like every other file manager:
                        // the cursor and the selection are the same thing
                        // until Shift/Ctrl says otherwise. shiftHeld extends
                        // the range from the existing anchor instead of
                        // collapsing to a single new selection.
                        function moveSelection(delta, shiftHeld = false) {
                            currentIndex = Math.max(0, Math.min(grid.model.count - 1, currentIndex + delta));
                            positionViewAtIndex(currentIndex, GridView.Contain);
                            const path = grid.model.get(currentIndex, "filePath");
                            if (!path) return;
                            if (shiftHeld) {
                                root.pane.selectRange(currentIndex);
                            } else {
                                root.pane.selectOnly(path, currentIndex);
                            }
                        }

                        function activateCurrent() {
                            const fileModelData = grid.model.get(currentIndex);
                            root.activateEntry(fileModelData);
                        }

                        // The path currently being renamed inline, or "" if
                        // none. A path rather than an index: the grid re-sorts
                        // and re-filters as files change, so an index held
                        // across that would end up pointing at a different
                        // row than the one the user started renaming.
                        property string renamingPath: ""

                        function beginRenameCurrent() {
                            const path = grid.model.get(currentIndex, "filePath");
                            if (path) grid.renamingPath = path;
                        }

                        function commitRename(oldPath, newName) {
                            grid.renamingPath = "";
                            if (newName.length === 0) return;
                            if (newName === FileUtils.fileNameForPath(oldPath)) return;
                            root.pane.renameEntry(oldPath, newName);
                        }

                        function cancelRename() {
                            grid.renamingPath = "";
                        }

                        // x/y/w/h are in rubberBandArea's coordinate space -
                        // i.e. the GridView's own visible viewport, NOT its
                        // scrolled content. Converted to content space by
                        // adding contentY (GridView doesn't scroll
                        // horizontally here, so contentX is left out) before
                        // comparing against each cell's row/column geometry,
                        // which IS in content space.
                        function selectWithinRubberBand(x, y, w, h) {
                            const top = y + grid.contentY;
                            const bottom = top + h;
                            const left = x;
                            const right = x + w;
                            const selected = [];
                            for (let i = 0; i < grid.count; i++) {
                                const row = Math.floor(i / grid.columns);
                                const col = i % grid.columns;
                                const cellLeft = col * grid.cellWidth;
                                const cellTop = row * grid.cellHeight;
                                const intersects = cellLeft < right && cellLeft + grid.cellWidth > left
                                    && cellTop < bottom && cellTop + grid.cellHeight > top;
                                if (intersects) {
                                    const path = grid.model.get(i, "filePath");
                                    if (path) selected.push(path);
                                }
                            }
                            root.pane.selectedPaths = selected;
                        }

                        model: root.pane.folderModel
                        onModelChanged: currentIndex = 0
                        delegate: FileExplorerDirectoryItem {
                            id: delegateRoot
                            required property var modelData
                            required property int index
                            fileModelData: modelData
                            // Bound to selectedPaths, not just to a locally
                            // toggled bool: pane.selectedPaths is the
                            // one selection model both this grid and any
                            // future context menu / operations act on.
                            property bool isSelected: root.pane.selectedPaths.indexOf(fileModelData.filePath) !== -1
                            isSelectedForMenu: isSelected
                            width: grid.cellWidth
                            height: grid.cellHeight
                            // Selected takes precedence over hover/keyboard-
                            // cursor - a selected item stays visibly selected
                            // while the mouse merely passes over a neighbour.
                            //
                            // Hover (containsMouse) and keyboard cursor
                            // (grid.currentIndex) are two separate states with
                            // separate lifetimes, checked independently rather
                            // than merged into one via onEntered writing into
                            // currentIndex as this used to do. That write had
                            // no matching reset: MouseArea has onEntered for
                            // "the pointer arrived here" but nothing fires for
                            // "the pointer left and landed on nothing", so
                            // currentIndex kept pointing at the last-hovered
                            // tile after the mouse moved off the grid
                            // entirely (off the window, or onto the sidebar/
                            // toolbar/address bar) - and that tile stayed lit
                            // forever, which is exactly the reported bug.
                            // containsMouse doesn't have this gap: Qt clears
                            // it the instant the pointer leaves each
                            // delegate, unconditionally, so it needs no
                            // explicit reset here at all.
                            colBackground: isSelected ? Appearance.colors.colPrimary
                                : (index === grid.currentIndex || containsMouse) ? Appearance.colors.colSecondaryContainer
                                : ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                            colText: isSelected ? Appearance.colors.colOnPrimary
                                : (index === grid.currentIndex || containsMouse) ? Appearance.colors.colOnSecondaryContainer
                                : Appearance.colors.colOnLayer0
                            renaming: grid.renamingPath === fileModelData.filePath
                            onRenameCommitted: newName => grid.commitRename(fileModelData.filePath, newName)
                            onRenameCancelled: grid.cancelRename()

                            onSelectRequested: modifiers => {
                                grid.currentIndex = index;
                                if (modifiers & Qt.ShiftModifier) {
                                    root.pane.selectRange(index);
                                } else if (modifiers & Qt.ControlModifier) {
                                    root.pane.toggleSelection(fileModelData.filePath, index);
                                } else {
                                    root.pane.selectOnly(fileModelData.filePath, index);
                                }
                            }

                            onActivated: {
                                root.activateEntry(fileModelData);
                            }

                            onContextMenuRequested: (x, y) => {
                                // isSelected has just been forced true by
                                // FileExplorerDirectoryItem itself (see its
                                // right-click handler) if it wasn't already,
                                // so pane.selectedPaths reflects "this entry,
                                // plus whatever else was already selected"
                                // by the time this runs. currentIndex is
                                // moved here regardless of whether selection
                                // changed, so Rename always acts on the
                                // right-clicked entry rather than whatever
                                // the keyboard cursor last pointed at.
                                grid.currentIndex = index;
                                const multiple = root.pane.selectedPaths.length > 1;
                                fileContextMenu.actions = [
                                    {
                                        text: Translation.tr("Open"),
                                        icon: "open_in_new",
                                        enabled: !multiple,
                                        onTriggered: () => root.activateEntry(fileModelData)
                                    },
                                    {
                                        text: Translation.tr("Rename"),
                                        icon: "edit",
                                        shortcut: "F2",
                                        enabled: !multiple,
                                        onTriggered: () => grid.beginRenameCurrent()
                                    },
                                    { separator: true },
                                    {
                                        text: Translation.tr("Copy"),
                                        icon: "content_copy",
                                        shortcut: "Ctrl+C",
                                        onTriggered: () => FileExplorer.copySelectionToClipboard(root.pane)
                                    },
                                    {
                                        text: Translation.tr("Cut"),
                                        icon: "content_cut",
                                        shortcut: "Ctrl+X",
                                        onTriggered: () => FileExplorer.cutSelectionToClipboard(root.pane)
                                    },
                                    { separator: true },
                                    {
                                        text: Translation.tr("Delete"),
                                        icon: "delete",
                                        shortcut: "Del",
                                        onTriggered: () => root.pane.deleteSelection()
                                    },
                                ];
                                fileContextMenu.openAt(x, y, delegateRoot);
                            }
                        }

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: gridDisplayRegion.width
                                height: gridDisplayRegion.height
                                radius: Appearance.rounding.normal
                            }
                        }
                    }

                    // Rubber-band multi-select: press-drag over empty grid
                    // space marquees every entry the rectangle touches, same
                    // as Nautilus/Explorer/most icon views.
                    //
                    // A separate MouseArea layered ON TOP of the GridView,
                    // not logic inside it - GridView is a Flickable, and a
                    // press-drag starting on its own empty space would
                    // otherwise be consumed as a flick/scroll gesture rather
                    // than reaching here at all.
                    //
                    // It only ever fires for a press that starts on genuinely
                    // empty space (grid.itemAt returns null there - checked
                    // BEFORE accepting the press): a press that lands on a
                    // delegate is explicitly declined (mouse.accepted =
                    // false) so it falls through to that delegate's own
                    // MouseArea underneath, leaving click/Ctrl+click/
                    // Shift+click/double-click on an item completely
                    // unaffected by this being layered above them.
                    MouseArea {
                        id: rubberBandArea
                        anchors.fill: parent
                        z: 1
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        property real originX: 0
                        property real originY: 0
                        property bool dragging: false

                        onPressed: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                // Right-click on empty grid space: only makes
                                // sense over a genuinely empty spot (itemAt
                                // null), for the same content/viewport
                                // coordinate reason as the left-click branch
                                // below - a right-click that landed on a
                                // delegate is this delegate's own menu to
                                // handle, not this background's.
                                if (grid.itemAt(mouse.x, mouse.y + grid.contentY)) {
                                    mouse.accepted = false;
                                    return;
                                }
                                emptySpaceContextMenu.actions = [
                                    {
                                        text: Translation.tr("Paste"),
                                        icon: "content_paste",
                                        shortcut: "Ctrl+V",
                                        enabled: FileExplorer.clipboardPaths.length > 0,
                                        onTriggered: () => FileExplorer.pasteClipboard(root.pane)
                                    },
                                    {
                                        text: Translation.tr("Select all"),
                                        icon: "select_all",
                                        shortcut: "Ctrl+A",
                                        onTriggered: () => root.pane.selectedPaths = root.pane.entries.slice()
                                    },
                                ];
                                emptySpaceContextMenu.openAt(mouse.x, mouse.y, rubberBandArea);
                                return;
                            }
                            // itemAt() takes CONTENT-space coordinates (it
                            // accounts for scrolling), while mouse.x/y here
                            // are in this MouseArea's own viewport space -
                            // the same content-vs-viewport distinction
                            // documented on selectWithinRubberBand below.
                            // Without adding contentY, this matched
                            // selectWithinRubberBand's coordinates only by
                            // accident whenever the grid happened to be
                            // scrolled to the top; scrolled any further, it
                            // could return null for a point actually on a
                            // delegate (letting a real click start a rubber
                            // band instead) or return a delegate for empty
                            // space (silently declining a click that should
                            // have cleared the selection) - which is exactly
                            // the "click empty space, selection doesn't
                            // clear" symptom this was reported as.
                            if (mouse.button !== Qt.LeftButton || grid.itemAt(mouse.x, mouse.y + grid.contentY)) {
                                mouse.accepted = false;
                                return;
                            }
                            rubberBandArea.originX = mouse.x;
                            rubberBandArea.originY = mouse.y;
                            rubberBandArea.dragging = false;
                            // GridView is a Flickable underneath this - left
                            // disabled while merely pressed (a plain click on
                            // empty space, handled in onReleased, should not
                            // fight interactive scrolling), and turned off
                            // only once movement confirms a drag is actually
                            // happening.
                        }

                        onPositionChanged: mouse => {
                            if (!(mouse.buttons & Qt.LeftButton)) return;
                            if (!rubberBandArea.dragging) {
                                // Small threshold before committing to a drag,
                                // so a slightly-imprecise click doesn't start
                                // a one-pixel marquee and clear the selection
                                // a plain click would have meant to keep.
                                const dx = mouse.x - rubberBandArea.originX;
                                const dy = mouse.y - rubberBandArea.originY;
                                if (dx * dx + dy * dy < 16) return;
                                rubberBandArea.dragging = true;
                                grid.interactive = false;
                            }
                            rubberBand.x = Math.min(rubberBandArea.originX, mouse.x);
                            rubberBand.y = Math.min(rubberBandArea.originY, mouse.y);
                            rubberBand.width = Math.abs(mouse.x - rubberBandArea.originX);
                            rubberBand.height = Math.abs(mouse.y - rubberBandArea.originY);
                            grid.selectWithinRubberBand(rubberBand.x, rubberBand.y, rubberBand.width, rubberBand.height);
                        }

                        onReleased: {
                            if (!rubberBandArea.dragging) {
                                // A plain click on empty space: clear the
                                // selection, matching every other file
                                // manager's "click nothing to deselect
                                // everything" behaviour.
                                root.pane.clearSelection();
                            }
                            rubberBandArea.dragging = false;
                            grid.interactive = true;
                            rubberBand.width = 0;
                            rubberBand.height = 0;
                        }

                        Rectangle {
                            id: rubberBand
                            visible: width > 0 && height > 0
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                            border.width: 1
                            border.color: Appearance.colors.colPrimary
                        }

                        FileExplorerContextMenu {
                            id: emptySpaceContextMenu
                        }
                    }

                    FileExplorerContextMenu {
                        id: fileContextMenu
                    }

                    Row {
                        id: extraOptions
                        anchors {
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                            bottomMargin: 8
                        }
                        spacing: 6
                        Toolbar {
                            ToolbarTextField {
                                id: filterField
                                placeholderText: focus ? Translation.tr("Search files") : Translation.tr("Hit \"/\" to search")

                                // Style
                                clip: true
                                font.pixelSize: Appearance.font.pixelSize.small

                                // Search
                                onTextChanged: {
                                    root.pane.searchQuery = text;
                                }

                                Keys.onPressed: event => {
                                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) { // Intercept Ctrl+V to handle "paste to go to" in pickers
                                        root.handleFilePasting(event);
                                        return;
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
                                        // Must be caught explicitly here, before
                                        // falling through to `event.accepted =
                                        // false` below: a TextField's own
                                        // "select all text" shortcut fires as a
                                        // native platform action on the control
                                        // itself, not as something that waits
                                        // for this handler's accepted flag - so
                                        // without this branch, Ctrl+A never
                                        // reached root.Keys.onPressed's
                                        // "select every grid entry" handling at
                                        // all (confirmed live: it silently
                                        // selected the field's own, empty text
                                        // instead of the grid).
                                        root.pane.selectedPaths = root.pane.entries.slice();
                                        event.accepted = true;
                                        return;
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
                                        // Same reasoning as Ctrl+A above: a
                                        // TextField answers Ctrl+C itself
                                        // ("copy selected text") before this
                                        // handler's accepted flag is ever
                                        // consulted, so root.Keys.onPressed's
                                        // Ctrl+C never fired at all - confirmed
                                        // live: clipboardPaths stayed empty and
                                        // a following paste did nothing.
                                        FileExplorer.copySelectionToClipboard(root.pane);
                                        event.accepted = true;
                                        return;
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_X) {
                                        FileExplorer.cutSelectionToClipboard(root.pane);
                                        event.accepted = true;
                                        return;
                                    } else if (event.key === Qt.Key_Delete) {
                                        // Not natively consumed by TextField
                                        // the way Ctrl+A/C/X are (Delete on
                                        // empty/fully-selected text is a
                                        // no-op there), but caught explicitly
                                        // anyway for the same reason as F2
                                        // below: falling through relies on
                                        // `text.length !== 0` not being true,
                                        // which is fragile to keep re-deriving
                                        // per key.
                                        root.pane.deleteSelection();
                                        event.accepted = true;
                                        return;
                                    } else if (event.key === Qt.Key_F2) {
                                        grid.beginRenameCurrent();
                                        event.accepted = true;
                                        return;
                                    } else if (text.length !== 0) {
                                        // No filtering, just navigate grid
                                        if (event.key === Qt.Key_Down) {
                                            grid.moveSelection(grid.columns);
                                            event.accepted = true;
                                            return;
                                        }
                                        if (event.key === Qt.Key_Up) {
                                            grid.moveSelection(-grid.columns);
                                            event.accepted = true;
                                            return;
                                        }
                                    }
                                    event.accepted = false;
                                }
                            }
                        }

                    }
                }
            }
        }
    }

    function focusSearch() {
        filterField.forceActiveFocus();
    }
}
