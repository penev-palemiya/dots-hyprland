import QtQuick
import QtQuick.Layouts
import qs.services as Services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    readonly property var enginePresets: [
        { label: Services.Translation.tr("Google"), value: "https://www.google.com/search?q=" },
        { label: Services.Translation.tr("DuckDuckGo"), value: "https://duckduckgo.com/?q=" },
        { label: Services.Translation.tr("Brave Search"), value: "https://search.brave.com/search?q=" },
        { label: Services.Translation.tr("Bing"), value: "https://www.bing.com/search?q=" },
        { label: Services.Translation.tr("Custom"), value: "" }
    ]
    readonly property bool customEngine: root.enginePresets.findIndex(item => item.value === Config.options.search.engineBaseUrl) < 0
    property string prefixErrorKey: ""
    property string prefixErrorText: ""
    property string webErrorText: ""

    function prefixValue(kind) {
        switch (kind) {
        case "app": return Config.options.search.prefix.app;
        case "action": return Config.options.search.prefix.action;
        case "clipboard": return Config.options.search.prefix.clipboard;
        case "emojis": return Config.options.search.prefix.emojis;
        case "math": return Config.options.search.prefix.math;
        case "shellCommand": return Config.options.search.prefix.shellCommand;
        case "webSearch": return Config.options.search.prefix.webSearch;
        default: return "";
        }
    }

    function setPrefix(kind, value) {
        switch (kind) {
        case "app": Config.options.search.prefix.app = value; break;
        case "action": Config.options.search.prefix.action = value; break;
        case "clipboard": Config.options.search.prefix.clipboard = value; break;
        case "emojis": Config.options.search.prefix.emojis = value; break;
        case "math": Config.options.search.prefix.math = value; break;
        case "shellCommand": Config.options.search.prefix.shellCommand = value; break;
        case "webSearch": Config.options.search.prefix.webSearch = value; break;
        }
    }

    function prefixError(kind, value) {
        const candidate = String(value ?? "").trim();
        if (candidate.length === 0)
            return Services.Translation.tr("Enter a shortcut prefix.");
        if (/\s/.test(candidate))
            return Services.Translation.tr("Prefixes cannot contain spaces.");
        if (candidate.length > 3)
            return Services.Translation.tr("Use at most 3 characters.");

        const kinds = ["app", "action", "clipboard", "emojis", "math", "shellCommand", "webSearch"];
        for (const other of kinds) {
            if (other === kind)
                continue;
            const otherValue = String(root.prefixValue(other));
            if (candidate === otherValue || candidate.startsWith(otherValue) || otherValue.startsWith(candidate))
                return Services.Translation.tr("That prefix conflicts with another search shortcut.");
        }
        return "";
    }

    function commitPrefix(kind, value) {
        const candidate = String(value ?? "").trim();
        const error = root.prefixError(kind, candidate);
        if (error.length > 0) {
            root.prefixErrorKey = kind;
            root.prefixErrorText = error;
            return false;
        }
        root.setPrefix(kind, candidate);
        root.prefixErrorKey = "";
        root.prefixErrorText = "";
        return true;
    }

    function prefixDescription(kind, normal) {
        return root.prefixErrorKey === kind ? root.prefixErrorText : normal;
    }

    function validEngineUrl(value) {
        const url = String(value ?? "").trim();
        return /^https?:\/\/[^\s]+$/i.test(url) && /[?&][^=]+=$/.test(url);
    }

    function commitEngineUrl(value) {
        const candidate = String(value ?? "").trim();
        if (!root.validEngineUrl(candidate)) {
            root.webErrorText = Services.Translation.tr("Use an HTTP or HTTPS URL ending with a query parameter, such as ?q=.");
            return false;
        }
        Config.options.search.engineBaseUrl = candidate;
        root.webErrorText = "";
        return true;
    }

    SettingsGroup {
        title: Services.Translation.tr("Search behavior")

        SettingsToggleRow {
            icon: "manage_search"
            title: Services.Translation.tr("Typo tolerance")
            description: Services.Translation.tr("Find results even when words are misspelled.")
            checked: Config.options.search.sloppy
            onToggled: checked => Config.options.search.sloppy = checked
        }

        SettingsToggleRow {
            icon: "bolt"
            title: Services.Translation.tr("Quick results")
            description: Services.Translation.tr("Show calculator, command, and web actions without typing their shortcut first.")
            checked: Config.options.search.prefix.showDefaultActionsWithoutPrefix
            onToggled: checked => Config.options.search.prefix.showDefaultActionsWithoutPrefix = checked
        }
    }

    SettingsGroup {
        title: Services.Translation.tr("Web search")

        SettingsRow {
            icon: "travel_explore"
            title: Services.Translation.tr("Search engine")
            description: root.webErrorText.length > 0 ? root.webErrorText : Services.Translation.tr("Used only when you explicitly activate a web-search result.")

            StyledComboBox {
                Layout.preferredWidth: 220
                textRole: "label"
                model: root.enginePresets
                currentIndex: {
                    const index = root.enginePresets.findIndex(item => item.value === Config.options.search.engineBaseUrl);
                    return index >= 0 ? index : root.enginePresets.length - 1;
                }
                onActivated: index => {
                    if (index >= 0 && root.enginePresets[index].value.length > 0) {
                        Config.options.search.engineBaseUrl = root.enginePresets[index].value;
                        root.webErrorText = "";
                    }
                }
            }
        }

        SettingsRow {
            visible: root.customEngine
            icon: "link"
            title: Services.Translation.tr("Custom search URL")
            description: root.webErrorText.length > 0 ? root.webErrorText : Services.Translation.tr("The query is appended after the final parameter, for example ?q=.")

            MaterialTextArea {
                id: customUrlField
                Layout.preferredWidth: 320
                implicitHeight: 42
                wrapMode: TextEdit.NoWrap
                Binding {
                    target: customUrlField
                    property: "text"
                    value: Config.options.search.engineBaseUrl
                    when: !customUrlField.activeFocus
                }
                onEditingFinished: root.commitEngineUrl(text)
            }
        }
    }

    SettingsGroup {
        title: Services.Translation.tr("Search shortcuts")

        SettingsRow {
            icon: "apps"
            title: Services.Translation.tr("Applications")
            description: root.prefixDescription("app", Services.Translation.tr("Prefix for application search."))
            MaterialTextField {
                id: appPrefix
                Layout.preferredWidth: 100
                implicitHeight: 42
                Binding { target: appPrefix; property: "text"; value: Config.options.search.prefix.app; when: !appPrefix.activeFocus }
                onEditingFinished: root.commitPrefix("app", text)
            }
        }

        SettingsRow {
            icon: "bolt"
            title: Services.Translation.tr("Shell actions")
            description: root.prefixDescription("action", Services.Translation.tr("Prefix for built-in and user shell actions."))
            MaterialTextField {
                id: actionPrefix
                Layout.preferredWidth: 100
                implicitHeight: 42
                Binding { target: actionPrefix; property: "text"; value: Config.options.search.prefix.action; when: !actionPrefix.activeFocus }
                onEditingFinished: root.commitPrefix("action", text)
            }
        }

        SettingsRow {
            icon: "content_paste"
            title: Services.Translation.tr("Clipboard")
            description: root.prefixDescription("clipboard", Services.Translation.tr("Prefix for explicit clipboard-history search."))
            MaterialTextField {
                id: clipboardPrefix
                Layout.preferredWidth: 100
                implicitHeight: 42
                Binding { target: clipboardPrefix; property: "text"; value: Config.options.search.prefix.clipboard; when: !clipboardPrefix.activeFocus }
                onEditingFinished: root.commitPrefix("clipboard", text)
            }
        }

        SettingsRow {
            icon: "mood"
            title: Services.Translation.tr("Emoji & symbols")
            description: root.prefixDescription("emojis", Services.Translation.tr("Prefix for emoji and symbol search."))
            MaterialTextField {
                id: emojiPrefix
                Layout.preferredWidth: 100
                implicitHeight: 42
                Binding { target: emojiPrefix; property: "text"; value: Config.options.search.prefix.emojis; when: !emojiPrefix.activeFocus }
                onEditingFinished: root.commitPrefix("emojis", text)
            }
        }

        SettingsRow {
            icon: "calculate"
            title: Services.Translation.tr("Calculator")
            description: root.prefixDescription("math", Services.Translation.tr("Prefix for calculator queries."))
            MaterialTextField {
                id: mathPrefix
                Layout.preferredWidth: 100
                implicitHeight: 42
                Binding { target: mathPrefix; property: "text"; value: Config.options.search.prefix.math; when: !mathPrefix.activeFocus }
                onEditingFinished: root.commitPrefix("math", text)
            }
        }

        SettingsRow {
            icon: "terminal"
            title: Services.Translation.tr("Shell commands")
            description: root.prefixDescription("shellCommand", Services.Translation.tr("Prefix for explicitly running a shell command."))
            MaterialTextField {
                id: commandPrefix
                Layout.preferredWidth: 100
                implicitHeight: 42
                Binding { target: commandPrefix; property: "text"; value: Config.options.search.prefix.shellCommand; when: !commandPrefix.activeFocus }
                onEditingFinished: root.commitPrefix("shellCommand", text)
            }
        }

        SettingsRow {
            icon: "travel_explore"
            title: Services.Translation.tr("Web search")
            description: root.prefixDescription("webSearch", Services.Translation.tr("Prefix for explicit browser web search."))
            MaterialTextField {
                id: webPrefix
                Layout.preferredWidth: 100
                implicitHeight: 42
                Binding { target: webPrefix; property: "text"; value: Config.options.search.prefix.webSearch; when: !webPrefix.activeFocus }
                onEditingFinished: root.commitPrefix("webSearch", text)
            }
        }
    }
}
