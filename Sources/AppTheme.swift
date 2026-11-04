import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.91, green: 0.90, blue: 0.88)
    static let surface = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let inset = Color(red: 0.99, green: 0.985, blue: 0.975)
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let secondaryInk = Color(red: 0.38, green: 0.38, blue: 0.37)
    static let line = Color(red: 0.82, green: 0.81, blue: 0.78)
    static let blue = Color(red: 0.22, green: 0.34, blue: 0.98)
    static let blueSoft = Color(red: 0.84, green: 0.87, blue: 1.0)
    static let key = Color(red: 0.99, green: 0.985, blue: 0.975)
}

struct DotMatrixMark: View {
    var dotSize: CGFloat = 4
    var spacing: CGFloat = 3

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<3, id: \.self) { column in
                        Circle()
                            .fill((row == 1 && column == 1) ? AppTheme.blue : AppTheme.ink)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
