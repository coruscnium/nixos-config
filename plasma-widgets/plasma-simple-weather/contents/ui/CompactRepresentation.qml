import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: compact

    Layout.minimumWidth:  contentRow.implicitWidth
    Layout.minimumHeight: contentRow.implicitHeight
    Layout.preferredWidth:  contentRow.implicitWidth
    Layout.preferredHeight: contentRow.implicitHeight

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: root.displayIcon
                Layout.preferredWidth:  Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                isMask: false
            }

            Text {
                text: root.displayTemp
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                color: Kirigami.Theme.textColor
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.highlightColor
        opacity: mouseArea.containsMouse ? 0.2 : 0
        radius: 3
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
