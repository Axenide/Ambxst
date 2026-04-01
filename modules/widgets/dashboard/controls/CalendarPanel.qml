pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    property string currentSection: ""

    // i18n helper — works with or without the I18n singleton
    function _t(key, fallback) {
        let str;
        try { str = I18n.t(key); } catch(e) { str = fallback; }
        for (let i = 2; i < arguments.length; i++)
            str = str.replace("%" + (i - 1), arguments[i]);
        return str;
    }

    // CalDAV form state
    property string caldavName: ""
    property string caldavUrl: ""
    property string caldavUser: ""
    property string caldavPass: ""

    // Pending settings
    property int pendingSyncInterval: CalendarService.syncInterval
    property bool pendingNotifications: CalendarService.notificationsEnabled
    property bool pendingBarIndicator: CalendarService.barIndicatorEnabled
    property bool pendingBarShowNextEvent: Config.calendar ? (Config.calendar.barShowNextEvent === true) : false
    property bool pendingBarAlwaysShow: Config.calendar ? (Config.calendar.barAlwaysShow === true) : false
    property int pendingDefaultReminder: CalendarService.defaultReminder
    property bool pendingSoundOnArrival: CalendarService.soundOnArrival
    property string pendingArrivalSoundPath: Config.calendar ? (Config.calendar.arrivalSoundPath || "") : ""
    property bool pendingBlinkOnArrival: CalendarService.blinkOnArrival
    property string pendingGoogleClientId: Config.calendar ? (Config.calendar.googleClientId || "") : ""
    property string pendingGoogleClientSecret: Config.calendar ? (Config.calendar.googleClientSecret || "") : ""

    readonly property bool hasGoogleAccount: {
        for (let i = 0; i < CalendarService.accounts.length; i++) {
            if (CalendarService.accounts[i].provider === "google") return true;
        }
        return false;
    }

    readonly property bool hasChanges: {
        if (!Config.calendar) return false;
        return pendingSyncInterval !== (Config.calendar.syncInterval || 15)
            || pendingNotifications !== (Config.calendar.notifications !== false)
            || pendingBarIndicator !== (Config.calendar.barIndicator !== false)
            || pendingDefaultReminder !== (Config.calendar.defaultReminder || 15)
            || pendingSoundOnArrival !== (Config.calendar.soundOnArrival !== false)
            || pendingArrivalSoundPath !== (Config.calendar.arrivalSoundPath || "")
            || pendingBlinkOnArrival !== (Config.calendar.blinkOnArrival !== false)
            || pendingGoogleClientId !== (Config.calendar.googleClientId || "")
            || pendingGoogleClientSecret !== (Config.calendar.googleClientSecret || "")
            || pendingBarShowNextEvent !== (Config.calendar.barShowNextEvent === true)
            || pendingBarAlwaysShow !== (Config.calendar.barAlwaysShow === true);
    }

    function resetToConfig() {
        if (!Config.calendar) return;
        pendingSyncInterval = Config.calendar.syncInterval || 15;
        pendingNotifications = Config.calendar.notifications !== false;
        pendingBarIndicator = Config.calendar.barIndicator !== false;
        pendingDefaultReminder = Config.calendar.defaultReminder || 15;
        pendingSoundOnArrival = Config.calendar.soundOnArrival !== false;
        pendingArrivalSoundPath = Config.calendar.arrivalSoundPath || "";
        pendingBlinkOnArrival = Config.calendar.blinkOnArrival !== false;
        pendingGoogleClientId = Config.calendar.googleClientId || "";
        pendingGoogleClientSecret = Config.calendar.googleClientSecret || "";
        pendingBarShowNextEvent = Config.calendar.barShowNextEvent === true;
        pendingBarAlwaysShow = Config.calendar.barAlwaysShow === true;
    }

    function saveToConfig() {
        if (!Config.calendar) return;
        Config.calendar.syncInterval = pendingSyncInterval;
        Config.calendar.notifications = pendingNotifications;
        Config.calendar.barIndicator = pendingBarIndicator;
        Config.calendar.barShowNextEvent = pendingBarShowNextEvent;
        Config.calendar.barAlwaysShow = pendingBarAlwaysShow;
        Config.calendar.defaultReminder = pendingDefaultReminder;
        Config.calendar.soundOnArrival = pendingSoundOnArrival;
        Config.calendar.arrivalSoundPath = pendingArrivalSoundPath;
        Config.calendar.blinkOnArrival = pendingBlinkOnArrival;
        Config.calendar.googleClientId = pendingGoogleClientId;
        Config.calendar.googleClientSecret = pendingGoogleClientSecret;
        Config.saveCalendar();
        CalendarService.setSyncInterval(pendingSyncInterval);
    }

    component SectionButton: StyledRect {
        id: sectionBtn
        required property string text
        required property string sectionId

        property bool isHovered: false

        variant: isHovered ? "focus" : "pane"
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Styling.radius(0)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Text {
                text: sectionBtn.text
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
            }

            Text {
                text: Icons.caretRight
                font.family: Icons.font
                font.pixelSize: 20
                color: Colors.overSurfaceVariant
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: sectionBtn.isHovered = true
            onExited: sectionBtn.isHovered = false
            onClicked: root.currentSection = sectionBtn.sectionId
        }
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn
            width: mainFlickable.width
            spacing: 8

            // Header
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: titlebar.height

                PanelTitlebar {
                    id: titlebar
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    title: root.currentSection === "" ? root._t("calendar.panel.title", "Calendar") : (root.currentSection === "accounts" ? root._t("calendar.panel.section_accounts", "Accounts") : root._t("calendar.panel.section_settings", "Settings"))
                    statusText: CalendarService.syncing ? "Syncing..." : ""
                    statusColor: Colors.primary

                    actions: {
                        let acts = [];
                        if (root.currentSection !== "") {
                            acts.push({
                                icon: Icons.arrowLeft,
                                tooltip: root._t("calendar.panel.back", "Back"),
                                onClicked: function() { root.currentSection = ""; }
                            });
                        }
                        if (CalendarService.hasAccounts) {
                            acts.push({
                                icon: Icons.sync,
                                tooltip: root._t("calendar.panel.sync_now", "Sync now"),
                                loading: CalendarService.syncing,
                                onClicked: function() { CalendarService.sync(); }
                            });
                        }
                        return acts;
                    }
                }
            }

            // Content
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: contentColumn.implicitHeight

                ColumnLayout {
                    id: contentColumn
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // ── Menu ──
                    ColumnLayout {
                        visible: root.currentSection === ""
                        Layout.fillWidth: true
                        spacing: 8

                        SectionButton {
                            text: root._t("calendar.panel.section_accounts", "Accounts")
                            sectionId: "accounts"
                        }

                        SectionButton {
                            text: root._t("calendar.panel.section_settings", "Settings")
                            sectionId: "settings"
                        }
                    }

                    // ── Accounts section ──
                    ColumnLayout {
                        visible: root.currentSection === "accounts"
                        Layout.fillWidth: true
                        spacing: 12

                        // Connected accounts
                        Repeater {
                            model: CalendarService.accounts

                            delegate: StyledRect {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                variant: "pane"
                                radius: Styling.radius(0)
                                implicitHeight: accountRow.implicitHeight + 20

                                RowLayout {
                                    id: accountRow
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    // Provider icon
                                    StyledRect {
                                        variant: "common"
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        radius: Styling.radius(-2)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.provider === "google" ? "G" : "C"
                                            font.family: Config.defaultFont
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: modelData.provider === "google" ? "#4285f4" : "#0082c9"
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: modelData.email || modelData.name || modelData.id
                                            font.family: Config.defaultFont
                                            font.pixelSize: Styling.fontSize(-1)
                                            color: Colors.overBackground
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.provider === "google" ? "Google Calendar" : "CalDAV"
                                            font.family: Config.defaultFont
                                            font.pixelSize: Styling.fontSize(-3)
                                            color: Colors.outline
                                        }
                                    }

                                    StyledRect {
                                        variant: removeMouseArea.containsMouse ? "focus" : "common"
                                        implicitWidth: removeText.implicitWidth + 16
                                        implicitHeight: 24
                                        radius: Styling.radius(-4)

                                        Text {
                                            id: removeText
                                            anchors.centerIn: parent
                                            text: root._t("calendar.panel.remove", "Remove")
                                            font.family: Config.defaultFont
                                            font.pixelSize: Styling.fontSize(-3)
                                            color: Colors.red
                                        }

                                        MouseArea {
                                            id: removeMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: CalendarService.removeAccount(modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        // Calendars list (if accounts exist)
                        ColumnLayout {
                            visible: CalendarService.calendars.length > 0
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: root._t("calendar.panel.section_calendars", "CALENDARS")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-3)
                                color: Colors.outline
                                Layout.topMargin: 8
                            }

                            Repeater {
                                model: CalendarService.calendars

                                delegate: RowLayout {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 12
                                        height: 12
                                        radius: 3
                                        color: modelData.color || Colors.primary
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || "Calendar"
                                        font.family: Config.defaultFont
                                        font.pixelSize: Styling.fontSize(-1)
                                        color: Colors.overBackground
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: CalendarService.accountName(modelData.accountId)
                                        font.family: Config.defaultFont
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: Colors.outline
                                    }

                                    Switch {
                                        checked: modelData.enabled !== false
                                        onToggled: CalendarService.setCalendarEnabled(modelData.id, checked)
                                        indicator: Rectangle {
                                            implicitWidth: 36
                                            implicitHeight: 18
                                            radius: 9
                                            color: parent.checked ? Colors.primary : Colors.surfaceBright

                                            Rectangle {
                                                x: parent.parent.checked ? parent.width - width - 2 : 2
                                                y: 2
                                                width: 14
                                                height: 14
                                                radius: 7
                                                color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                                Behavior on x { NumberAnimation { duration: 150 } }
                                            }
                                        }
                                        background: null
                                    }
                                }
                            }
                        }

                        // gcalcli detected — quick import
                        StyledRect {
                            visible: CalendarService.gcalcliFound && !root.hasGoogleAccount
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            variant: "pane"
                            radius: Styling.radius(0)
                            implicitHeight: gcalcliCol.implicitHeight + 20

                            ColumnLayout {
                                id: gcalcliCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Text {
                                    text: root._t("calendar.panel.gcalcli_found", "gcalcli token found")
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-2)
                                    color: Colors.outline
                                }

                                Text {
                                    text: root._t("calendar.panel.gcalcli_detected", "An existing Google Calendar token from gcalcli was detected. You can import it to connect your account instantly.")
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-2)
                                    color: Colors.overBackground
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                StyledRect {
                                    Layout.fillWidth: true
                                    variant: gcalcliMouse.containsMouse ? "primaryfocus" : "primary"
                                    implicitHeight: 36
                                    radius: Styling.radius(-2)

                                    Text {
                                        anchors.centerIn: parent
                                        text: root._t("calendar.panel.import_gcalcli", "Import from gcalcli")
                                        font.family: Config.defaultFont
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: Font.DemiBold
                                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                    }

                                    MouseArea {
                                        id: gcalcliMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: CalendarService.importGcalcli()
                                    }
                                }
                            }
                        }

                        // Add account buttons
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            spacing: 8

                            StyledRect {
                                Layout.fillWidth: true
                                variant: googleMouse.containsMouse ? "primaryfocus" : "primary"
                                implicitHeight: 36
                                radius: Styling.radius(-2)

                                Text {
                                    anchors.centerIn: parent
                                    text: root._t("calendar.panel.add_google", "+ Google OAuth")
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                }

                                MouseArea {
                                    id: googleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: CalendarService.authGoogle()
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                variant: caldavMouse.containsMouse ? "primaryfocus" : "primary"
                                implicitHeight: 36
                                radius: Styling.radius(-2)

                                Text {
                                    anchors.centerIn: parent
                                    text: root._t("calendar.panel.add_caldav", "+ CalDAV")
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                }

                                MouseArea {
                                    id: caldavMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: caldavForm.visible = !caldavForm.visible
                                }
                            }
                        }

                        Text {
                            visible: !CalendarService.gcalcliFound
                            text: root._t("calendar.panel.oauth_hint", "Enter your Google OAuth Client ID and Secret above, then click Connect. If you have gcalcli installed and authenticated, its token will be detected automatically.")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Auth error display
                        Text {
                            visible: CalendarService.authError !== ""
                            text: CalendarService.authError
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.red
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // CalDAV connection form
                        ColumnLayout {
                            id: caldavForm
                            visible: false
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: root._t("calendar.panel.caldav_server", "CalDAV Server")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overBackground
                            }

                            TextField {
                                id: caldavNameField
                                Layout.fillWidth: true
                                implicitHeight: 36
                                leftPadding: 8; rightPadding: 8
                                topPadding: 0; bottomPadding: 0
                                verticalAlignment: TextInput.AlignVCenter
                                placeholderText: root._t("calendar.panel.caldav_name", "Account name (optional)")
                                placeholderTextColor: Colors.outline
                                text: root.caldavName
                                onTextChanged: root.caldavName = text
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                selectByMouse: true
                                background: Item {
                                    StyledRect {
                                        anchors.fill: parent
                                        variant: "common"
                                        radius: Styling.radius(-2)
                                        enableBorder: false
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: caldavNameField.activeFocus ? Colors.primary : Colors.outlineVariant
                                        border.width: 1
                                        radius: Styling.radius(-2)
                                    }
                                }
                            }

                            TextField {
                                id: caldavUrlField
                                Layout.fillWidth: true
                                implicitHeight: 36
                                leftPadding: 8; rightPadding: 8
                                topPadding: 0; bottomPadding: 0
                                verticalAlignment: TextInput.AlignVCenter
                                placeholderText: "https://cloud.example.com/remote.php/dav"
                                placeholderTextColor: Colors.outline
                                text: root.caldavUrl
                                onTextChanged: root.caldavUrl = text.replace(/[\r\n\t ]/g, "")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                selectByMouse: true
                                background: Item {
                                    StyledRect {
                                        anchors.fill: parent
                                        variant: "common"
                                        radius: Styling.radius(-2)
                                        enableBorder: false
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: caldavUrlField.activeFocus ? Colors.primary : Colors.outlineVariant
                                        border.width: 1
                                        radius: Styling.radius(-2)
                                    }
                                }
                            }

                            TextField {
                                id: caldavUserField
                                Layout.fillWidth: true
                                implicitHeight: 36
                                leftPadding: 8; rightPadding: 8
                                topPadding: 0; bottomPadding: 0
                                verticalAlignment: TextInput.AlignVCenter
                                placeholderText: root._t("calendar.panel.username", "Username")
                                placeholderTextColor: Colors.outline
                                text: root.caldavUser
                                onTextChanged: root.caldavUser = text
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                selectByMouse: true
                                background: Item {
                                    StyledRect {
                                        anchors.fill: parent
                                        variant: "common"
                                        radius: Styling.radius(-2)
                                        enableBorder: false
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: caldavUserField.activeFocus ? Colors.primary : Colors.outlineVariant
                                        border.width: 1
                                        radius: Styling.radius(-2)
                                    }
                                }
                            }

                            TextField {
                                id: caldavPassField
                                Layout.fillWidth: true
                                implicitHeight: 36
                                leftPadding: 8; rightPadding: 8
                                topPadding: 0; bottomPadding: 0
                                verticalAlignment: TextInput.AlignVCenter
                                placeholderText: root._t("calendar.panel.password", "Password")
                                placeholderTextColor: Colors.outline
                                text: root.caldavPass
                                onTextChanged: root.caldavPass = text
                                echoMode: TextInput.Password
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                selectByMouse: true
                                background: Item {
                                    StyledRect {
                                        anchors.fill: parent
                                        variant: "common"
                                        radius: Styling.radius(-2)
                                        enableBorder: false
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: caldavPassField.activeFocus ? Colors.primary : Colors.outlineVariant
                                        border.width: 1
                                        radius: Styling.radius(-2)
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                variant: connectMouse.containsMouse ? "primaryfocus" : "primary"
                                implicitHeight: 32
                                radius: Styling.radius(-2)

                                Text {
                                    anchors.centerIn: parent
                                    text: root._t("calendar.panel.connect", "Connect")
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.DemiBold
                                    color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                }

                                MouseArea {
                                    id: connectMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        CalendarService.authCalDAV(root.caldavUrl, root.caldavUser, root.caldavPass, root.caldavName);
                                        root.caldavName = "";
                                        root.caldavUrl = "";
                                        root.caldavUser = "";
                                        root.caldavPass = "";
                                        caldavForm.visible = false;
                                    }
                                }
                            }
                        }
                    }

                    // ── Settings section ──
                    ColumnLayout {
                        visible: root.currentSection === "settings"
                        Layout.fillWidth: true
                        spacing: 12

                        // Google OAuth credentials
                        Text {
                            text: root._t("calendar.panel.section_google", "GOOGLE OAUTH")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        TextField {
                            id: googleClientIdField
                            Layout.fillWidth: true
                            implicitHeight: 36
                            leftPadding: 8; rightPadding: 8
                            topPadding: 0; bottomPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: root._t("calendar.panel.google_client_id", "Google Client ID")
                            placeholderTextColor: Colors.outline
                            text: root.pendingGoogleClientId
                            onTextChanged: root.pendingGoogleClientId = text
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            selectByMouse: true
                            background: Item {
                                StyledRect {
                                    anchors.fill: parent
                                    variant: "common"
                                    radius: Styling.radius(-2)
                                    enableBorder: false
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: googleClientIdField.activeFocus ? Colors.primary : Colors.outlineVariant
                                    border.width: 1
                                    radius: Styling.radius(-2)
                                }
                            }
                        }

                        TextField {
                            id: googleClientSecretField
                            Layout.fillWidth: true
                            implicitHeight: 36
                            leftPadding: 8; rightPadding: 8
                            topPadding: 0; bottomPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: root._t("calendar.panel.google_client_secret", "Google Client Secret")
                            placeholderTextColor: Colors.outline
                            text: root.pendingGoogleClientSecret
                            onTextChanged: root.pendingGoogleClientSecret = text
                            echoMode: TextInput.Password
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            selectByMouse: true
                            background: Item {
                                StyledRect {
                                    anchors.fill: parent
                                    variant: "common"
                                    radius: Styling.radius(-2)
                                    enableBorder: false
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: googleClientSecretField.activeFocus ? Colors.primary : Colors.outlineVariant
                                    border.width: 1
                                    radius: Styling.radius(-2)
                                }
                            }
                        }

                        Text {
                            text: root._t("calendar.panel.google_credentials_hint", "Create credentials at console.cloud.google.com (Calendar API, Desktop app type).")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.bottomMargin: 8
                        }

                        // Sync interval
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: root._t("calendar.panel.sync_interval", "Sync interval")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                Layout.fillWidth: true
                            }

                            ComboBox {
                                id: syncIntervalCombo
                                implicitHeight: 36
                                model: [
                                    { text: root._t("calendar.form.reminder_minutes", "%1 min", 5), value: 5 },
                                    { text: root._t("calendar.form.reminder_minutes", "%1 min", 15), value: 15 },
                                    { text: root._t("calendar.form.reminder_minutes", "%1 min", 30), value: 30 },
                                    { text: root._t("calendar.form.reminder_minutes", "%1 min", 60), value: 60 }
                                ]
                                textRole: "text"
                                valueRole: "value"
                                currentIndex: {
                                    const vals = [5, 15, 30, 60];
                                    const idx = vals.indexOf(root.pendingSyncInterval);
                                    return idx >= 0 ? idx : 1;
                                }
                                onCurrentValueChanged: if (currentValue) root.pendingSyncInterval = currentValue
                                background: Rectangle {
                                    color: syncIntervalCombo.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                                    radius: Styling.radius(-2)
                                    border.color: Colors.outlineVariant
                                    border.width: 1
                                }
                                contentItem: Text {
                                    leftPadding: 10
                                    rightPadding: 32
                                    text: syncIntervalCombo.displayText
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                indicator: Text {
                                    x: syncIntervalCombo.width - width - 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Icons.caretDown
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: Colors.overBackground
                                }
                                popup: Popup {
                                    y: syncIntervalCombo.height + 4
                                    width: syncIntervalCombo.width
                                    padding: 4
                                    background: Rectangle {
                                        color: Colors.surfaceContainerLow
                                        radius: Styling.radius(-1)
                                        border.color: Colors.outlineVariant
                                        border.width: 1
                                    }
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: Math.min(contentHeight, 200)
                                        model: syncIntervalCombo.popup.visible ? syncIntervalCombo.delegateModel : null
                                        currentIndex: syncIntervalCombo.highlightedIndex
                                        ScrollIndicator.vertical: ScrollIndicator {}
                                    }
                                }
                                delegate: ItemDelegate {
                                    id: syncIntervalDelegate
                                    required property var modelData
                                    required property int index
                                    width: ListView.view.width
                                    height: 32
                                    highlighted: syncIntervalCombo.highlightedIndex === index
                                    background: Rectangle {
                                        color: syncIntervalDelegate.highlighted ? Colors.surfaceContainerHigh : "transparent"
                                        radius: Styling.radius(-2)
                                    }
                                    contentItem: Text {
                                        leftPadding: 8
                                        text: syncIntervalDelegate.modelData.text || ""
                                        font.family: Config.defaultFont
                                        font.pixelSize: Styling.fontSize(-1)
                                        color: Colors.overBackground
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        // Notifications toggle
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root._t("calendar.panel.notifications", "Notifications")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                Layout.fillWidth: true
                            }

                            Switch {
                                checked: root.pendingNotifications
                                onToggled: root.pendingNotifications = checked
                                indicator: Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    radius: 9
                                    color: parent.checked ? Colors.primary : Colors.surfaceBright
                                    Rectangle {
                                        x: parent.parent.checked ? parent.width - width - 2 : 2
                                        y: 2; width: 14; height: 14; radius: 7
                                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                }
                                background: null
                            }
                        }

                        // Bar indicator toggle
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root._t("calendar.panel.bar_indicator", "Bar indicator")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                Layout.fillWidth: true
                            }

                            Switch {
                                checked: root.pendingBarIndicator
                                onToggled: root.pendingBarIndicator = checked
                                indicator: Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    radius: 9
                                    color: parent.checked ? Colors.primary : Colors.surfaceBright
                                    Rectangle {
                                        x: parent.parent.checked ? parent.width - width - 2 : 2
                                        y: 2; width: 14; height: 14; radius: 7
                                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                }
                                background: null
                            }
                        }

                        // Bar — show next event toggle
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root._t("calendar.panel.bar_show_next", "Show next upcoming event")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: root.pendingBarIndicator ? Colors.overBackground : Colors.outline
                                Layout.fillWidth: true
                            }

                            Switch {
                                enabled: root.pendingBarIndicator
                                checked: root.pendingBarShowNextEvent
                                onToggled: root.pendingBarShowNextEvent = checked
                                indicator: Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    radius: 9
                                    color: parent.checked && parent.enabled ? Colors.primary : Colors.surfaceBright
                                    opacity: parent.enabled ? 1 : 0.4
                                    Rectangle {
                                        x: parent.parent.checked ? parent.width - width - 2 : 2
                                        y: 2; width: 14; height: 14; radius: 7
                                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                }
                                background: null
                            }
                        }

                        // Bar — always show toggle
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root._t("calendar.settings.bar_always_show", "Always show in bar")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: root.pendingBarIndicator ? Colors.overBackground : Colors.outline
                                Layout.fillWidth: true
                            }

                            Switch {
                                enabled: root.pendingBarIndicator
                                checked: root.pendingBarAlwaysShow
                                onToggled: root.pendingBarAlwaysShow = checked
                                indicator: Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    radius: 9
                                    color: parent.checked && parent.enabled ? Colors.primary : Colors.surfaceBright
                                    opacity: parent.enabled ? 1 : 0.4
                                    Rectangle {
                                        x: parent.parent.checked ? parent.width - width - 2 : 2
                                        y: 2; width: 14; height: 14; radius: 7
                                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                }
                                background: null
                            }
                        }

                        // Default reminder
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: root._t("calendar.panel.default_reminder", "Default reminder")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                Layout.fillWidth: true
                            }

                            ComboBox {
                                id: defaultReminderCombo
                                implicitHeight: 36
                                model: [
                                    { text: root._t("calendar.form.reminder_none", "None"), value: 0 },
                                    { text: root._t("calendar.form.reminder_minutes", "%1 min", 5), value: 5 },
                                    { text: root._t("calendar.form.reminder_minutes", "%1 min", 10), value: 10 },
                                    { text: root._t("calendar.form.reminder_minutes", "%1 min", 15), value: 15 },
                                    { text: root._t("calendar.form.reminder_minutes", "%1 min", 30), value: 30 },
                                    { text: root._t("calendar.form.reminder_1hour", "1 hour"), value: 60 }
                                ]
                                textRole: "text"
                                valueRole: "value"
                                currentIndex: {
                                    const vals = [0, 5, 10, 15, 30, 60];
                                    const idx = vals.indexOf(root.pendingDefaultReminder);
                                    return idx >= 0 ? idx : 3;
                                }
                                onCurrentValueChanged: if (currentValue !== undefined) root.pendingDefaultReminder = currentValue
                                background: Rectangle {
                                    color: defaultReminderCombo.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                                    radius: Styling.radius(-2)
                                    border.color: Colors.outlineVariant
                                    border.width: 1
                                }
                                contentItem: Text {
                                    leftPadding: 10
                                    rightPadding: 32
                                    text: defaultReminderCombo.displayText
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                indicator: Text {
                                    x: defaultReminderCombo.width - width - 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Icons.caretDown
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: Colors.overBackground
                                }
                                popup: Popup {
                                    y: defaultReminderCombo.height + 4
                                    width: defaultReminderCombo.width
                                    padding: 4
                                    background: Rectangle {
                                        color: Colors.surfaceContainerLow
                                        radius: Styling.radius(-1)
                                        border.color: Colors.outlineVariant
                                        border.width: 1
                                    }
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: Math.min(contentHeight, 200)
                                        model: defaultReminderCombo.popup.visible ? defaultReminderCombo.delegateModel : null
                                        currentIndex: defaultReminderCombo.highlightedIndex
                                        ScrollIndicator.vertical: ScrollIndicator {}
                                    }
                                }
                                delegate: ItemDelegate {
                                    id: defaultReminderDelegate
                                    required property var modelData
                                    required property int index
                                    width: ListView.view.width
                                    height: 32
                                    highlighted: defaultReminderCombo.highlightedIndex === index
                                    background: Rectangle {
                                        color: defaultReminderDelegate.highlighted ? Colors.surfaceContainerHigh : "transparent"
                                        radius: Styling.radius(-2)
                                    }
                                    contentItem: Text {
                                        leftPadding: 8
                                        text: defaultReminderDelegate.modelData.text || ""
                                        font.family: Config.defaultFont
                                        font.pixelSize: Styling.fontSize(-1)
                                        color: Colors.overBackground
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        // Arrival attention settings
                        Text {
                            text: root._t("calendar.panel.section_arrival", "ARRIVAL ATTENTION")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                            Layout.topMargin: 4
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root._t("calendar.panel.sound_on_arrival", "Sound on arrival")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: root.pendingNotifications ? Colors.overBackground : Colors.outline
                                Layout.fillWidth: true
                            }

                            Switch {
                                enabled: root.pendingNotifications
                                checked: root.pendingSoundOnArrival
                                onToggled: root.pendingSoundOnArrival = checked
                                indicator: Rectangle {
                                    implicitWidth: 36; implicitHeight: 18; radius: 9
                                    color: parent.checked && parent.enabled ? Colors.primary : Colors.surfaceBright
                                    opacity: parent.enabled ? 1 : 0.4
                                    Rectangle {
                                        x: parent.parent.checked ? parent.width - width - 2 : 2
                                        y: 2; width: 14; height: 14; radius: 7
                                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                }
                                background: null
                            }
                        }

                        // Custom sound path (shown when sound is enabled)
                        ColumnLayout {
                            visible: root.pendingSoundOnArrival && root.pendingNotifications
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: root._t("calendar.panel.custom_sound", "Custom sound file")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-3)
                                color: Colors.outline
                            }

                            TextField {
                                id: arrivalSoundField
                                Layout.fillWidth: true
                                implicitHeight: 36
                                leftPadding: 8; rightPadding: 8
                                topPadding: 0; bottomPadding: 0
                                verticalAlignment: TextInput.AlignVCenter
                                placeholderText: root._t("calendar.panel.sound_hint_default", "Leave empty to use system default")
                                placeholderTextColor: Colors.outline
                                text: root.pendingArrivalSoundPath
                                onTextChanged: root.pendingArrivalSoundPath = text
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                selectByMouse: true
                                background: Item {
                                    StyledRect {
                                        anchors.fill: parent
                                        variant: "common"
                                        radius: Styling.radius(-2)
                                        enableBorder: false
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: arrivalSoundField.activeFocus ? Colors.primary : Colors.outlineVariant
                                        border.width: 1
                                        radius: Styling.radius(-2)
                                    }
                                }
                            }

                            Text {
                                text: root._t("calendar.panel.sound_hint_formats", "Supports .oga, .ogg, .wav, .mp3")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-4)
                                color: Colors.outline
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root._t("calendar.panel.blink_on_arrival", "Blink icon on arrival")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: root.pendingBarIndicator ? Colors.overBackground : Colors.outline
                                Layout.fillWidth: true
                            }

                            Switch {
                                enabled: root.pendingBarIndicator
                                checked: root.pendingBlinkOnArrival
                                onToggled: root.pendingBlinkOnArrival = checked
                                indicator: Rectangle {
                                    implicitWidth: 36; implicitHeight: 18; radius: 9
                                    color: parent.checked && parent.enabled ? Colors.primary : Colors.surfaceBright
                                    opacity: parent.enabled ? 1 : 0.4
                                    Rectangle {
                                        x: parent.parent.checked ? parent.width - width - 2 : 2
                                        y: 2; width: 14; height: 14; radius: 7
                                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                }
                                background: null
                            }
                        }

                        // Save / Reset buttons
                        RowLayout {
                            visible: root.hasChanges
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            spacing: 8

                            StyledRect {
                                Layout.fillWidth: true
                                variant: saveBtnMouse.containsMouse ? "primaryfocus" : "primary"
                                implicitHeight: 32
                                radius: Styling.radius(-2)

                                Text {
                                    anchors.centerIn: parent
                                    text: root._t("calendar.panel.save", "Save")
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.DemiBold
                                    color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                                }

                                MouseArea {
                                    id: saveBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.saveToConfig()
                                }
                            }

                            StyledRect {
                                variant: resetBtnMouse.containsMouse ? "focus" : "common"
                                implicitWidth: 64
                                implicitHeight: 32
                                radius: Styling.radius(-2)

                                Text {
                                    anchors.centerIn: parent
                                    text: root._t("calendar.panel.reset", "Reset")
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.outline
                                }

                                MouseArea {
                                    id: resetBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.resetToConfig()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
