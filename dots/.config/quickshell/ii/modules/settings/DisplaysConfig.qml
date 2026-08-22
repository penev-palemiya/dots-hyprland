import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components
import "../../services/displays/MonitorRules.js" as MonitorRules

SettingsSubPage {
    id: root
    property var draft: ({ rules: [], monitorCapabilities: ({}) })
    property var originalDraft: ({ rules: [], monitorCapabilities: ({}) })
    property string selectedOutput: ""
    property bool topologyChangedWhileDirty: false
    readonly property bool hasChanges: JSON.stringify(draft.rules) !== JSON.stringify(originalDraft.rules)
    readonly property var validation: MonitorRules.validateDraft(draft)
    readonly property var selectedRule: draft.rules.find(rule => rule.output === selectedOutput) ?? null

    function resetDraft() {
        const next = MonitorRules.draftFromMonitors(DisplaysService.monitors);
        draft = MonitorRules.clone(next);
        originalDraft = MonitorRules.clone(next);
        selectedOutput = draft.rules[0]?.output ?? "";
        topologyChangedWhileDirty = false;
    }
    function updateRule(output, changes) {
        draft = { rules: draft.rules.map(rule => rule.output === output ? Object.assign({}, rule, changes) : rule), monitorCapabilities: draft.monitorCapabilities };
    }
    function selectedModes() { return draft.monitorCapabilities[selectedOutput]?.modes ?? []; }
    function resolutions() {
        const found = {};
        for (const mode of selectedModes()) found[`${mode.width}x${mode.height}`] = { width: mode.width, height: mode.height };
        return Object.values(found);
    }
    function refreshes() {
        if (!selectedRule?.mode) return [];
        const matching = selectedModes().filter(mode => mode.width === selectedRule.mode.width && mode.height === selectedRule.mode.height);
        // Hyprland commonly reports current 59.997 while availableModes says
        // 60.00. The current mode is still a real valid option.
        return matching.length > 0 ? matching : [selectedRule.mode];
    }
    function validScales() {
        if (!selectedRule?.mode) return [];
        const candidates = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, selectedRule.scale];
        return [...new Set(candidates)].filter(scale => {
            const candidate = Object.assign({}, selectedRule, { scale });
            const size = MonitorRules.effectiveLogicalSize(candidate);
            return size && Math.abs(size.width - Math.round(size.width)) < 0.0001 && Math.abs(size.height - Math.round(size.height)) < 0.0001;
        }).sort((a, b) => a - b);
    }
    function labelFor(rule) {
        const monitor = DisplaysService.monitorByName(rule.output);
        if (monitor?.description) return monitor.description;
        if (monitor?.make || monitor?.model) return `${monitor.make} ${monitor.model}`.trim();
        return rule.output;
    }
    function mirrorTargets() { return draft.rules.filter(rule => rule.output !== selectedOutput && rule.enabled && !rule.mirrorOf); }
    function comboWidth(items) {
        let longest = 0;
        for (const item of items ?? []) {
            const label = typeof item === "string" ? item : (item.label ?? "");
            longest = Math.max(longest, String(label).length);
        }
        // Text width approximation plus horizontal padding and chevron. A
        // per-control cap keeps a long monitor name from breaking a narrow page.
        return Math.max(120, Math.min(280, longest * Appearance.font.pixelSize.normal * 0.62 + 56));
    }

    Component.onCompleted: resetDraft()
    Connections {
        target: DisplaysService
        function onTopologySignatureChanged() {
            if (root.hasChanges) root.topologyChangedWhileDirty = true;
            else root.resetDraft();
        }
    }

    SettingsGroup {
        title: Translation.tr("Display arrangement")
        SettingsRow {
            visible: DisplaysService.lastError.length > 0
            icon: "error"
            title: Translation.tr("Could not load displays")
            description: DisplaysService.lastError
            registerInSearch: false
        }
        SettingsRow {
            visible: root.topologyChangedWhileDirty
            icon: "warning"
            title: Translation.tr("Displays changed")
            description: Translation.tr("Your draft was kept. Reset it before applying changes for the new display layout.")
            registerInSearch: false
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 250
            visible: DisplaysService.monitors.length > 0
            Rectangle { anchors.fill: parent; color: Appearance.colors.colSurfaceContainerHighest; radius: 16 }
            Item {
                id: board
                anchors.fill: parent; anchors.margins: 18
                property var bounds: MonitorRules.layoutBounds(root.draft.rules) ?? ({ x: 0, y: 0, width: 1, height: 1 })
                property real presentationScale: Math.min(width / Math.max(1, bounds.width), height / Math.max(1, bounds.height)) * 0.82
                property real offsetX: (width - bounds.width * presentationScale) / 2 - bounds.x * presentationScale
                property real offsetY: (height - bounds.height * presentationScale) / 2 - bounds.y * presentationScale
                Repeater {
                    model: root.draft.rules.filter(rule => rule.enabled && !rule.mirrorOf)
                    Rectangle {
                        required property var modelData
                        property var rule: modelData
                        x: board.offsetX + rule.x * board.presentationScale
                        y: board.offsetY + rule.y * board.presentationScale
                        width: Math.max(70, MonitorRules.logicalRect(rule).width * board.presentationScale)
                        height: Math.max(50, MonitorRules.logicalRect(rule).height * board.presentationScale)
                        radius: 8; border.width: root.selectedOutput === rule.output ? 3 : 1
                        border.color: root.selectedOutput === rule.output ? Appearance.colors.colPrimary : Appearance.colors.colOutline
                        color: Appearance.colors.colSurfaceContainerHigh
                        StyledText { anchors.centerIn: parent; text: `${root.labelFor(rule)}\n${rule.output}`; horizontalAlignment: Text.AlignHCenter; color: Appearance.colors.colOnSurface }
                        MouseArea {
                            anchors.fill: parent; drag.target: parent
                            onClicked: root.selectedOutput = rule.output
                            onReleased: {
                                const x = Math.round((parent.x - board.offsetX) / board.presentationScale);
                                const y = Math.round((parent.y - board.offsetY) / board.presentationScale);
                                const next = Object.assign({}, rule, { x, y });
                                const candidates = MonitorRules.snapCandidatePositions(next, root.draft.rules, 16);
                                let snapped = { x, y };
                                for (const candidate of candidates) snapped[candidate.axis] = candidate.value;
                                root.updateRule(rule.output, snapped);
                            }
                        }
                    }
                }
                Repeater {
                    model: root.draft.rules.filter(rule => rule.enabled && rule.mirrorOf)
                    StyledText { required property var modelData; text: `${modelData.output} → ${modelData.mirrorOf}`; color: Appearance.colors.colOnSurfaceVariant; x: 4; y: index * 22 }
                }
            }
        }
        SettingsRow {
            icon: "monitor"
            title: Translation.tr("Selected display")
            description: root.selectedRule ? `${root.labelFor(root.selectedRule)} — ${root.selectedRule.output}` : Translation.tr("No display selected")
            registerInSearch: false
        }
        SettingsRow {
            icon: "monitor"
            title: Translation.tr("Identify displays")
            description: Translation.tr("Show each display name briefly")
            clickable: true
            onClicked: DisplayOverlayState.showIdentify()
        }
    }

    SettingsGroup {
        visible: root.selectedRule !== null
        title: Translation.tr("Display settings")
        SettingsToggleRow { icon: "desktop_windows"; title: Translation.tr("Enable display"); checked: root.selectedRule?.enabled ?? false; onToggled: checked => root.updateRule(root.selectedOutput, { enabled: checked }) }
        SettingsRow {
            icon: "call_split"; title: Translation.tr("Use as")
            StyledComboBox { model: [Translation.tr("Extend desktop"), Translation.tr("Mirror another display")]; width: root.comboWidth(model); currentIndex: root.selectedRule?.mirrorOf ? 1 : 0; onActivated: index => root.updateRule(root.selectedOutput, { mirrorOf: index === 0 ? "" : (root.mirrorTargets()[0]?.output ?? "") }) }
        }
        SettingsRow {
            visible: Boolean(root.selectedRule?.mirrorOf)
            icon: "screen_share"; title: Translation.tr("Mirror target")
            StyledComboBox { textRole: "label"; model: root.mirrorTargets().map(rule => ({ label: root.labelFor(rule), output: rule.output })); width: root.comboWidth(model); currentIndex: model.findIndex(item => item.output === root.selectedRule?.mirrorOf); onActivated: index => root.updateRule(root.selectedOutput, { mirrorOf: model[index].output }) }
        }
        SettingsRow {
            visible: !root.selectedRule?.mirrorOf
            icon: "aspect_ratio"; title: Translation.tr("Resolution")
            StyledComboBox { textRole: "label"; model: root.resolutions().map(value => ({ label: `${value.width} × ${value.height}`, value })); width: root.comboWidth(model); currentIndex: model.findIndex(item => item.value.width === root.selectedRule?.mode?.width && item.value.height === root.selectedRule?.mode?.height); onActivated: index => { const value = model[index].value; const mode = root.selectedModes().find(item => item.width === value.width && item.height === value.height); root.updateRule(root.selectedOutput, { mode: { width: value.width, height: value.height, refreshRate: mode.refreshRate } }); } }
        }
        SettingsRow {
            visible: !root.selectedRule?.mirrorOf
            icon: "speed"; title: Translation.tr("Refresh rate")
            StyledComboBox { textRole: "label"; model: root.refreshes().map(value => ({ label: `${Math.round(value.refreshRate)} Hz`, value })); width: root.comboWidth(model); currentIndex: model.findIndex(item => Math.abs(item.value.refreshRate - root.selectedRule?.mode?.refreshRate) < 0.1); onActivated: index => root.updateRule(root.selectedOutput, { mode: Object.assign({}, root.selectedRule.mode, { refreshRate: model[index].value.refreshRate }) }) }
        }
        SettingsRow {
            icon: "zoom_out_map"; title: Translation.tr("Scale")
            StyledComboBox { textRole: "label"; model: root.validScales().map(value => ({ label: `${Math.round(value * 100)}%`, value })); width: root.comboWidth(model); currentIndex: model.findIndex(item => item.value === root.selectedRule?.scale); onActivated: index => root.updateRule(root.selectedOutput, { scale: model[index].value }) }
        }
        SettingsRow {
            icon: "screen_rotation"; title: Translation.tr("Orientation")
            StyledComboBox { textRole: "label"; model: [{label: Translation.tr("Landscape"), value: 0}, {label: Translation.tr("Portrait left"), value: 1}, {label: Translation.tr("Landscape flipped"), value: 2}, {label: Translation.tr("Portrait right"), value: 3}]; width: root.comboWidth(model); currentIndex: model.findIndex(item => item.value === root.selectedRule?.transform); onActivated: index => root.updateRule(root.selectedOutput, { transform: model[index].value }) }
        }
    }

    SettingsGroup {
        title: Translation.tr("Apply changes")
        SettingsRow { visible: root.validation.errors.length > 0; icon: "error"; title: Translation.tr("Fix display configuration errors before applying"); description: root.validation.errors.map(issue => issue.message).join(" "); registerInSearch: false }
        SettingsRow { visible: root.validation.warnings.length > 0; icon: "warning"; title: Translation.tr("Display configuration warnings"); description: root.validation.warnings.map(issue => issue.message).join(" "); registerInSearch: false }
        SettingsRow {
            icon: "restart_alt"; title: Translation.tr("Reset changes"); clickable: root.hasChanges
            enabled: root.hasChanges; onClicked: root.resetDraft()
        }
        SettingsRow {
            icon: "check"; title: Translation.tr("Apply"); description: root.hasChanges ? Translation.tr("Preview changes before keeping them") : Translation.tr("No changes to apply")
            clickable: root.hasChanges && root.validation.valid && !root.topologyChangedWhileDirty
            enabled: clickable
            onClicked: DisplaysPreview.beginPreview(root.draft)
        }
    }

}
