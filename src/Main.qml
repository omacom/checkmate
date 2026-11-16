import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
  id: window
  width: 1280
  height: 850
  minimumWidth: 920
  minimumHeight: 650
  visible: true
  title: "Checkmate"
  color: theme.background
  Material.theme: theme.light ? Material.Light : Material.Dark
  Material.accent: theme.accent
  Material.background: theme.background
  Material.foreground: theme.foreground
  Overlay.modal: Rectangle { color: "#80000000" }
  font.family: "sans-serif"
  font.pixelSize: 14
  property color line: Qt.alpha(theme.foreground,.13)
  property color muted: Qt.alpha(theme.foreground,.58)
  property var setNames: [qsTr("Orbital Orders"),qsTr("Midnight Atelier"),qsTr("Moss & Myth"),qsTr("Candy Kingdom")]
  property var setDescriptions: [qsTr("Across the stars"),qsTr("Wood, ivory & brass"),qsTr("A woodland tale"),qsTr("A little sweetness")]
  property var setColors: ["#d9ad69","#c99b6b","#93a775","#db9eb2"]
  property var difficultyNames: [qsTr("Casual"),qsTr("Thoughtful"),qsTr("Challenging")]
  // Tab clears the header and sidebar away so only the board is left; it comes back with every launch.
  property bool chrome: true
  property bool modalOpen: newGameDialog.visible || settingsDialog.visible || helpDialog.visible || promotionDialog.visible || setMenu.visible
  function statusText() {
    if (backend.outcome === "white-wins") return qsTr("White wins by checkmate")
    if (backend.outcome === "black-wins") return qsTr("Black wins by checkmate")
    if (backend.outcome === "stalemate") return qsTr("Draw by stalemate")
    if (backend.outcome === "material") return qsTr("Draw · insufficient material")
    if (backend.outcome === "fifty-moves") return qsTr("Draw · fifty-move rule")
    if (backend.outcome === "repetition") return qsTr("Draw · threefold repetition")
    if (backend.thinking) return backend.agent ? qsTr("%1 is thinking…").arg(backend.agentName) : qsTr("Considering the next move…")
    if (backend.checked) return backend.whiteTurn ? qsTr("White is in check") : qsTr("Black is in check")
    return backend.whiteTurn ? qsTr("White to move") : qsTr("Black to move")
  }
  component FlatButton: Button {
    id: control
    Material.roundedScale: theme.radius
    implicitHeight: 38
    background: Rectangle {
      radius: theme.radius
      color: control.down ? Qt.alpha(theme.accent,.22) : control.hovered ? Qt.alpha(theme.foreground,.09) : "transparent"
      border.color: window.line
    }
    contentItem: Text {
      text: control.text
      color: control.enabled ? theme.foreground : window.muted
      opacity: control.enabled ? 1 : .5
      font: control.font
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }
  // Quiet toolbar buttons for the header: no outline, a soft fill on hover, and no Material insets so every one stands the same height.
  component HeaderButton: Button {
    id: header
    property bool lit: false
    property color tint: theme.foreground
    implicitHeight: 34
    topInset: 0; bottomInset: 0; leftInset: 0; rightInset: 0
    leftPadding: 14; rightPadding: 14
    font.pixelSize: 13
    background: Rectangle {
      radius: theme.radius
      color: header.down ? Qt.alpha(header.tint,.2) : header.lit ? Qt.alpha(header.tint,header.hovered ? .2 : .13) : header.hovered ? Qt.alpha(theme.foreground,.07) : "transparent"
      Behavior on color { enabled: !backend.reducedMotion; ColorAnimation { duration: 120 } }
    }
    contentItem: Text {
      text: header.text
      color: header.lit || header.hovered ? theme.foreground : Qt.alpha(theme.foreground,.72)
      font: header.font
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }
  Item {
    anchors.fill: parent
    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    ColumnLayout {
      anchors.fill: parent
      spacing: 0
      Rectangle {
        objectName: "header"
        visible: window.chrome
        Layout.fillWidth: true
        Layout.preferredHeight: 70
        color: theme.background
        RowLayout {
          anchors { fill: parent; leftMargin: 26; rightMargin: 24 }
          spacing: 13
          Text { text: "♔"; color: window.setColors[backend.pieceSet]; font.pixelSize: 32 }
          Text { text: "Checkmate"; color: theme.foreground; font.family: "serif"; font.pixelSize: 29 }
          Rectangle { Layout.leftMargin: 12; width: 1; height: 22; color: window.line }
          Button {
            id: setPicker
            objectName: "setPicker"
            Accessible.name: qsTr("Piece set")
            Accessible.description: window.setNames[backend.pieceSet]
            implicitHeight: 38
            leftPadding: 10
            rightPadding: 10
            onClicked: setMenu.visible ? setMenu.close() : setMenu.open()
            background: Rectangle {
              radius: theme.radius
              color: setMenu.visible ? Qt.alpha(theme.foreground,.07) : setPicker.hovered ? Qt.alpha(theme.foreground,.05) : "transparent"
            }
            contentItem: RowLayout {
              spacing: 8
              Text { text: window.setNames[backend.pieceSet]; color: setPicker.hovered || setMenu.visible ? theme.foreground : window.muted; font.pixelSize: 12 }
              Text { text: "▾"; color: window.muted; font.pixelSize: 11; rotation: setMenu.visible ? 180 : 0; Behavior on rotation { enabled: !backend.reducedMotion; NumberAnimation { duration: 140 } } }
            }
            Popup {
              id: setMenu
              objectName: "setMenu"
              y: setPicker.height + 6
              x: setPicker.mirrored ? setPicker.width - width : 0
              width: 268
              padding: 6
              focus: true
              // Modal without the dim, so the press that dismisses the menu never lands on the board and moves a piece.
              modal: true
              dim: false
              closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
              onOpened: { setList.currentIndex = backend.pieceSet; setList.forceActiveFocus() }
              background: Rectangle { radius: theme.radius; color: theme.background; border.color: window.line }
              contentItem: ListView {
                id: setList
                implicitHeight: contentHeight
                interactive: false
                spacing: 2
                model: 4
                keyNavigationEnabled: true
                highlightFollowsCurrentItem: false
                Keys.onReturnPressed: { backend.pieceSet = currentIndex; setMenu.close() }
                Keys.onEnterPressed: { backend.pieceSet = currentIndex; setMenu.close() }
                Keys.onSpacePressed: { backend.pieceSet = currentIndex; setMenu.close() }
                delegate: ItemDelegate {
                  id: setButton
                  required property int index
                  width: ListView.view.width
                  height: 54
                  objectName: "set-" + index
                  Accessible.name: window.setNames[index]
                  onClicked: { backend.pieceSet = index; setMenu.close() }
                  background: Rectangle {
                    radius: theme.radius
                    color: backend.pieceSet === setButton.index ? Qt.alpha(window.setColors[setButton.index],.1) : setButton.hovered || setButton.ListView.isCurrentItem && setList.activeFocus ? Qt.alpha(theme.foreground,.05) : "transparent"
                  }
                  contentItem: RowLayout {
                    spacing: 12
                    Text { text: ["◎","♞","❧","♛"][setButton.index]; color: window.setColors[setButton.index]; font.pixelSize: 24; horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: 28; Layout.leftMargin: 2 }
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 3
                      Text { text: window.setNames[setButton.index]; color: theme.foreground; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                      Text { text: window.setDescriptions[setButton.index]; color: window.muted; font.pixelSize: 10; Layout.fillWidth: true }
                    }
                    Text { text: (setButton.index + 1).toLocaleString(Qt.locale(),'f',0); color: window.muted; font.pixelSize: 10; visible: backend.pieceSet !== setButton.index }
                    Text { text: "✓"; color: window.setColors[setButton.index]; visible: backend.pieceSet === setButton.index; Layout.rightMargin: 4 }
                  }
                }
              }
            }
          }
          Item { Layout.fillWidth: true }
          RowLayout {
            spacing: 4
            HeaderButton { objectName: "newGameButton"; text: qsTr("+  New game"); lit: true; tint: window.setColors[backend.pieceSet]; onClicked: newGameDialog.open() }
            HeaderButton { text: qsTr("Settings"); onClicked: settingsDialog.open() }
            HeaderButton {
              id: sidebarButton
              objectName: "sidebarButton"
              implicitWidth: 34
              Accessible.name: backend.sidebar ? qsTr("Hide sidebar") : qsTr("Show sidebar")
              ToolTip.visible: hovered
              ToolTip.delay: 600
              ToolTip.text: Accessible.name + "  ·  B"
              onClicked: backend.sidebar = !backend.sidebar
              // A small panel glyph whose side column fills in while the sidebar is showing.
              contentItem: Item {
                Rectangle {
                  id: panelFrame
                  anchors.centerIn: parent
                  width: 16; height: 13; radius: 2
                  color: "transparent"
                  border.width: 1.5
                  border.color: sidebarButton.hovered || backend.sidebar ? theme.foreground : Qt.alpha(theme.foreground,.72)
                  Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right; margins: 1.5 }
                    width: 5
                    color: panelFrame.border.color
                    opacity: backend.sidebar ? 1 : 0
                    Behavior on opacity { enabled: !backend.reducedMotion; NumberAnimation { duration: 140 } }
                  }
                }
              }
            }
            HeaderButton { text: "?"; implicitWidth: 34; font.pixelSize: 14; Accessible.name: qsTr("Keyboard shortcuts"); onClicked: helpDialog.open() }
          }
        }
      }
      Rectangle { Layout.fillWidth: true; height: 1; color: window.line; visible: window.chrome }
      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0
        BoardView { id: board; objectName: "board"; Layout.fillWidth: true; Layout.fillHeight: true }
        Rectangle { Layout.fillHeight: true; width: 1; color: window.line; visible: backend.sidebar && window.chrome }
        Rectangle {
          objectName: "sidebar"
          visible: backend.sidebar && window.chrome
          Layout.preferredWidth: window.width < 1100 ? 264 : 298
          Layout.fillHeight: true
          color: Qt.alpha(theme.foreground,.018)
          ColumnLayout {
            anchors { fill: parent; margins: 22 }
            spacing: 18
            RowLayout {
              Layout.fillWidth: true
              Text { text: backend.agent ? qsTr("VS AGENT") : backend.computer ? qsTr("VS COMPUTER") : qsTr("TWO PLAYERS"); font.pixelSize: 10; font.letterSpacing: Qt.application.layoutDirection === Qt.RightToLeft ? 0 : 2; color: window.muted; Layout.fillWidth: true }
              Text { text: "●"; color: window.setColors[backend.pieceSet]; font.pixelSize: 9 }
            }
            Text { text: backend.agent ? backend.agentName : backend.computer ? window.difficultyNames[backend.difficulty] : qsTr("One board. Two minds."); color: theme.foreground; font.family: "serif"; font.pixelSize: 23; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Repeater {
              model: [false,true]
              Rectangle {
                required property bool modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: backend.whiteTurn === modelData && !backend.finished ? Qt.alpha(theme.accent,.08) : "transparent"
                radius: theme.radius
                border.color: backend.whiteTurn === modelData && !backend.finished ? Qt.alpha(theme.accent,.45) : window.line
                RowLayout {
                  anchors { fill: parent; margins: 12 }
                  spacing: 12
                  Text { text: modelData ? "♙" : "♟"; font.pixelSize: 29; color: theme.foreground }
                  ColumnLayout {
                    spacing: 3
                    Text { text: backend.computer ? (backend.humanWhite === modelData ? qsTr("You") : backend.agent ? backend.agentName : qsTr("Computer")) : (modelData ? qsTr("Player 1") : qsTr("Player 2")); color: theme.foreground; font.pixelSize: 14 }
                    Text { text: modelData ? qsTr("White") : qsTr("Black"); color: window.muted; font.pixelSize: 11 }
                  }
                  Item { Layout.fillWidth: true }
                  Text { text: backend.whiteTurn === modelData && !backend.finished ? "●" : ""; color: theme.accent; font.pixelSize: 10 }
                }
              }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: window.line }
            Text { objectName: "status"; text: window.statusText(); color: backend.checked ? theme.colors.red : theme.foreground; font.pixelSize: 17; font.family: "serif"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Text { text: qsTr("MOVE HISTORY"); color: window.muted; font.pixelSize: 10; font.letterSpacing: Qt.application.layoutDirection === Qt.RightToLeft ? 0 : 1.8 }
            ListView {
              id: history
              objectName: "history"
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              model: Math.ceil(backend.moves.length / 2)
              spacing: 3
              ScrollBar.vertical: ScrollBar { }
              onCountChanged: Qt.callLater(positionViewAtEnd)
              delegate: Rectangle {
                required property int index
                width: history.width
                height: 32
                color: index % 2 === 0 ? Qt.alpha(theme.foreground,.035) : "transparent"
                RowLayout {
                  anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                  Text { text: { translator.language; return (index + 1).toLocaleString(Qt.locale(),'f',0) + "." } color: window.muted; Layout.preferredWidth: 30; font.pixelSize: 12 }
                  Text { text: backend.moves[index * 2] || ""; color: theme.foreground; Layout.fillWidth: true; font.pixelSize: 13 }
                  Text { text: backend.moves[index * 2 + 1] || "·"; color: theme.foreground; Layout.preferredWidth: 66; font.pixelSize: 13 }
                }
              }
              Text { anchors { top: parent.top; left: parent.left } visible: history.count === 0; text: qsTr("Every great game starts\nwith a single move."); color: window.muted; font.pixelSize: 12; lineHeight: 1.6 }
            }
            FlatButton { objectName: "undoButton"; text: qsTr("↶  Undo move"); Layout.fillWidth: true; enabled: backend.canUndo; onClicked: backend.undo() }
            Text { text: backend.saveHealthy ? qsTr("Saved automatically · No time limit") : qsTr("Game is not being saved"); font.pixelSize: 10; color: window.muted; Layout.alignment: Qt.AlignHCenter }
          }
        }
      }
    }
    Rectangle {
      visible: backend.error.length > 0
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
      height: errorRow.implicitHeight + 28
      color: theme.background
      border.color: theme.colors.red
      radius: theme.radius
      RowLayout {
        id: errorRow
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 }
        Text { text: backend.error; color: theme.foreground; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        // A stalled agent keeps its message up until the player asks again, undoes, or starts over.
        FlatButton { objectName: "askAgain"; text: qsTr("Ask again"); visible: backend.agentStalled; onClicked: backend.askAgentAgain() }
        FlatButton { text: qsTr("Dismiss"); visible: !backend.agentStalled; onClicked: backend.dismissError() }
      }
    }
  }
  Dialog {
    id: newGameDialog
    objectName: "newGameDialog"
    anchors.centerIn: parent
    width: 420
    modal: true
    focus: true
    title: qsTr("A new match")
    footer: DialogButtonBox {
      LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
      LayoutMirroring.childrenInherit: true
      Button { text: qsTr("Start game"); DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole; Material.roundedScale: theme.radius }
      Button { text: qsTr("Cancel"); DialogButtonBox.buttonRole: DialogButtonBox.RejectRole; Material.roundedScale: theme.radius }
      onAccepted: newGameDialog.accept()
      onRejected: newGameDialog.reject()
    }
    Material.roundedScale: theme.radius
    onOpened: {
      backend.refreshAgent()
      mode.currentIndex = backend.agent && backend.agentAvailable ? 2 : backend.computer ? 0 : 1
      level.currentIndex = backend.difficulty
      side.currentIndex = backend.humanWhite ? 0 : 1
      mode.forceActiveFocus()
    }
    onAccepted: { backend.newGame(mode.currentIndex !== 1,level.currentIndex,side.currentIndex === 0,mode.currentIndex === 2); board.resetCamera() }
    contentItem: ColumnLayout {
      LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
      LayoutMirroring.childrenInherit: true
      spacing: 16
      Label { text: backend.canUndo ? qsTr("Starting a new match replaces the saved game.") : qsTr("Choose your opponent and settle in."); wrapMode: Text.WordWrap; Layout.fillWidth: true }
      ComboBox { leftPadding: mirrored ? 40 : 16; rightPadding: mirrored ? 16 : 40; id: mode; objectName: "mode"; Layout.fillWidth: true; // The default Omarchy agent joins the list when it can answer on its own; it comes last so the others keep their places.
        model: backend.agentAvailable ? [qsTr("Play against the computer"),qsTr("Two players · same device"),qsTr("Play against %1").arg(backend.agentName)]
                                      : [qsTr("Play against the computer"),qsTr("Two players · same device")]; Material.roundedScale: theme.radius }
      ComboBox { leftPadding: mirrored ? 40 : 16; rightPadding: mirrored ? 16 : 40; id: level; Layout.fillWidth: true; model: window.difficultyNames; visible: mode.currentIndex === 0; Material.roundedScale: theme.radius }
      ComboBox { leftPadding: mirrored ? 40 : 16; rightPadding: mirrored ? 16 : 40; id: side; Layout.fillWidth: true; model: [qsTr("Play as White"),qsTr("Play as Black")]; visible: mode.currentIndex !== 1; Material.roundedScale: theme.radius }
    }
  }
  Dialog {
    id: settingsDialog
    anchors.centerIn: parent
    width: 400
    modal: true
    focus: true
    title: qsTr("Make yourself comfortable")
    footer: DialogButtonBox {
      LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
      LayoutMirroring.childrenInherit: true
      Button { text: qsTr("Close"); DialogButtonBox.buttonRole: DialogButtonBox.RejectRole; Material.roundedScale: theme.radius }
      onRejected: settingsDialog.close()
    }
    Material.roundedScale: theme.radius
    contentItem: ColumnLayout {
      LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
      LayoutMirroring.childrenInherit: true
      CheckBox { text: qsTr("Reduced motion"); checked: backend.reducedMotion; onToggled: backend.reducedMotion = checked }
      CheckBox { text: qsTr("Turn the board for each player"); checked: backend.autoRotate; onToggled: backend.autoRotate = checked }
      Label { text: qsTr("Automatic rotation applies to two-player games."); color: window.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
      FlatButton { text: qsTr("Reset camera"); Layout.fillWidth: true; onClicked: board.resetCamera() }
    }
  }
  Dialog {
    id: helpDialog
    objectName: "help"
    anchors.centerIn: parent
    width: 430
    modal: true
    focus: true
    title: qsTr("At your fingertips")
    footer: DialogButtonBox {
      LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
      LayoutMirroring.childrenInherit: true
      Button { text: qsTr("Close"); DialogButtonBox.buttonRole: DialogButtonBox.RejectRole; Material.roundedScale: theme.radius }
      onRejected: helpDialog.close()
    }
    Material.roundedScale: theme.radius
    contentItem: Label {
      LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
      text: qsTr("Click a piece, then a highlighted square.\n\nArrow keys  ·  Navigate the board\nSpace / Enter  ·  Select or move\nEscape  ·  Cancel selection\nCtrl+Z  ·  Undo\nN  ·  New game\nF  ·  Flip board\nR  ·  Reset camera\n1–4  ·  Piece set\nB  ·  Show or hide the sidebar\nTab  ·  Show or hide the interface\nS  ·  Settings\n?  ·  Keyboard shortcuts\nQ  ·  Quit (your game is saved)\n\nRight-drag to orbit. Scroll to zoom.")
      wrapMode: Text.WordWrap
      lineHeight: 1.4
    }
  }
  Dialog {
    id: promotionDialog
    objectName: "promotionDialog"
    anchors.centerIn: parent
    width: 420
    modal: true
    focus: true
    title: qsTr("Choose your promotion")
    closePolicy: Popup.CloseOnEscape
    Material.roundedScale: theme.radius
    onRejected: backend.cancelSelection()
    contentItem: RowLayout {
      LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
      LayoutMirroring.childrenInherit: true
      Repeater {
        model: [5,4,3,2]
        FlatButton {
          required property int modelData
          objectName: "promotion-" + modelData
          text: ["","","♘","♗","♖","♕"][modelData]
          font.pixelSize: 32
          Layout.fillWidth: true
          Accessible.name: modelData === 5 ? qsTr("Queen") : modelData === 4 ? qsTr("Rook") : modelData === 3 ? qsTr("Bishop") : qsTr("Knight")
          onClicked: { backend.promote(modelData); promotionDialog.close() }
        }
      }
    }
  }
  Connections {
    target: backend
    function onChanged() {
      if (backend.promotionPending && !promotionDialog.opened) promotionDialog.open()
      else if (!backend.promotionPending && promotionDialog.opened) promotionDialog.close()
    }
  }
  Shortcut { sequence: "?"; enabled: !window.modalOpen; onActivated: helpDialog.open() }
  Shortcut { sequence: "S"; enabled: !window.modalOpen; onActivated: settingsDialog.open() }
  Shortcut { sequence: "Q"; enabled: !window.modalOpen; onActivated: window.close() }
  Shortcut { sequence: "N"; enabled: !window.modalOpen; onActivated: newGameDialog.open() }
  Shortcut { sequences: [StandardKey.Undo]; enabled: !window.modalOpen; onActivated: backend.undo() }
  Shortcut { sequence: "F"; enabled: !window.modalOpen; onActivated: board.manualAzimuth += 180 }
  Shortcut { sequence: "1"; enabled: !window.modalOpen; onActivated: backend.pieceSet = 0 }
  Shortcut { sequence: "2"; enabled: !window.modalOpen; onActivated: backend.pieceSet = 1 }
  Shortcut { sequence: "3"; enabled: !window.modalOpen; onActivated: backend.pieceSet = 2 }
  Shortcut { sequence: "4"; enabled: !window.modalOpen; onActivated: backend.pieceSet = 3 }
  Shortcut { sequence: "B"; enabled: !window.modalOpen; onActivated: backend.sidebar = !backend.sidebar }
  Shortcut { sequence: "Tab"; enabled: !window.modalOpen; onActivated: window.chrome = !window.chrome }
  Shortcut { sequence: "R"; enabled: !window.modalOpen; onActivated: board.resetCamera() }
  Shortcut { sequence: "Escape"; enabled: !window.modalOpen; onActivated: backend.cancelSelection() }
  Shortcut { sequences: ["Space","Return"]; enabled: !window.modalOpen; onActivated: board.keyboardSelect() }
  Shortcut { sequence: "Left"; enabled: !window.modalOpen; onActivated: board.navigate(-1,0) }
  Shortcut { sequence: "Right"; enabled: !window.modalOpen; onActivated: board.navigate(1,0) }
  Shortcut { sequence: "Up"; enabled: !window.modalOpen; onActivated: board.navigate(0,1) }
  Shortcut { sequence: "Down"; enabled: !window.modalOpen; onActivated: board.navigate(0,-1) }
}
