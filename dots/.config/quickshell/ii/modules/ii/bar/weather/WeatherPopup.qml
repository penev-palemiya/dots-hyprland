import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar

StyledPopup {
    id: root

    // Same cascade the resources popup uses. The 2-column grid is staggered
    // by ROW rather than per tile: eight individually-delayed tiles read as a
    // slow ripple, whereas paired rows keep the whole reveal inside the same
    // window as every other popup.
    staggerContent: true
    sectionCount: 7 // hero, hourly strip, four grid rows, footer
    
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
                opacity: root.sectionOpacity(0)
                transform: Translate { y: root.sectionOffset(0) }

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
                opacity: root.sectionOpacity(1)
                transform: Translate { y: root.sectionOffset(1) }

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

            GroupedGrid {
                id: detailsGrid

                Layout.fillWidth: true
                columns: 2
                uniformCellWidths: true

                WeatherCard {
                    id: rainCard

                    corners: detailsGrid.cornersFor(rainCard)
                    opacity: root.sectionOpacity(2)
                    transform: Translate { y: root.sectionOffset(2) }
                    title: Translation.tr("Rain")
                    symbol: "rainy"
                    value: Weather.data.insights?.rain ?? "--"
                }
                WeatherCard {
                    id: comfortCard

                    corners: detailsGrid.cornersFor(comfortCard)
                    opacity: root.sectionOpacity(2)
                    transform: Translate { y: root.sectionOffset(2) }
                    title: Translation.tr("Comfort")
                    symbol: "device_thermostat"
                    value: Weather.data.insights?.comfort ?? "--"
                }
                WeatherCard {
                    id: windCard

                    corners: detailsGrid.cornersFor(windCard)
                    opacity: root.sectionOpacity(3)
                    transform: Translate { y: root.sectionOffset(3) }
                    title: Translation.tr("Wind")
                    symbol: "air"
                    value: Weather.data.details?.wind ?? "--"
                }
                WeatherCard {
                    id: uvCard

                    corners: detailsGrid.cornersFor(uvCard)
                    opacity: root.sectionOpacity(3)
                    transform: Translate { y: root.sectionOffset(3) }
                    title: Translation.tr("UV Index")
                    symbol: "wb_sunny"
                    value: Weather.data.details?.uv ?? "--"
                }
                WeatherCard {
                    id: daylightCard

                    corners: detailsGrid.cornersFor(daylightCard)
                    opacity: root.sectionOpacity(4)
                    transform: Translate { y: root.sectionOffset(4) }
                    title: Translation.tr("Daylight")
                    symbol: "wb_twilight"
                    value: Weather.data.today?.daylight ?? "--"
                }
                WeatherCard {
                    id: humidityCard

                    corners: detailsGrid.cornersFor(humidityCard)
                    opacity: root.sectionOpacity(4)
                    transform: Translate { y: root.sectionOffset(4) }
                    title: Translation.tr("Humidity")
                    symbol: "humidity_low"
                    value: Weather.data.details?.humidity ?? "--"
                }
                WeatherCard {
                    id: visibilityCard

                    corners: detailsGrid.cornersFor(visibilityCard)
                    opacity: root.sectionOpacity(5)
                    transform: Translate { y: root.sectionOffset(5) }
                    title: Translation.tr("Visibility")
                    symbol: "visibility"
                    value: Weather.data.details?.visibility ?? "--"
                }
                WeatherCard {
                    id: pressureCard

                    corners: detailsGrid.cornersFor(pressureCard)
                    opacity: root.sectionOpacity(5)
                    transform: Translate { y: root.sectionOffset(5) }
                    title: Translation.tr("Pressure")
                    symbol: "readiness_score"
                    value: Weather.data.details?.pressure ?? "--"
                }
            }

            // Footer: last refresh
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                opacity: root.sectionOpacity(6)
                transform: Translate { y: root.sectionOffset(6) }
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
