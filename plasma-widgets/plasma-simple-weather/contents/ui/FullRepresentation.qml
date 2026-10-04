import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras

Item {
    id: fullRep

    property int activeTab: 0
    property int hoveredIndex: -1
    property real hoverX: 0
    property real hoverY: 0
    property string hoverLabel: ""

    Layout.minimumWidth:  Kirigami.Units.gridUnit * 30
    Layout.minimumHeight: Kirigami.Units.gridUnit * 30
    Layout.preferredWidth:  Kirigami.Units.gridUnit * 44
    Layout.preferredHeight: Kirigami.Units.gridUnit * 46

    function tempRange() {
        var minT = 999, maxT = -999
        var d = root.hourlyModel
        for (var i = 0; i < d.length; i++) {
            var t = d[i].temp
            if (t < minT) minT = t
            if (t > maxT) maxT = t
        }
        var r = maxT - minT
        if (r < 4) r = 4
        return { min: minT - r * 0.2, max: maxT + r * 0.2, range: (maxT - minT) * 1.4 }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: 0

        // ── Header ──────────────────────────────────────────
        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true
            RowLayout {
                Kirigami.Heading {
                    level: 3
                    text: root.hasData ? root.conditionText : "Weather"
                    Layout.fillWidth: true
                }
                QQC2.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: root.fetchWeather()
                }
            }
        }

        // ── Current conditions ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasData
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: root.displayIcon
                Layout.preferredWidth:  Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                isMask: false
            }
            QQC2.Label {
                text: root.displayTemp
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 2.2
                font.weight: Font.Light
            }
            QQC2.Label {
                text: "Feels " + root.formatTemp(root.currentWeather.feelsLike || 0)
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
            }
            Item { Layout.fillWidth: true }
            QQC2.Label {
                text: "Humidity " + (root.currentWeather.humidity || "\u2014") + "%"
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
            }
            QQC2.Label {
                text: "Wind " + root.formatWind(root.currentWeather.windSpeed || 0)
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.hasError
            type: Kirigami.MessageType.Error
            text: root.errorMessage || "Unable to fetch weather data."
        }

        // ── Tab bar ─────────────────────────────────────────
        QQC2.TabBar {
            id: tabBar
            Layout.fillWidth: true
            QQC2.TabButton {
                text: "Hourly"
                width: tabBar.width / 2
                onClicked: fullRep.activeTab = 0
            }
            QQC2.TabButton {
                text: "Daily"
                width: tabBar.width / 2
                onClicked: fullRep.activeTab = 1
            }
            onWidthChanged: {
                for (var i = 0; i < contentChildren.length; i++)
                    contentChildren[i].width = width / 2
            }
            Component.onCompleted: { tabBar.currentIndex = 0 }
        }
        Binding { target: tabBar; property: "currentIndex"; value: fullRep.activeTab }

        Kirigami.Separator { Layout.fillWidth: true }

        // ── Content area ────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // ══════════════════════════════════════════════════
            // HOURLY
            // ══════════════════════════════════════════════════
            Item {
                id: hourlyItem
                anchors.fill: parent
                visible: fullRep.activeTab === 0

                // ── Time labels at bottom ───────────────────
                Row {
                    id: timeRow
                    anchors.left: yPanel.right
                    anchors.leftMargin: 1
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Kirigami.Units.gridUnit * 1.5
                    clip: true
                    visible: root.hourlyModel.length > 0
                    property real offX: chartFlick.contentX * -1

                    Repeater {
                        model: root.hourlyModel.length > 0 ? Math.floor(root.hourlyModel.length / 3) + 1 : 0
                        QQC2.Label {
                            x: timeRow.offX + index * 3 * Kirigami.Units.gridUnit * 4 + Kirigami.Units.smallSpacing
                            width: Kirigami.Units.gridUnit * 6
                            height: parent.height
                            text: {
                                var di = index * 3
                                return di < root.hourlyModel.length ? root.hourlyModel[di].hourLabel : ""
                            }
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 0.95 * root.fontScale
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // ── Y-axis panel ────────────────────────────
                Item {
                    id: yPanel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: timeRow.top
                    anchors.rightMargin: 0
                    width: Kirigami.Units.gridUnit * 2.5
                    visible: root.hourlyModel.length > 0

                    // Top half: temperature labels
                    Item {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.bottom: midSep.top

                        QQC2.Label {
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            anchors.top: parent.top
                            text: Math.round(fullRep.tempRange().max) + "\u00b0"
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
                        }
                        QQC2.Label {
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            y: parent.height * 0.333 - height * 0.5
                            text: Math.round(fullRep.tempRange().max - fullRep.tempRange().range / 3) + "\u00b0"
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
                        }
                        QQC2.Label {
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            y: parent.height * 0.667 - height * 0.5
                            text: Math.round(fullRep.tempRange().max - fullRep.tempRange().range * 2 / 3) + "\u00b0"
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
                        }
                        QQC2.Label {
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            anchors.bottom: parent.bottom
                            text: Math.round(fullRep.tempRange().min) + "\u00b0"
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
                        }
                    }

                    // Midpoint separator
                    Rectangle {
                        id: midSep
                        anchors.left: parent.left
                        anchors.right: parent.right
                        y: parent.height / 2
                        height: 1
                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                       Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, 0.2)
                    }

                    // Bottom half: precipitation labels
                    Item {
                        anchors.left: parent.left
                        anchors.top: midSep.bottom
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom

                        QQC2.Label {
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            anchors.top: parent.top
                            text: "100%"
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
                        }
                        QQC2.Label {
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: "50%"
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
                        }
                        QQC2.Label {
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            anchors.bottom: parent.bottom
                            text: "0%"
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.1 * root.fontScale
                        }
                    }

                    // Right edge divider
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                       Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, 0.1)
                    }
                }

                // ── Chart Flickable ─────────────────────────
                Flickable {
                    id: chartFlick
                    anchors.left: yPanel.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: timeRow.top
                    contentWidth: Math.max(width, root.hourlyModel.length * Kirigami.Units.gridUnit * 4 + Kirigami.Units.largeSpacing)
                    contentHeight: height
                    clip: true
                    flickDeceleration: 3000
                    maximumFlickVelocity: 6000

                    onContentXChanged: {
                        if (contentX < -10) contentX = -10
                        if (contentX > contentWidth - width + 10)
                            contentX = Math.max(0, contentWidth - width + 10)
                    }

                            // Temp canvas (top half)
                            Canvas {
                                id: tc
                                width: chartFlick.contentWidth
                                height: chartFlick.height / 2
                                visible: root.hourlyModel.length > 0
                                Connections {
                                    target: root
                                    function onHourlyModelChanged() { tc.requestPaint() }
                                }
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                property int pl: 4; property int pr: 12
                                property int pt: 2; property int pb: 2

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var d = root.hourlyModel
                                    var n = d.length
                                    if (n < 2) return
                                    var cw = width - pl - pr
                                    var ch = height - pt - pb
                                    var sx = cw / (n - 1)
                                    var tr = fullRep.tempRange()
                                    var min = tr.min, max = tr.max, r = tr.range

                                    function tx(i) { return pl + i * sx }
                                    function ty(t) { return pt + ch - ((t - min) / r) * ch }

                                    ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r,
                                        Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                                    ctx.lineWidth = 1
                                    for (var g = 0; g <= 3; g++) {
                                        var gy = pt + (g / 3) * ch
                                        ctx.beginPath()
                                        ctx.moveTo(pl, gy)
                                        ctx.lineTo(width - pr, gy)
                                        ctx.stroke()
                                    }

                                    ctx.beginPath()
                                    ctx.moveTo(tx(0), ty(d[0].temp))
                                    for (var j = 1; j < n; j++) ctx.lineTo(tx(j), ty(d[j].temp))
                                    ctx.lineTo(tx(n - 1), pt + ch)
                                    ctx.lineTo(tx(0), pt + ch)
                                    ctx.closePath()
                                    var grad = ctx.createLinearGradient(0, pt, 0, pt + ch)
                                    grad.addColorStop(0, Qt.rgba(0.95, 0.55, 0.25, 0.30))
                                    grad.addColorStop(1, Qt.rgba(0.95, 0.55, 0.25, 0.02))
                                    ctx.fillStyle = grad
                                    ctx.fill()

                                    ctx.beginPath()
                                    ctx.strokeStyle = "#f08a24"
                                    ctx.lineWidth = 3
                                    ctx.lineJoin = "round"
                                    ctx.lineCap = "round"
                                    for (var k = 0; k < n; k++) {
                                        var lx = tx(k), ly = ty(d[k].temp)
                                        if (k === 0) ctx.moveTo(lx, ly)
                                        else ctx.lineTo(lx, ly)
                                    }
                                    ctx.stroke()

                                    for (var dd = 0; dd < n; dd++) {
                                        var dx = tx(dd), dy = ty(d[dd].temp)
                                        ctx.beginPath()
                                        ctx.fillStyle = "#f08a24"
                                        ctx.arc(dx, dy, 4, 0, Math.PI * 2)
                                        ctx.fill()
                                        ctx.beginPath()
                                        ctx.fillStyle = Kirigami.Theme.backgroundColor
                                        ctx.arc(dx, dy, 2.5, 0, Math.PI * 2)
                                        ctx.fill()
                                    }
                                }
                            }

                            // Precip canvas (bottom half)
                            Canvas {
                                id: pc
                                anchors.top: tc.bottom
                                width: chartFlick.contentWidth
                                height: chartFlick.height / 2
                                visible: root.hourlyModel.length > 0
                                Connections {
                                    target: root
                                    function onHourlyModelChanged() { pc.requestPaint() }
                                }
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                property int pl: 4; property int pr: 12
                                property int pt: 2; property int pb: 2

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var d = root.hourlyModel
                                    var n = d.length
                                    if (n < 2) return
                                    var cw = width - pl - pr
                                    var ch = height - pt - pb
                                    var sx = cw / (n - 1)

                                    function tx(i) { return pl + i * sx }
                                    function ty(p) { return pt + ch - (p / 100) * ch }

                                    ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r,
                                        Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                                    ctx.lineWidth = 1
                                    for (var g = 0; g <= 2; g++) {
                                        var gy = pt + (g / 2) * ch
                                        ctx.beginPath()
                                        ctx.moveTo(pl, gy)
                                        ctx.lineTo(width - pr, gy)
                                        ctx.stroke()
                                    }

                                    ctx.beginPath()
                                    ctx.moveTo(tx(0), ty(d[0].precip))
                                    for (var j = 1; j < n; j++) ctx.lineTo(tx(j), ty(d[j].precip))
                                    ctx.lineTo(tx(n - 1), pt + ch)
                                    ctx.lineTo(tx(0), pt + ch)
                                    ctx.closePath()
                                    var grad = ctx.createLinearGradient(0, pt, 0, pt + ch)
                                    grad.addColorStop(0, Qt.rgba(0.36, 0.65, 0.84, 0.30))
                                    grad.addColorStop(1, Qt.rgba(0.36, 0.65, 0.84, 0.02))
                                    ctx.fillStyle = grad
                                    ctx.fill()

                                    ctx.beginPath()
                                    ctx.strokeStyle = "#5b9bd5"
                                    ctx.lineWidth = 3
                                    ctx.lineJoin = "round"
                                    ctx.lineCap = "round"
                                    for (var k = 0; k < n; k++) {
                                        var lx = tx(k), ly = ty(d[k].precip)
                                        if (k === 0) ctx.moveTo(lx, ly)
                                        else ctx.lineTo(lx, ly)
                                    }
                                    ctx.stroke()

                                    for (var dd = 0; dd < n; dd++) {
                                        var dx = tx(dd), dy = ty(d[dd].precip)
                                        ctx.beginPath()
                                        ctx.fillStyle = "#5b9bd5"
                                        ctx.arc(dx, dy, 4, 0, Math.PI * 2)
                                        ctx.fill()
                                        ctx.beginPath()
                                        ctx.fillStyle = Kirigami.Theme.backgroundColor
                                        ctx.arc(dx, dy, 2.5, 0, Math.PI * 2)
                                        ctx.fill()
                                    }
                                }
                            }

                            // ── Hover tooltip ─────────────────
                            Rectangle {
                                id: tip
                                visible: fullRep.hoveredIndex >= 0
                                x: Math.min(fullRep.hoverX - width / 2,
                                            chartFlick.contentWidth - width - 4)
                                y: Math.max(0, fullRep.hoverY - height - Kirigami.Units.gridUnit)
                                width: tipText.implicitWidth + Kirigami.Units.largeSpacing
                                height: tipText.implicitHeight + Kirigami.Units.smallSpacing
                                radius: 4
                                color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                                               Kirigami.Theme.backgroundColor.g,
                                               Kirigami.Theme.backgroundColor.b, 0.94)
                                border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                                      Kirigami.Theme.textColor.g,
                                                      Kirigami.Theme.textColor.b, 0.2)
                                border.width: 1

                                QQC2.Label {
                                    id: tipText
                                    anchors.centerIn: parent
                                    text: fullRep.hoverLabel
                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1 * root.fontScale
                                    font.weight: Font.DemiBold
                                }
                            }

                            // ── Mouse handling ────────────────
                            MouseArea {
                                id: chartMouse
                                anchors.fill: parent
                                hoverEnabled: true

                                onPositionChanged: function(mouse) {
                                    var n = root.hourlyModel.length
                                    if (n < 2) { fullRep.hoveredIndex = -1; return }
                                    var sx = chartFlick.contentWidth / (n - 1)
                                    var idx = Math.round(mouse.x / sx)
                                    idx = Math.max(0, Math.min(n - 1, idx))
                                    fullRep.hoveredIndex = idx
                                    fullRep.hoverX = mouse.x
                                    var d = root.hourlyModel[idx]
                                    if (mouse.y < tc.height) {
                                        fullRep.hoverY = mouse.y
                                        fullRep.hoverLabel = d.hourLabel + "  " + d.temp + "\u00b0"
                                    } else {
                                        fullRep.hoverY = mouse.y
                                        fullRep.hoverLabel = d.hourLabel + "  " + d.precip + "%"
                                    }
                                }
                                onExited: { fullRep.hoveredIndex = -1 }
                                onWheel: function(wheel) {
                                    chartFlick.contentX -= wheel.angleDelta.y * 2
                                    wheel.accepted = true
                                }
                            }
                }
            }

            // ══════════════════════════════════════════════════
            // DAILY
            // ══════════════════════════════════════════════════
            ListView {
                id: dl
                anchors.fill: parent
                visible: fullRep.activeTab === 1
                clip: true
                model: root.dailyModel
                spacing: Kirigami.Units.smallSpacing

                delegate: Rectangle {
                    width: dl.width - Kirigami.Units.smallSpacing
                    height: Kirigami.Units.gridUnit * 4
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                                   Kirigami.Theme.backgroundColor.g,
                                   Kirigami.Theme.backgroundColor.b, 0.35)
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                          Kirigami.Theme.textColor.g,
                                          Kirigami.Theme.textColor.b, 0.06)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.largeSpacing

                        QQC2.Label {
                            text: modelData.dayLabel
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                            font.weight: Font.DemiBold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05 * root.fontScale
                        }
                        Kirigami.Icon {
                            source: modelData.icon
                            Layout.preferredWidth:  Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            isMask: false
                        }
                        QQC2.Label {
                            text: modelData.high + "\u00b0"
                            font.weight: Font.DemiBold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05 * root.fontScale
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                        }
                        QQC2.Label {
                            text: modelData.low + "\u00b0"
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05 * root.fontScale
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Item { Layout.fillHeight: true }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: Qt.rgba(Kirigami.Theme.textColor.r,
                                               Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b, 0.1)
                                Rectangle {
                                    width: parent.width * (modelData.precip / 100)
                                    height: parent.height
                                    radius: 2
                                    color: "#5b9bd5"
                                }
                            }
                            QQC2.Label {
                                text: modelData.precip > 0 ? modelData.precip + "%" : ""
                                color: "#5b9bd5"
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.05 * root.fontScale
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }
    }
}
