import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configGeneral

    property alias cfg_latitude:        latField.text
    property alias cfg_longitude:       lonField.text
    property alias cfg_locationLabel:   locationField.text
    property alias cfg_temperatureUnit: tempUnitCombo.currentValue
    property alias cfg_windUnit:        windUnitCombo.currentValue
    property alias cfg_fontSize:        fontSizeCombo.currentValue
    property alias cfg_refreshInterval: refreshSpin.value

    Kirigami.FormLayout {
        anchors.fill: parent

        // ── Location label (config-only, never shown in panel) ──
        RowLayout {
            Kirigami.FormData.label: "Location Name:"
            spacing: Kirigami.Units.smallSpacing
            QQC2.TextField {
                id: locationField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                placeholderText: "e.g. New York"
                text: cfg_locationLabel || ""
            }
        }

        // ── Coordinates ─────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Coordinates" }

        RowLayout {
            Kirigami.FormData.label: "Latitude:"
            QQC2.TextField {
                id: latField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                placeholderText: "40.7128"
                text: cfg_latitude || "40.7128"
                validator: DoubleValidator { notation: DoubleValidator.StandardNotation }
            }
        }
        RowLayout {
            Kirigami.FormData.label: "Longitude:"
            QQC2.TextField {
                id: lonField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                placeholderText: "-74.006"
                text: cfg_longitude || "-74.006"
                validator: DoubleValidator { notation: DoubleValidator.StandardNotation }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: "Find your coordinates at latlong.net or openstreetmap.org"
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            wrapMode: Text.WordWrap
        }

        Item { Kirigami.FormData.isSection: true }

        // ── Units ───────────────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: "Temperature:"
            QQC2.ComboBox {
                id: tempUnitCombo
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                model: [
                    { text: "Fahrenheit (°F)", value: "fahrenheit" },
                    { text: "Celsius (°C)",    value: "celsius" }
                ]
                textRole: "text"; valueRole: "value"
                Component.onCompleted: {
                    for (var i = 0; i < model.length; i++)
                        if (model[i].value === cfg_temperatureUnit) { currentIndex = i; break }
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Wind Speed:"
            QQC2.ComboBox {
                id: windUnitCombo
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                model: [
                    { text: "km/h",      value: "kmh" },
                    { text: "mph",       value: "mph" },
                    { text: "m/s",       value: "ms" }
                ]
                textRole: "text"; valueRole: "value"
                Component.onCompleted: {
                    for (var i = 0; i < model.length; i++)
                        if (model[i].value === cfg_windUnit) { currentIndex = i; break }
                }
            }
        }

        // ── Refresh ─────────────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: "Refresh Interval:"
            QQC2.SpinBox {
                id: refreshSpin
                from: 10; to: 120; stepSize: 5; value: 30
                textFromValue: function(v, l) { return v + " min" }
                valueFromText: function(t, l) { return parseInt(t) }
            }
        }

        // ── Appearance ──────────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: "Font Size:"
            QQC2.ComboBox {
                id: fontSizeCombo
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                model: [
                    { text: "Small",  value: "small" },
                    { text: "Medium", value: "medium" },
                    { text: "Large",  value: "large" }
                ]
                textRole: "text"; valueRole: "value"
                Component.onCompleted: {
                    for (var i = 0; i < model.length; i++)
                        if (model[i].value === cfg_fontSize) { currentIndex = i; break }
                }
            }
        }

        Item { Kirigami.FormData.isSection: true }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            visible: true
            text: "Your location name is only visible in these settings. The panel shows only the weather icon and temperature — never your location."
        }
    }
}
