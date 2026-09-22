import Foundation
import CoreGraphics

public enum BarGeometry {
    /// AppKit uses a bottom-left origin. The menu inset is independent of Dock placement.
    public static func frame(
        screen: CGRect,
        menuBarInset: Double,
        safeAreaTop: Double,
        thickness: Double,
        placement: AppearanceSettings.Placement,
        scale: Double
    ) -> CGRect {
        let scale = max(1, scale)
        // A half-point hairline is one pixel at 2x. Keep at least one pixel at 1x.
        let height = max(1, (max(AppearanceSettings.thicknessRange.lowerBound, thickness) * scale).rounded()) / scale
        let y: Double
        switch placement {
        case .belowMenuBar: y = screen.maxY - max(menuBarInset, safeAreaTop) - height
        case .top: y = screen.maxY - safeAreaTop - height
        case .bottom: y = screen.minY
        }
        return CGRect(x: screen.minX, y: (y * scale).rounded() / scale, width: screen.width, height: height)
    }
}
