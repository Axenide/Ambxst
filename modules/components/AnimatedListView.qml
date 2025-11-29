pragma ComponentBehavior: Bound

 import QtQuick
 import QtQuick.Layouts
 import qs.config

 ListView {
     id: root

     // Public properties for customization
     property int itemHeight: 48
     property Component itemDelegate
     property var highlightVariant: "primary"
     property bool highlightVisible: true

     clip: true
     cacheBuffer: 200
     reuseItems: true
    
     // Animación para items que se desplazan a nueva posición
      displaced: Transition {
          ParallelAnimation {
              NumberAnimation {
                  property: "y"
                  duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                  easing.type: Easing.OutCubic
              }
              NumberAnimation {
                  property: "opacity"
                  to: 1
                  duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                  easing.type: Easing.OutCubic
              }
          }
      }
    
    // Animación para items que aparecen
     add: Transition {
         ParallelAnimation {
             NumberAnimation {
                 property: "opacity"
                 from: 0
                 to: 1
                 duration: Config.animDuration > 0 ? Config.animDuration / 4 : 0
                 easing.type: Easing.OutCubic
             }
             NumberAnimation {
                 property: "y"
                 duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                 easing.type: Easing.OutCubic
             }
         }
     }
    
    // Animación para items que desaparecen
     remove: Transition {
         ParallelAnimation {
             NumberAnimation {
                 property: "opacity"
                 to: 0
                 duration: Config.animDuration > 0 ? Config.animDuration / 4 : 0
                 easing.type: Easing.OutCubic
             }
             NumberAnimation {
                 property: "height"
                 to: 0
                 duration: Config.animDuration > 0 ? Config.animDuration / 4 : 0
                 easing.type: Easing.OutCubic
             }
         }
     }
    
    // Custom highlight with independent position calculation
    highlight: Item {
        width: root.width
        height: root.itemHeight
        
        // Calculate Y position based on index, not item position
        y: root.currentIndex * root.itemHeight
        
        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }
        
        Loader {
            anchors.fill: parent
            sourceComponent: root.itemDelegate ? null : defaultHighlight
            active: !root.itemDelegate
        }
        
        Component {
            id: defaultHighlight
            Rectangle {
                color: "transparent"
            }
        }
    }
    
    highlightFollowsCurrentItem: false
}
