import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.hubLanguage) private var language

    private var weekdaySymbols: [String] {
        L10n.weekdaySymbols(language: language)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HubTopBar(title: L10n.tr(.insightsTitle, language: language), showSearch: false, onMenu: { store.showSideMenu = true })

                VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
                    productivityHero
                    statsGrid
                    focusDistribution
                    insightCard
                }
                .padding(.horizontal, LuminaSpacing.marginPage)
                .padding(.top, LuminaSpacing.stackMD)
                .padding(.bottom, LuminaSpacing.stackXL)
            }
        }
        .background(LuminaColor.surface)
        .refreshable {
            await store.refreshFromCloudAndNotifications()
        }
    }

    private var productivityHero: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr(.insightsProductivityScore, language: language))
                        .font(.luminaLabelSM)
                        .tracking(0.8)
                        .foregroundStyle(LuminaColor.onSurfaceVariant)
                    Text("\(store.productivityScore)%")
                        .font(.luminaDisplay)
                        .foregroundStyle(LuminaColor.primary)
                }
                Spacer()
                if store.productivityScore > 0 {
                    Text(String(format: L10n.tr(.insightsBasedOnTasks, language: language), store.completedCount, store.tasks.count))
                        .font(.luminaLabelSM)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(LuminaColor.primary.opacity(0.1))
                        .foregroundStyle(LuminaColor.primary)
                        .clipShape(Capsule())
                }
            }

            WeeklyChartView(values: store.weeklyChartNormalizedValues())
                .frame(height: 160)

            HStack {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.luminaLabelSM)
                        .foregroundStyle(LuminaColor.outline)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LuminaSpacing.stackMD) {
            statCard(
                icon: "checkmark.circle",
                title: L10n.tr(.insightsCompletedTasks, language: language),
                value: "\(store.completedCount)",
                trend: store.completedCount > 0 ? "+\(store.completedCount)" : nil
            )
            focusDurationCard
            streakCard
        }
    }

    private func statCard(icon: String, title: String, value: String, trend: String?, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(LuminaColor.primary)
            Text(title)
                .font(.luminaLabelSM)
                .foregroundStyle(LuminaColor.onSurfaceVariant)
            Text(value)
                .font(.luminaHeadlineLG)
            if let trend {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                    Text(trend)
                        .font(.luminaLabelSM)
                }
                .foregroundStyle(LuminaColor.primary)
            } else if let subtitle {
                Text(subtitle)
                    .font(.luminaLabelSM)
                    .foregroundStyle(LuminaColor.outline)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
    }

    private var focusDurationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 24))
                .foregroundStyle(LuminaColor.primary)
            Text(L10n.tr(.insightsFocusDuration, language: language))
                .font(.luminaLabelSM)
                .foregroundStyle(LuminaColor.onSurfaceVariant)
            Text(store.focusHoursFormatted)
                .font(.luminaHeadlineLG)
            Text(store.focusGoalSubtitle)
                .font(.luminaLabelSM)
                .foregroundStyle(LuminaColor.outline)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LuminaColor.surfaceContainer).frame(height: 6)
                    Capsule()
                        .fill(LuminaColor.primary)
                        .frame(width: geo.size.width * store.focusGoalProgress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
    }

    private var streakCard: some View {
        let progress = min(1, Double(store.focusStreakDays) / 16)
        return HStack {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(LuminaColor.primary)
                Text(L10n.tr(.insightsCurrentStreak, language: language))
                    .font(.luminaLabelSM)
                    .foregroundStyle(LuminaColor.onSurfaceVariant)
                Text(String(format: L10n.tr(.insightsStreakDaysUnit, language: language), store.focusStreakDays))
                    .font(.luminaHeadlineLG)
            }
            Spacer()
            ZStack {
                Circle().stroke(LuminaColor.surfaceContainer, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(LuminaColor.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.luminaLabelSM)
                    .foregroundStyle(LuminaColor.primary)
            }
            .frame(width: 64, height: 64)
        }
        .padding(20)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
        .gridCellColumns(2)
    }

    private var focusDistribution: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
            LuminaSectionLabel(title: L10n.tr(.insightsFocusDistribution, language: language))
            VStack(spacing: LuminaSpacing.stackMD) {
                ForEach(store.categoryDistribution(), id: \.0) { category, percent in
                    breakdownRow(label: category.displayName(language: language), percent: percent, color: categoryColor(category))
                }
            }
        }
        .padding(LuminaSpacing.insetMD)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
    }

    private var insightCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr(.insightsKeepGoing, language: language))
                    .font(.luminaHeadlineMobile)
                    .foregroundStyle(LuminaColor.onPrimaryContainer)
                Text(insightMessage)
                    .font(.luminaBodyMD)
                    .foregroundStyle(LuminaColor.onPrimaryContainer.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(LuminaColor.onPrimary.opacity(0.12))
                .rotationEffect(.degrees(12))
        }
        .background(LuminaColor.primaryContainer)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.lg))
        .luminaSoftShadow()
    }

    private var insightMessage: String {
        if store.focusStreakDays >= 7 {
            return String(format: L10n.tr(.insightsStreakMessage, language: language), store.focusStreakDays)
        }
        return L10n.tr(.insightsStartSmall, language: language)
    }

    private func breakdownRow(label: String, percent: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.luminaLabelMD)
                Spacer()
                Text("\(Int(percent * 100))%").font(.luminaLabelMD).foregroundStyle(LuminaColor.onSurfaceVariant)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LuminaColor.surfaceContainer).frame(height: 8)
                    Capsule().fill(color).frame(width: geo.size.width * percent, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(LuminaSpacing.insetMD)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
    }

    private func categoryColor(_ category: TaskCategory) -> Color {
        switch category {
        case .work: return LuminaColor.primary
        case .deepFocus: return LuminaColor.primaryContainer
        case .personal: return LuminaColor.secondary
        }
    }
}

struct WeeklyChartView: View {
    var values: [CGFloat] = Array(repeating: 0.3, count: 7)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let normalized = values.count == 7 ? values : Array(repeating: 0.2, count: 7)
            let points: [CGPoint] = normalized.enumerated().map { index, value in
                let x = w * CGFloat(index) / 6
                let y = h * (1 - value * 0.75) - h * 0.1
                return CGPoint(x: x, y: y)
            }

            ZStack {
                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for p in points.dropFirst() { path.addLine(to: p) }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [LuminaColor.primary.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))

                    Path { path in
                        path.move(to: points[0])
                        for p in points.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(LuminaColor.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(LuminaColor.primary)
                            .frame(width: 6, height: 6)
                            .position(point)
                    }
                }
            }
        }
    }
}
