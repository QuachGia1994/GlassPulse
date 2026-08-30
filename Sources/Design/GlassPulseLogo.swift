import SwiftUI

struct GlassPulseLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            glassSurface
            orbitRing
            pulse
            ball
        }
        .frame(width: size, height: size)
        .drawingGroup()
        .accessibilityHidden(true)
    }

    private var glassSurface: some View {
        Circle()
            .fill(Color.black.opacity(0.26))
    }

    private var orbitRing: some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [.cyan, .purple, .orange, .cyan],
                    center: .center
                ),
                lineWidth: size * 0.045
            )
            .shadow(color: .cyan.opacity(0.42), radius: size * 0.08)
    }

    private var pulse: some View {
        PulseWave()
            .stroke(
                LinearGradient(
                    colors: [.cyan, .white, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(
                    lineWidth: size * 0.045,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .padding(size * 0.19)
    }

    private var ball: some View {
        Circle()
            .fill(.orange)
            .frame(width: size * 0.15, height: size * 0.15)
            .overlay {
                Circle()
                    .fill(.white.opacity(0.72))
                    .padding(size * 0.05)
            }
            .shadow(color: .orange.opacity(0.72), radius: size * 0.08)
            .offset(x: -size * 0.285, y: size * 0.285)
    }
}

private struct PulseWave: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: 0.12, y: 0.52),
            CGPoint(x: 0.34, y: 0.52),
            CGPoint(x: 0.42, y: 0.30),
            CGPoint(x: 0.51, y: 0.72),
            CGPoint(x: 0.59, y: 0.40),
            CGPoint(x: 0.66, y: 0.52),
            CGPoint(x: 0.88, y: 0.52)
        ]
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: scaled(first, in: rect))
        for point in points.dropFirst() {
            path.addLine(to: scaled(point, in: rect))
        }
        return path
    }

    private func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }
}
