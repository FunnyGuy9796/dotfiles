import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls

ShellRoot {
    id: shellRoot

    function closePopups(keep) {
        if (!keep.includes("netmenu"))
            netMenu.visible = false

        if (!keep.includes("wifilist"))
            wifiList.visible = false

        if (!keep.includes("btlist"))
            btList.visible = false

        if (!keep.includes("powermenu"))
            powerMenu.visible = false
    }

    HyprlandFocusGrab {
        id: quickSettingsGrab
        windows: [netMenu, wifiList, btList, powerMenu]
        active: netMenu.visible || wifiList.visible || btList.visible || powerMenu.visible
        onCleared: shellRoot.closePopups([])
    }

    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }

        margins {
            top: 10
        }

        implicitHeight: 30
        color: "transparent"

        Rectangle {
            id: workspaceIsland
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: wsRow.width + 16
            height: 30
            radius: 8
            color: "#111111"

            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: 9

                    Rectangle {
                        property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                        property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                        property bool hasWindows: ws !== undefined

                        width: 24
                        height: 24
                        radius: 4
                        color: isActive ? "#3b4261" : (hasWindows ? "#333333" : "transparent")
                        border.width: hasWindows && !isActive ? 1 : 0
                        border.color: "#333333"

                        Text {
                            anchors.centerIn: parent
                            text: (index + 1).toString()
                            color: isActive ? "white" : (hasWindows ? "#cccccc" : "#666666")
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Hyprland.dispatch("workspace " + (index + 1))
                        }
                    }
                }
            }
        }

        Rectangle {
            id: clockIsland
            anchors.centerIn: parent
            width: clockText.width + dateText.width + 76
            height: 30
            radius: 8
            color: "#111111"

            Item {
                id: clockWidget
                anchors.centerIn: parent
                width: clockText.width + dateText.width + 60
                height: clockText.height

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -30
                    text: Qt.formatDateTime(new Date(), "h:mm AP")
                    color: "white"

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: parent.text = Qt.formatDateTime(new Date(), "h:mm AP")
                    }
                }

        	    Text {
                    id: dateText
              		anchors.centerIn: parent
              		anchors.horizontalCenterOffset:	30
              		text: Qt.formatDateTime(new Date(), "ddd, MMM d")
              		color: "white"

              		Timer {
              		    interval: 60000
              		    running: true
              		    repeat: true
              		    onTriggered: parent.text = Qt.formatDateTime(new Date(), "ddd, MMM d")
              		}
        	    }

                MouseArea {
                    id: clockMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: launcher.toggle()
                }
            }
        }

        Rectangle {
            id: statusIsland
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: statusRow.width + 66
            height: 30
            radius: 8
            color: "#111111"

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 16

                Item {
                    id: sensorsWidget
                    width: sensorsRow.width
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    property real cpuTemp: 0
                    property int fanRpm: 0

                    Row {
                        id: sensorsRow
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            color: sensorsWidget.cpuTemp >= 80 ? "#ff6b6b" : "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            text: "󰔏 " + Math.round(sensorsWidget.cpuTemp) + "°C"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            color: "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            text: "󰈐 " + sensorsWidget.fanRpm
                        }
                    }

                    Process {
                        id: cpuTempProc
                        command: ["sensors", "-A", "-u", "coretemp-isa-0000"]
                        running: true
                        stdout: SplitParser {
                            onRead: data => {
                                const trimmed = data.trim()
                                if (trimmed.startsWith("temp1_input:")) {
                                    sensorsWidget.cpuTemp = parseFloat(trimmed.split(":")[1])
                                }
                            }
                        }
                    }

                    Process {
                        id: fanProc
                        command: ["sensors", "-A", "-u", "nct6798-isa-02a0"]
                        running: true
                        stdout: SplitParser {
                            onRead: data => {
                                const trimmed = data.trim()
                                if (trimmed.startsWith("fan1_input:")) {
                                    sensorsWidget.fanRpm = Math.round(parseFloat(trimmed.split(":")[1]))
                                }
                            }
                        }
                    }

                    Timer {
                        interval: 3000
                        running: true
                        repeat: true
                        onTriggered: {
                            cpuTempProc.running = true
                            fanProc.running = true
                        }
                    }
                }

                Item {
                    id: netWidget
                    width: netIcon.width
                    height: netIcon.height
                    anchors.verticalCenter: parent.verticalCenter

                    property string connectionType: "disconnected"
                    property int signalStrength: 0
                    property string wifiDevice: ""

                    Text {
                        id: netIcon
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        text: {
                            if (netWidget.connectionType == "ethernet")
                                return ""

                            if (netWidget.connectionType == "disconnected")
                                return "󰣽"

                            if (netWidget.signalStrength >= 75)
                                return "󰣺"

                            if (netWidget.signalStrength >= 50)
                                return "󰣸"

                            if (netWidget.signalStrength >= 25)
                                return "󰣶"

                            return "󰣴"
                        }
                    }

                    MouseArea {
                        id: netMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: netMenu.toggleMenu()
                    }

                    Process {
                        id: netProc
                        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]
                        running: true
                        stdout: SplitParser {
                            onRead: data => {
                                const parts = data.split(":")
                                const device = parts[0]
                                const type = parts[1]
                                const state = parts[2]

                                if (device === "lo")
                                    return

                                if (type === "wifi")
                                    netWidget.wifiDevice = device

                                if (type === "ethernet" && state === "connected")
                                    netWidget.connectionType = "ethernet"
                                else if (type === "wifi" && state === "connected") {
                                    netWidget.connectionType = "wifi"
                                    signalProc.running = true
                                } else if (type === "wifi" && state === "disconnected") {
                                    netWidget.connectionType = "disconnected"
                                    netWidget.signalStrength = 0
                                }
                            }
                        }
                    }

                    Process {
                        id: signalProc
                        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL", "device", "wifi", "list"]
                        running: false
                        stdout: SplitParser {
                            onRead: data => {
                                const parts = data.split(":")
                                if (parts[0] === "yes")
                                    netWidget.signalStrength = parseInt(parts[1]) || 0
                            }
                        }
                    }

                    Timer {
                        interval: 5000
                        running: true
                        repeat: true
                        onTriggered: netProc.running = true
                    }
                }

                Item {
                    id: powerWidget
                    width: powerIcon.width
                    height: powerIcon.height
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: powerIcon
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        text: "⏻"
                    }

                    MouseArea {
                        id: powerMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: powerMenu.toggleMenu()
                    }
                }
            }
        }
    }

    FloatingWindow {
        id: launcher
        visible: false
        implicitWidth: 500
        implicitHeight: 400
        title: "launcher"

        function toggle(): void {
            launcher.visible = !launcher.visible
        }

        HyprlandFocusGrab {
            id: launcherGrab
            windows: [launcher]
            active: launcher.visible
            onCleared: launcher.visible = false
        }

        IpcHandler {
            target: "launcher"

            function toggle(): void {
                launcher.toggle()
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#111111"
            radius: 8

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                TextInput {
                    id: searchBox
                    width: parent.width
                    height: 30
                    leftPadding: 10
                    rightPadding: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"
                    focus: launcher.visible
                    font.pixelSize: 16

                    Rectangle {
                        anchors.fill: parent
                        color: "#333333"
                        z: -1
                        radius: 4
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            appList.currentIndex = Math.min(appList.currentIndex + 1, appList.count - 1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            appList.currentIndex = Math.max(appList.currentIndex - 1, 0)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            const app = appList.filteredApps[appList.currentIndex]

                            if (app) {
                                app.execute()
                                launcher.visible = false
                            }

                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            launcher.visible = false
                            event.accepted = true
                        }
                    }

                    onTextChanged: appList.currentIndex = 0
                }

                ListView {
                    id: appList
                    width: parent.width
                    height: parent.height - 40
                    clip: true
                    currentIndex: 0

                    property var filteredApps: DesktopEntries.applications.values.filter(app =>
                        app.name.toLowerCase().includes(searchBox.text.toLowerCase())
                    )

                    model: filteredApps

                    highlight: Rectangle {
                        color: "#3b4261"
                        radius: 4
                    }
                    highlightMoveDuration: 100

                    delegate: Rectangle {
                        width: appList.width
                        height: 40
                        color: "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            IconImage {
                                width: 24
                                height: 24
                                anchors.verticalCenter: parent.verticalCenter
                                source: Quickshell.iconPath(modelData.icon, true)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: "white"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                modelData.execute()
                                launcher.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    FloatingWindow {
        id: netMenu
        visible: false
        implicitWidth: 180
        implicitHeight: 70
        title: "netmenu"

        function openMenu() {
            shellRoot.closePopups(["netmenu"])
            wifiStateProc.running = true
            visible = true
        }

        function toggleMenu() {
            if (visible) {
                visible = false
            } else
                openMenu()
        }

        IpcHandler {
            target: "netmenu"

            function toggle(): void {
                netMenu.toggleMenu()
            }
        }

        property bool wifiEnabled: true

        Process {
            id: wifiStateProc
            command: ["nmcli", "-t", "-f", "WIFI", "general", "status"]
            running: false
            stdout: SplitParser {
                onRead: data => {
                    netMenu.wifiEnabled = data.trim() === "enabled"
                }
            }
        }

        Process {
            id: wifiToggleProc

            property bool turningOff: false

            running: false
            onExited: exitCode => {
                if (exitCode === 0)
                    wifiStateProc.running = true
            }
        }

        function toggleWifi() {
            const turningOff = wifiEnabled

            wifiToggleProc.turningOff = turningOff
            wifiToggleProc.command = turningOff ? ["nmcli", "radio", "wifi", "off"] : ["nmcli", "radio", "wifi", "on"]
            wifiToggleProc.running = true
        }

        Rectangle {
            anchors.fill: parent
            color: "#111111"
            radius: 8

            Row {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 80
                    height: 50
                    radius: 4
                    color: netMenu.wifiEnabled ? "#3b4261" : "#333333"

                    Row {
                        anchors.fill: parent

                        Item {
                            width: parent.width / 2
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: "󰤨"
                                color: "white"
                                font.pixelSize: 24
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: netMenu.toggleWifi()
                            }
                        }

                        Item {
                            width: parent.width / 2
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: "white"
                                font.pixelSize: 24
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (wifiList.visible)
                                        wifiList.visible = false
                                    else
                                        wifiList.openMenu()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: 80
                    height: 50
                    radius: 4
                    color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "#3b4261" : "#333333"

                    Row {
                        anchors.fill: parent

                        Item {
                            width: parent.width / 2
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: "󰂯"
                                color: "white"
                                font.pixelSize: 24
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (Bluetooth.defaultAdapter)
                                        Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                                }
                            }
                        }

                        Item {
                            width: parent.width / 2
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: "white"
                                font.pixelSize: 24
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (btList.visible)
                                        btList.visible = false
                                    else
                                        btList.openMenu()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FloatingWindow {
        id: wifiList
        visible: false
        implicitWidth: 400
        implicitHeight: 400
        title: "wifilist"

        function openMenu() {
            shellRoot.closePopups(["wifilist", "netmenu"])
            passwordMode = false
            scanProc.lines = []
            scanProc.running = true
            visible = true
        }

        IpcHandler {
            target: "wifilist"

            function toggle(): void {
                if (wifiList.visible)
                    wifiList.visible = false
                else
                    wifiList.openMenu()
            }
        }

        property var networks: []
        property bool passwordMode: false
        property string pendingSsid: ""

        Process {
            id: scanProc

            property var lines: []

            command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SECURITY,SIGNAL", "device", "wifi", "list"]
            running: false
            stdout: SplitParser {
                onRead: data => scanProc.lines.push(data)
            }
            onExited: {
                const seen = {}

                for (const line of lines) {
                    const parts = line.split(":")
                    const active = parts[0] === "yes"
                    const ssid = parts[1]
                    const security = parts[2]
                    const signal = parseInt(parts[3]) || 0

                    if (!ssid)
                        continue

                    if (!seen[ssid] || signal > seen[ssid].signal || active)
                        seen[ssid] = { ssid, security, signal, active }
                }

                wifiList.networks = Object.values(seen).sort((a, b) => b.signal - a.signal)
            }
        }

        Process {
            id: connectProc
            running: false
            onExited: exitCode => {
                if (exitCode === 0) {
                    wifiList.passwordMode = false
                    wifiList.visible = false
                } else
                    errorText.text = "Connection failed"
            }
        }

        Process {
            id: disconnectProc
            running: false
            onExited: exitCode => {
                if (exitCode === 0)
                    wifiList.openMenu()
            }
        }

        Timer {
            id: wifiGuardResetTimer
            interval: 200
            running: false
            repeat: false
            onTriggered: shellRoot.suppressNetMenuClear = false
        }

        Rectangle {
            anchors.fill: parent
            color: "#111111"
            radius: 8

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                visible: !wifiList.passwordMode

                ListView {
                    id: netList
                    width: parent.width
                    height: parent.height
                    clip: true
                    model: wifiList.networks
                    currentIndex: 0
                    focus: wifiList.visible && !wifiList.passwordMode

                    highlight: Rectangle { color: "#3b4261"; radius: 4 }
                    highlightMoveDuration: 100

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            currentIndex = Math.min(currentIndex + 1, count - 1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            currentIndex = Math.max(currentIndex - 1, 0)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            const net = wifiList.networks[currentIndex]

                            if (net) {
                                if (net.active) {
                                    disconnectProc.command = ["nmcli", "device", "disconnect", netWidget.wifiDevice]
                                    disconnectProc.running = true
                                } else {
                                    const open = !net.security || net.security === "OWE"

                                    if (open) {
                                        connectProc.command = ["nmcli", "device", "wifi", "connect", net.ssid]
                                        connectProc.running = true
                                    } else {
                                        wifiList.pendingSsid = net.ssid
                                        wifiList.passwordMode = true
                                        passwordBox.text = ""
                                    }
                                }
                            }

                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            wifiList.visible = false
                            event.accepted = true
                        }
                    }

                    delegate: Rectangle {
                        width: netList.width
                        height: 40
                        color: "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: (modelData.active ? "✓ " : "") + modelData.ssid + (modelData.security ? "  " : "")
                            color: "white"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.active) {
                                    disconnectProc.command = ["nmcli", "device", "disconnect", netWidget.wifiDevice]
                                    disconnectProc.running = true
                                } else {
                                    const open = !modelData.security || modelData.security === "OWE"

                                    if (open) {
                                        connectProc.command = ["nmcli", "device", "wifi", "connect", modelData.ssid]
                                        connectProc.running = true
                                    } else {
                                        wifiList.pendingSsid = modelData.ssid
                                        wifiList.passwordMode = true
                                        passwordBox.text = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                visible: wifiList.passwordMode

                Text {
                    text: "Password for " + wifiList.pendingSsid
                    color: "white"
                }

                TextInput {
                    id: passwordBox
                    width: parent.width
                    height: 30
                    leftPadding: 10
                    rightPadding: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"
                    echoMode: TextInput.Password
                    focus: wifiList.passwordMode

                    Rectangle {
                        anchors.fill: parent
                        color: "#333333"
                        z: -1
                        radius: 4
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            connectProc.command = ["nmcli", "device", "wifi", "connect", wifiList.pendingSsid, "password", passwordBox.text]
                            connectProc.running = true
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            wifiList.passwordMode = false
                            event.accepted = true
                        }
                    }
                }

                Text {
                    id: errorText
                    color: "#ff6b6b"
                }
            }
        }
    }

    FloatingWindow {
        id: btList
        visible: false
        implicitWidth: 400
        implicitHeight: 400
        title: "btlist"

        function openMenu() {
            shellRoot.closePopups(["btlist", "netmenu"])
            visible = true
        }

        IpcHandler {
            target: "btlist"

            function toggle(): void {
                if (btList.visible)
                    btList.visible = false
                else
                    btList.openMenu()
            }
        }

        Timer {
            id: btGuardResetTimer
            interval: 200
            running: false
            repeat: false
            onTriggered: shellRoot.suppressNetMenuClear = false
        }

        property var devices: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices.values : []

        Rectangle {
            anchors.fill: parent
            color: "#111111"
            radius: 8

            ListView {
                id: btDeviceList
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                model: btList.devices
                currentIndex: 0
                focus: btList.visible

                highlight: Rectangle { color: "#3b4261"; radius: 4 }
                highlightMoveDuration: 100

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        currentIndex = Math.min(currentIndex + 1, count - 1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        currentIndex = Math.max(currentIndex - 1, 0)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        const dev = btList.devices[currentIndex]

                        if (dev)
                            dev.connected = !dev.connected

                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        btList.visible = false
                        event.accepted = true
                    }
                }

                delegate: Rectangle {
                    width: btDeviceList.width
                    height: 40
                    color: "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        text: (modelData.connected ? "✓ " : "") + modelData.name
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: modelData.connected = !modelData.connected
                    }
                }
            }
        }
    }

    FloatingWindow {
        id: powerMenu
        visible: false
        implicitWidth: 130
        implicitHeight: 130
        title: "powermenu"

        function toggleMenu() {
            if (visible)
                visible = false
            else {
                shellRoot.closePopups(["powermenu"])
                visible = true
            }
        }

        IpcHandler {
            target: "powermenu"

            function toggle(): void {
                powerMenu.toggleMenu()
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#111111"
            radius: 8

            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -30
                spacing: 8

                Rectangle {
                    width: 50
                    height: 50
                    radius: 4
                    color: "#333333"

                    Item {
                        width: parent.width
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: "white"
                            font.pixelSize: 24
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                powerMenu.visible = false
                                lockProc.running = true
                            }
                        }
                    }
                }

                Rectangle {
                    width: 50
                    height: 50
                    radius: 4
                    color: "#333333"

                    Item {
                        width: parent.width
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: "⏻"
                            color: "white"
                            font.pixelSize: 36
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                powerMenu.visible = false
                                powerConfirm.request("shutdown")
                            }
                        }
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 30
                spacing: 8

                Rectangle {
                    width: 50
                    height: 50
                    radius: 4
                    color: "#333333"

                    Item {
                        width: parent.width
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: "󰤄"
                            color: "white"
                            font.pixelSize: 24
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                powerMenu.visible = false
                                suspendProc.running = true
                            }
                        }
                    }
                }

                Rectangle {
                    width: 50
                    height: 50
                    radius: 4
                    color: "#333333"

                    Item {
                        width: parent.width
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: "white"
                            font.pixelSize: 24
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                powerMenu.visible = false
                                powerConfirm.request("reboot")
                            }
                        }
                    }
                }
            }
        }

        Process {
            id: lockProc
            command: ["hyprlock"]
            running: false
        }

        Process {
            id: suspendProc
            command: ["systemctl", "suspend"]
            running: false
        }
    }

    FloatingWindow {
        id: powerConfirm
        visible: false
        implicitWidth: 200
        implicitHeight: 100
        title: "powerconfirm"

        HyprlandFocusGrab {
            id: powerConfirmGrab
            windows: [powerConfirm]
            active: powerConfirm.visible
            onCleared: powerConfirm.visible = false
        }

        property string pendingAction: ""
        property int selectedIndex: 0

        function request(action) {
            pendingAction = action
            selectedIndex = 1
            visible = true
        }

        function confirm() {
            if (pendingAction === "shutdown")
                shutdownProc.running = true
            else if (pendingAction === "reboot")
                rebootProc.running = true

            visible = false
        }

        Process { id: rebootProc; command: ["systemctl", "reboot"]; running: false }
        Process { id: shutdownProc; command: ["systemctl", "poweroff"]; running: false }

        Item {
            id: confirmRect
            anchors.fill: parent
            focus: powerConfirm.visible

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    powerConfirm.selectedIndex = powerConfirm.selectedIndex === 0 ? 1 : 0
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab) {
                    powerConfirm.selectedIndex = powerConfirm.selectedIndex === 0 ? 1 : 0
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (powerConfirm.selectedIndex === 0)
                        powerConfirm.confirm()
                    else
                        powerConfirm.visible = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    powerConfirm.visible = false
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#111111"
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: powerConfirm.pendingAction === "shutdown" ? "Shut down now?" : "Restart now?"
                        color: "white"
                        font.pixelSize: 16
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Rectangle {
                            width: 60
                            height: 36
                            radius: 4
                            color: powerConfirm.selectedIndex === 0 ? "#3b4261" : "#333333"

                            Text {
                                anchors.centerIn: parent
                                text: "Yes"
                                color: "white"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: powerConfirm.confirm()
                            }
                        }

                        Rectangle {
                            width: 60
                            height: 36
                            radius: 4
                            color: powerConfirm.selectedIndex === 1 ? "#3b4261" : "#333333"

                            Text {
                                anchors.centerIn: parent
                                text: "No"
                                color: "white"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: powerConfirm.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    FloatingWindow {
        id: volumeOsd
        visible: false
        implicitWidth: 200
        implicitHeight: 60
        title: "volumeosd"

        property real volume: 0
        property bool muted: false

        function openOSD() {
            volProc.running = true
            visible = true
            hideTimer.restart()
        }

        IpcHandler {
            target: "volumeosd"

            function trigger(): void {
                volumeOsd.openOSD()
            }
        }

        Timer {
            id: hideTimer
            interval: 1500
            running: false
            repeat: false
            onTriggered: volumeOsd.visible = false
        }

        Process {
            id: volProc
            command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
            running: false
            stdout: SplitParser {
                onRead: data => {
                    volumeOsd.muted = data.includes("MUTED")

                    const match = data.match(/[\d.]+/)

                    if (match)
                        volumeOsd.volume = parseFloat(match[0])
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#111111"
            radius: 8

            Row {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: "white"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 24
                    text: {
                        if (volumeOsd.muted)
                            return "󰝟"

                        if (volumeOsd.volume >= 0.5)
                            return "󰕾"
                        if (volumeOsd.volume > 0)
                            return "󰖀"

                        return "󰕿"
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 100
                    height: 8
                    radius: 4
                    color: "#333333"

                    Rectangle {
                        width: parent.width * Math.min(volumeOsd.volume, 1.0)
                        height: parent.height
                        radius: 4
                        color: "#3b4261"
                    }
                }
            }
        }
    }
}
