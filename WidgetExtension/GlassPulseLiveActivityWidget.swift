import ActivityKit
import SwiftUI
import WidgetKit

@main
struct GlassPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlassPulseLiveActivityWidget()
    }
}

struct GlassPulseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlassPulseActivityAttributes.self) { context in
            lockScreenContent(context)
                .activityBackgroundTint(Color.black.opacity(0.88))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.modeTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    scoreLabel(context.state.score)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        timeLabel(context.state)
                        Spacer()
                        Text("Streak \(context.state.dailyStreak)")
                        Text("Local best \(context.state.localDailyBest)")
                    }
                    .font(.caption2)
                }
            } compactLeading: {
                Image(systemName: context.attributes.isDaily ? "calendar" : "timer")
                    .accessibilityLabel(context.attributes.modeTitle)
            } compactTrailing: {
                Text("\(context.state.score)")
                    .font(.caption2.monospacedDigit())
                    .accessibilityLabel("Điểm \(context.state.score)")
            } minimal: {
                Text("\(context.state.score)")
                    .font(.caption2.monospacedDigit())
                    .accessibilityLabel("Glass Pulse, điểm \(context.state.score)")
            }
        }
    }

    private func lockScreenContent(
        _ context: ActivityViewContext<GlassPulseActivityAttributes>
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.modeTitle)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    scoreLabel(context.state.score)
                    timeLabel(context.state)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text("Streak \(context.state.dailyStreak)")
                Text("Local best \(context.state.localDailyBest)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary(context))
    }

    private func scoreLabel(_ score: Int) -> some View {
        Label("\(score)", systemImage: "sparkles")
            .font(.subheadline.weight(.semibold).monospacedDigit())
    }

    @ViewBuilder
    private func timeLabel(_ state: GlassPulseActivityAttributes.ContentState) -> some View {
        if state.isPaused, let remaining = state.remainingSeconds {
            Label("\(remaining)s", systemImage: "pause.fill")
                .monospacedDigit()
        } else if let endDate = state.timerEndDate, endDate > .now {
            Text(timerInterval: Date.now...endDate, countsDown: true)
                .monospacedDigit()
        } else if let remaining = state.remainingSeconds {
            Text("\(remaining)s")
                .monospacedDigit()
        }
    }

    private func accessibilitySummary(
        _ context: ActivityViewContext<GlassPulseActivityAttributes>
    ) -> String {
        let remaining = context.state.remainingSeconds.map { ", còn \($0) giây" } ?? ""
        return "\(context.attributes.modeTitle), điểm \(context.state.score)\(remaining), streak \(context.state.dailyStreak), local best \(context.state.localDailyBest)"
    }
}
