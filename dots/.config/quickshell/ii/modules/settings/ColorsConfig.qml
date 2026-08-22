import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    readonly property var paletteStyles: [
        { value: "scheme-neutral", label: Translation.tr("Balanced"), description: Translation.tr("Soft and neutral") },
        { value: "scheme-tonal-spot", label: Translation.tr("Tonal"), description: Translation.tr("Material tonal character") },
        { value: "scheme-expressive", label: Translation.tr("Expressive"), description: Translation.tr("Stronger color relationships") },
        { value: "scheme-fidelity", label: Translation.tr("Fidelity"), description: Translation.tr("Stays closer to the source") },
        { value: "scheme-monochrome", label: Translation.tr("Monochrome"), description: Translation.tr("Minimal chroma") }
    ]
    readonly property string generatedSourcePath: `${Directories.state}/user/generated/color.txt`
    readonly property string derivedSourceColor: root.normalizeHex(sourceFile.text().trim())
    property string customDraft: ""
    property string pendingType: ""
    property string pendingColor: ""
    property string errorText: ""
    property bool busy: paletteProcess.running

    function normalizeHex(value) {
        const candidate = (value || "").trim();
        return /^#[0-9a-fA-F]{6}$/.test(candidate) ? candidate.toUpperCase() : "";
    }

    function fallbackSourceColor() {
        const derived = root.derivedSourceColor;
        if (derived.length > 0)
            return derived;
        return root.colorToHex(Appearance.m3colors.m3primary);
    }

    function colorToHex(color) {
        const value = Qt.color(color).toString();
        const match = value.match(/^#[0-9a-fA-F]{6}/);
        return match ? match[0].toUpperCase() : "#6750A4";
    }

    function generationType(type) {
        return ["scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-tonal-spot", "scheme-vibrant", "scheme-smart"].includes(type)
            ? type
            : "scheme-tonal-spot";
    }

    function generate(type, color) {
        if (root.busy)
            return;
        root.errorText = "";
        root.pendingType = root.generationType(type);
        root.pendingColor = color || "";
        paletteProcess.running = true;
    }

    function selectSource(custom) {
        if (custom) {
            if (Config.options.appearance.palette.accentColor.length > 0)
                root.customDraft = Config.options.appearance.palette.accentColor;
            else
                root.customDraft = root.fallbackSourceColor();
            colorField.text = root.customDraft;
            root.generate(Config.options.appearance.palette.type, root.customDraft);
        } else {
            root.generate(Config.options.appearance.palette.type, "");
        }
    }

    function commitCustomDraft() {
        const value = root.normalizeHex(colorField.text);
        if (value.length === 0) {
            root.errorText = Translation.tr("Enter a valid color such as #21B5C7.");
            return;
        }
        root.customDraft = value;
        root.generate(Config.options.appearance.palette.type, value);
    }

    function selectStyle(value) {
        root.generate(value, Config.options.appearance.palette.accentColor);
    }

    FileView {
        id: sourceFile
        path: Qt.resolvedUrl(root.generatedSourcePath)
        watchChanges: true
    }

    Process {
        id: paletteProcess
        command: {
            const args = [Directories.scriptPath + "/colors/generate-shell-palette.sh", "--mode", Appearance.m3colors.darkmode ? "dark" : "light", "--scheme", root.pendingType];
            if (root.pendingColor.length > 0)
                args.push("--color", root.pendingColor);
            return args;
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Config.options.appearance.palette.type = root.pendingType;
                Config.options.appearance.palette.accentColor = root.pendingColor;
                root.customDraft = root.pendingColor;
                root.errorText = "";
            } else {
                root.errorText = Translation.tr("Could not generate the shell palette; the previous palette was kept.");
            }
            root.pendingType = "";
            root.pendingColor = "";
        }
    }

    SettingsGroup {
        title: Translation.tr("Color source")

        SettingsRow {
            icon: "palette"
            title: Translation.tr("Source")
            description: root.errorText.length > 0 ? root.errorText : Translation.tr("Choose where the shell palette comes from.")

            ConfigSelectionArray {
                enabled: !root.busy
                currentValue: Config.options.appearance.palette.accentColor.length > 0 ? "custom" : "wallpaper"
                onSelected: value => root.selectSource(value === "custom")
                options: [
                    { value: "wallpaper", displayName: Translation.tr("Wallpaper"), icon: "wallpaper" },
                    { value: "custom", displayName: Translation.tr("Custom"), icon: "colorize" }
                ]
            }
        }

        SettingsRow {
            visible: Config.options.appearance.palette.accentColor.length === 0
            icon: "auto_awesome"
            title: Translation.tr("Wallpaper-derived color")
            description: Translation.tr("Colors are derived from the current wallpaper.")

            Rectangle {
                implicitWidth: 92
                implicitHeight: 36
                radius: Appearance.rounding.small
                color: root.derivedSourceColor.length > 0 ? root.derivedSourceColor : Appearance.colors.colPrimary

                StyledText {
                    anchors.centerIn: parent
                    text: root.derivedSourceColor || Translation.tr("Unavailable")
                    color: ColorUtils.colorWithLightnessOf("#ffffff", parent.color).hslLightness < 0.55 ? "#ffffff" : "#111111"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }

        SettingsRow {
            visible: Config.options.appearance.palette.accentColor.length > 0
            icon: "colorize"
            title: Translation.tr("Custom color")
            description: Translation.tr("Use a six-digit RGB color for the shell palette.")

            RowLayout {
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: Appearance.rounding.small
                    color: root.normalizeHex(colorField.text) || Appearance.colors.colPrimary
                }

                MaterialTextField {
                    id: colorField
                    Layout.preferredWidth: 140
                    implicitHeight: 42
                    text: root.customDraft || Config.options.appearance.palette.accentColor
                    placeholderText: "#RRGGBB"
                    enabled: !root.busy
                    onEditingFinished: root.commitCustomDraft()
                }

                RippleButtonWithIcon {
                    materialIcon: "check"
                    mainText: Translation.tr("Apply")
                    enabled: !root.busy && root.normalizeHex(colorField.text).length > 0
                    onClicked: root.commitCustomDraft()
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Palette style")

        SettingsRow {
            icon: "colors"
            title: Translation.tr("Shell palette")
            description: Translation.tr("Select a style for generated shell colors.")

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.paletteStyles

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 142
                        height: 62
                        radius: Appearance.rounding.small
                        color: Config.options.appearance.palette.type === modelData.value ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                        border.width: Config.options.appearance.palette.type === modelData.value ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                        opacity: root.busy ? 0.55 : 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: Appearance.colors.colOnLayer2
                                font.weight: Font.Medium
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.description
                                color: Appearance.colors.colOnSurfaceVariant
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectStyle(modelData.value)
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Preview")

        SettingsRow {
            icon: "preview"
            title: Translation.tr("Shell palette preview")
            description: Translation.tr("A live sample of the generated shell colors.")

            Rectangle {
                implicitWidth: 300
                implicitHeight: 108
                radius: Appearance.rounding.small
                color: Appearance.m3colors.m3surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Example surface")
                        color: Appearance.m3colors.m3onSurface
                        font.weight: Font.Medium
                    }

                    RowLayout {
                        spacing: 8

                        Rectangle {
                            implicitWidth: 112
                            implicitHeight: 32
                            radius: Appearance.rounding.small
                            color: Appearance.m3colors.m3primary
                            StyledText { anchors.centerIn: parent; text: Translation.tr("Primary action"); color: Appearance.m3colors.m3onPrimary; font.pixelSize: Appearance.font.pixelSize.smaller }
                        }
                        Rectangle {
                            implicitWidth: 112
                            implicitHeight: 32
                            radius: Appearance.rounding.small
                            color: Appearance.m3colors.m3secondaryContainer
                            StyledText { anchors.centerIn: parent; text: Translation.tr("Secondary"); color: Appearance.m3colors.m3onSecondaryContainer; font.pixelSize: Appearance.font.pixelSize.smaller }
                        }
                    }
                }
            }
        }
    }
}
