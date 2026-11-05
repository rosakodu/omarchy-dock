import QtQuick
import QtQuick.Shapes
import qs.Commons
import "/usr/share/omarchy/shell/Commons/BorderGeometry.js" as Geometry

// Visual border renderer for Omarchy Dock supporting multi-stop linear gradients
// and continuous angle rotation matching Hyprland's `borderangle` animation loop.
Item {
    id: root

    property var borderSpec: Border.none()
    property real radius: 0
    property bool animated: true
    property real animationDuration: 6000

    readonly property var _widths: borderSpec && borderSpec.widths ? borderSpec.widths : Geometry.parseWidthSpec(0, 0)
    readonly property bool hasBorder: Geometry.maxWidth(_widths) > 0
    readonly property var _gradient: borderSpec && borderSpec.gradient ? borderSpec.gradient : ({ colors: [], angle: 0, enabled: false })
    readonly property var _colors: _gradient.enabled ? _gradient.colors : [Border.color(borderSpec), Border.color(borderSpec)]

    property real currentAngle: _gradient.angle || 0

    NumberAnimation {
        id: angleAnim
        target: root
        property: "currentAngle"
        from: (_gradient.angle || 0)
        to: (_gradient.angle || 0) + 360
        duration: Math.max(1000, root.animationDuration)
        loops: Animation.Infinite
        running: root.animated && root._gradient.enabled && root.visible && root.width > 0 && root.height > 0
    }

    readonly property var _endpoints: Geometry.gradientEndpoints(width, height, currentAngle)
    readonly property string _path: Geometry.ringPath(width, height, radius, _widths)

    visible: hasBorder && width > 0 && height > 0
    anchors.fill: parent
    enabled: false
    z: 100000

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillRule: ShapePath.WindingFill
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: root._endpoints.x1
                y1: root._endpoints.y1
                x2: root._endpoints.x2
                y2: root._endpoints.y2

                GradientStop { position: Geometry.stopPosition(root._colors, 0); color: Geometry.stopColor(root._colors, 0) }
                GradientStop { position: Geometry.stopPosition(root._colors, 1); color: Geometry.stopColor(root._colors, 1) }
                GradientStop { position: Geometry.stopPosition(root._colors, 2); color: Geometry.stopColor(root._colors, 2) }
                GradientStop { position: Geometry.stopPosition(root._colors, 3); color: Geometry.stopColor(root._colors, 3) }
                GradientStop { position: Geometry.stopPosition(root._colors, 4); color: Geometry.stopColor(root._colors, 4) }
                GradientStop { position: Geometry.stopPosition(root._colors, 5); color: Geometry.stopColor(root._colors, 5) }
                GradientStop { position: Geometry.stopPosition(root._colors, 6); color: Geometry.stopColor(root._colors, 6) }
                GradientStop { position: Geometry.stopPosition(root._colors, 7); color: Geometry.stopColor(root._colors, 7) }
                GradientStop { position: Geometry.stopPosition(root._colors, 8); color: Geometry.stopColor(root._colors, 8) }
                GradientStop { position: Geometry.stopPosition(root._colors, 9); color: Geometry.stopColor(root._colors, 9) }
            }

            PathSvg { path: root._path }
        }
    }
}
