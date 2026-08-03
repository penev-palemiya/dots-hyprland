import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar

StyledPopup {
    id: root
    
    Item {
        anchors.centerIn: parent
        implicitWidth: 392
        implicitHeight: columnLayout.implicitHeight + 8

        ColumnLayout {
            id: columnLayout
            anchors.centerIn: parent
            width: parent.implicitWidth - 8
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: heroContent.implicitHeight + 24
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHigh

                RowLayout {
                    id: heroContent
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 14
                        rightMargin: 14
                    }
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: Weather.data.city
                            font {
                                weight: Font.Normal
                                pixelSize: Appearance.font.pixelSize.smaller
                            }
                            color: Appearance.colors.colOutline
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Weather.data.conditionText || Translation.tr("Weather")
                            font {
                                weight: Font.Bold
                                pixelSize: Appearance.font.pixelSize.small
                            }
                            color: Appearance.colors.colOnSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)} • ${Weather.data.today?.low ?? "--"} / ${Weather.data.today?.high ?? "--"}`
                            font {
                                weight: Font.Normal
                                pixelSize: Appearance.font.pixelSize.smaller
                            }
                            color: Appearance.colors.colOutline
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8

                        StyledText {
                            text: Weather.data.temp
                            font {
                                weight: Font.Bold
                                pixelSize: Appearance.font.pixelSize.small * 2
                            }
                            color: Appearance.colors.colOnSurface
                        }

                        MaterialSymbol {
                            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                            fill: 0
                            font.weight: Font.Normal
                            iconSize: Appearance.font.pixelSize.small * 2
                            color: Appearance.colors.colOnSurface
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 72
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHigh

                RowLayout {
                    id: hourlyRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 0

                    Repeater {
                        model: Weather.data.hourlyPreview ?? []

                        Item {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: hourlySlotColumn.implicitHeight

                            ColumnLayout {
                                id: hourlySlotColumn
                                anchors.centerIn: parent
                                width: parent.width
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: parent.parent.modelData.time
                                    font.pixelSize: Appearance.font.pixelSize.smaller * 0.92
                                    color: Appearance.colors.colOutline
                                    elide: Text.ElideRight
                                }

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Icons.getWeatherIcon(parent.parent.modelData.wCode) ?? "cloud"
                                    fill: 0
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnSurface
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: parent.parent.modelData.temp
                                    font {
                                        pixelSize: Appearance.font.pixelSize.smaller * 0.96
                                        weight: Font.Bold
                                    }
                                    color: Appearance.colors.colOnSurface
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                uniformCellWidths: true

                WeatherCard {
                    title: Translation.tr("Rain")
                    symbol: "rainy"
                    value: Weather.data.insights?.rain ?? "--"
                }
                WeatherCard {
                    title: Translation.tr("Comfort")
                    symbol: "device_thermostat"
                    value: Weather.data.insights?.comfort ?? "--"
                }
                WeatherCard {
                    title: Translation.tr("Wind")
                    symbol: "air"
                    value: Weather.data.details?.wind ?? "--"
                }
                WeatherCard {
                    title: Translation.tr("UV Index")
                    symbol: "wb_sunny"
                    value: Weather.data.details?.uv ?? "--"
                }
                WeatherCard {
                    title: Translation.tr("Daylight")
                    symbol: "wb_twilight"
                    value: Weather.data.today?.daylight ?? "--"
                }
                WeatherCard {
                    title: Translation.tr("Humidity")
                    symbol: "humidity_low"
                    value: Weather.data.details?.humidity ?? "--"
                }
                WeatherCard {
                    title: Translation.tr("Visibility")
                    symbol: "visibility"
                    value: Weather.data.details?.visibility ?? "--"
                }
                WeatherCard {
                    title: Translation.tr("Pressure")
                    symbol: "readiness_score"
                    value: Weather.data.details?.pressure ?? "--"
                }
            }

            // Footer: last refresh
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)
                font {
                    weight: Font.Normal
                    pixelSize: Appearance.font.pixelSize.smaller
                }
                color: Appearance.colors.colOutline
            }
        }
    }
}
