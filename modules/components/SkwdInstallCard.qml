import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.services

// Installs skwd-wall into your home, updates Ambxst's own
// copy, or lists missing system packages. Shown in the wallpaper settings;
// hidden while a system install is used.
StyledRect {
    id: skwdStatusCard
    implicitHeight: skwdStatusRow.implicitHeight + 24
    Layout.preferredHeight: implicitHeight
    variant: "pane"
    radius: Styling.radius(4)

    readonly property string st: SkwdWall.installState
    readonly property bool missing: SkwdWall.source === "none" && st !== "done"
    readonly property bool needsLibs: SkwdWall.missingLibs.length > 0
    // Something to say: not installed, installing, failed, missing packages
    // or an update. A system install (AUR, distro package) never shows it.
    readonly property bool shouldShow: SkwdWall.source !== "unknown" && SkwdWall.source !== "system"
        && (missing || st === "running" || st === "failed" || needsLibs || SkwdWall.updateAvailable)
    visible: shouldShow

    RowLayout {
        id: skwdStatusRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 12
        spacing: 12

        Text {
            Layout.alignment: Qt.AlignTop
            text: skwdStatusCard.st === "failed" || skwdStatusCard.needsLibs ? Icons.alert : Icons.image
            font.family: Icons.font
            font.pixelSize: 22
            color: Styling.srItem("overprimary")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: {
                    const st = skwdStatusCard.st;
                    if (st === "running")
                        return "Installing skwd-wall";
                    if (st === "failed")
                        return "Couldn't install skwd-wall";
                    if (skwdStatusCard.needsLibs)
                        return "skwd-wall " + SkwdWall.installedVersion + " is installed, but needs a few system packages";
                    if (SkwdWall.updateAvailable)
                        return "skwd-wall " + SkwdWall.latestVersion + " is available";
                    return "skwd-wall isn't installed";
                }
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Bold
                color: Colors.overBackground
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: {
                    const st = skwdStatusCard.st;
                    if (st === "running")
                        return SkwdWall.installStep + "…";
                    if (st === "failed")
                        return SkwdWall.installError;
                    if (skwdStatusCard.needsLibs)
                        return "Install these with your package manager, then reload Ambxst: " + SkwdWall.missingLibs.map(m => m.pkg !== "?" ? m.pkg + " (" + m.lib + ")" : m.lib).join(", ");
                    if (SkwdWall.updateAvailable)
                        return "You have " + SkwdWall.installedVersion + ". The update downloads from liixini's GitHub releases and takes a few seconds.";
                    return "Ambxst is drawing your wallpapers for now. Install skwd-wall (about 70 MB from liixini's GitHub releases, into your home folder, no password needed) for its transitions and lighter video playback.";
                }
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.outline
                wrapMode: Text.WordWrap
            }
        }

        StyledRect {
            id: skwdActionBtn
            readonly property bool busy: skwdStatusCard.st === "running"
            visible: !skwdStatusCard.needsLibs
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 34
            Layout.preferredWidth: skwdActionLabel.implicitWidth + 28
            variant: busy ? "common" : (maSkwdAction.containsMouse ? "primaryfocus" : "primary")
            radius: Styling.radius(2)
            opacity: busy ? 0.7 : 1.0

            Text {
                id: skwdActionLabel
                anchors.centerIn: parent
                text: skwdActionBtn.busy ? "Working…" : (skwdStatusCard.st === "failed" ? "Try again" : (SkwdWall.updateAvailable ? "Update" : "Install skwd-wall"))
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Bold
                color: skwdActionBtn.busy ? Colors.overSurface : Styling.srItem(maSkwdAction.containsMouse ? "primaryfocus" : "primary")
            }

            MouseArea {
                id: maSkwdAction
                anchors.fill: parent
                hoverEnabled: true
                enabled: !skwdActionBtn.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: SkwdWall.install()
            }
        }
    }
}
