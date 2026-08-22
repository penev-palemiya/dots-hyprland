import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property string familySearchError: ""
    property list<string> installedFamilies: []

    function loadFamilies() {
        try {
            const nativeFamilies = Qt.fontFamilies();
            root.installedFamilies = Array.from(new Set(nativeFamilies)).sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
        } catch (exception) {
            root.familySearchError = Translation.tr("Installed fonts could not be listed.");
            root.installedFamilies = [];
        }
    }

    function isInstalled(family) {
        return root.installedFamilies.some(value => value.toLowerCase() === family.toLowerCase());
    }

    function setFamily(role, family) {
        if (role === "main") {
            Config.options.appearance.fonts.main = family;
            Config.options.appearance.fonts.numbers = family;
        } else if (role === "monospace") {
            Config.options.appearance.fonts.monospace = family;
        } else if (role === "title") {
            Config.options.appearance.fonts.title = family;
        } else if (role === "reading") {
            Config.options.appearance.fonts.reading = family;
        } else if (role === "expressive") {
            Config.options.appearance.fonts.expressive = family;
        }
    }

    Component.onCompleted: root.loadFamilies()

    SettingsGroup {
        title: Translation.tr("Fonts")

        SettingsRow {
            icon: "text_fields"
            title: Translation.tr("Interface")
            description: root.isInstalled(Config.options.appearance.fonts.main)
                ? Translation.tr("Used throughout the shell")
                : Translation.tr("%1 · Not installed").arg(Config.options.appearance.fonts.main)

            ColumnLayout {
                spacing: 4
                SearchableSelection {
                    Layout.preferredWidth: 300
                    currentValue: Config.options.appearance.fonts.main
                    options: root.installedFamilies
                    placeholder: Translation.tr("Select interface font")
                    searchPlaceholder: Translation.tr("Search installed fonts")
                    onSelected: value => root.setFamily("main", value)
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Aa Бб 123 · The quick brown fox"
                    font.family: Config.options.appearance.fonts.main
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        SettingsRow {
            icon: "code"
            title: Translation.tr("Monospace")
            description: root.isInstalled(Config.options.appearance.fonts.monospace)
                ? Translation.tr("Used for code and fixed-width text")
                : Translation.tr("%1 · Not installed").arg(Config.options.appearance.fonts.monospace)

            ColumnLayout {
                spacing: 4
                SearchableSelection {
                    Layout.preferredWidth: 300
                    currentValue: Config.options.appearance.fonts.monospace
                    options: root.installedFamilies
                    placeholder: Translation.tr("Select monospace font")
                    searchPlaceholder: Translation.tr("Search installed fonts")
                    onSelected: value => root.setFamily("monospace", value)
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "const value = 42;"
                    font.family: Config.options.appearance.fonts.monospace
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        SettingsRow {
            icon: "title"
            title: Translation.tr("Headings")
            description: root.isInstalled(Config.options.appearance.fonts.title)
                ? Translation.tr("Used for headings and dialog titles")
                : Translation.tr("%1 · Not installed").arg(Config.options.appearance.fonts.title)

            ColumnLayout {
                spacing: 4
                SearchableSelection {
                    Layout.preferredWidth: 300
                    currentValue: Config.options.appearance.fonts.title
                    options: root.installedFamilies
                    placeholder: Translation.tr("Select heading font")
                    searchPlaceholder: Translation.tr("Search installed fonts")
                    onSelected: value => root.setFamily("title", value)
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Aa Бб 123"
                    font.family: Config.options.appearance.fonts.title
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }
            }
        }

        SettingsRow {
            icon: "menu_book"
            title: Translation.tr("Reading")
            description: root.isInstalled(Config.options.appearance.fonts.reading)
                ? Translation.tr("Used for reading-focused text")
                : Translation.tr("%1 · Not installed").arg(Config.options.appearance.fonts.reading)

            ColumnLayout {
                spacing: 4
                SearchableSelection {
                    Layout.preferredWidth: 300
                    currentValue: Config.options.appearance.fonts.reading
                    options: root.installedFamilies
                    placeholder: Translation.tr("Select reading font")
                    searchPlaceholder: Translation.tr("Search installed fonts")
                    onSelected: value => root.setFamily("reading", value)
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "A short readable sentence · Короткий текст"
                    font.family: Config.options.appearance.fonts.reading
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        SettingsRow {
            icon: "auto_awesome"
            title: Translation.tr("Expressive")
            description: root.isInstalled(Config.options.appearance.fonts.expressive)
                ? Translation.tr("Used for decorative shell text")
                : Translation.tr("%1 · Not installed").arg(Config.options.appearance.fonts.expressive)

            ColumnLayout {
                spacing: 4
                SearchableSelection {
                    Layout.preferredWidth: 300
                    currentValue: Config.options.appearance.fonts.expressive
                    options: root.installedFamilies
                    placeholder: Translation.tr("Select expressive font")
                    searchPlaceholder: Translation.tr("Search installed fonts")
                    onSelected: value => root.setFamily("expressive", value)
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Aa Бб 123"
                    font.family: Config.options.appearance.fonts.expressive
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }
            }
        }
    }

    SettingsRow {
        visible: root.familySearchError.length > 0
        icon: "error"
        title: Translation.tr("Font discovery unavailable")
        description: root.familySearchError
        registerInSearch: false
    }
}
