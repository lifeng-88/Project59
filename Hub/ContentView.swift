import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var faceController: AppFaceController
    @Environment(\.hubLanguage) private var language

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch store.selectedTab {
                case .today:
                    TodayView()
                case .calendar:
                    CalendarView()
                case .insights:
                    InsightsView()
                case .settings:
                    SettingsView()
                }
            }
            .padding(.bottom, store.hubTabBarHidden ? 0 : 88)

            if !store.hubTabBarHidden {
                HubBottomBar(selection: $store.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if store.selectedTab.showsFAB, !store.hubTabBarHidden {
                HubFAB {
                    if store.selectedTab == .calendar {
                        store.prepareQuickAdd(for: store.calendarSelectedDate)
                    } else {
                        store.prepareQuickAdd(for: Date())
                    }
                    store.showQuickAdd = true
                }
                .padding(.trailing, LuminaSpacing.marginPage)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if store.selectedTab == .today, showsHubFaceSwitchFAB, !store.hubTabBarHidden {
                HubFaceSwitchFAB(style: .lumina)
                    .padding(.leading, LuminaSpacing.marginPage)
                    .padding(.bottom, 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.hubTabBarHidden)
        .onChange(of: store.selectedTab) { _, tab in
            if tab != .settings {
                store.hubTabBarHidden = false
            }
        }
        .preferredColorScheme(store.colorScheme)
        .environment(\.hubLanguage, store.appLanguage)
        .environment(\.locale, store.appLanguage.locale)
        .luminaRootTheme()
        .sheet(isPresented: $store.showQuickAdd) {
            QuickAddSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(LuminaRadius.sheetTop)
                .presentationBackground(LuminaColor.surfaceContainerLowest)
        }
        .sheet(item: $store.taskToEdit) { task in
            EditTaskSheet(task: task)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showSideMenu) {
            SideMenuView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(LuminaColor.surface)
        }
        .sheet(isPresented: $store.showFocusTimer) {
            FocusTimerView()
        }
        .sheet(item: $store.exportFile) { file in
            ShareSheet(items: [file.url])
        }
        .alert(L10n.tr(.commonTip, language: language), isPresented: alertBinding) {
            Button(L10n.tr(.commonOK, language: language), role: .cancel) {
                store.alertMessage = nil
            }
        } message: {
            Text(store.alertMessage ?? "")
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { store.alertMessage != nil },
            set: { if !$0 { store.alertMessage = nil } }
        )
    }

    private var showsHubFaceSwitchFAB: Bool {
        guard AppFaceController.showsManualFaceSwitchInUI else { return false }
        /// A 面首页不展示进入 Rahmi（B 面）的 Debug 入口；仅在 B 面保留返回 Hub 的按钮。
        return faceController.isShowingRahmi
    }
}

#Preview {
    ContentView()
        .environmentObject(TaskStore())
        .environmentObject(AppFaceController())
}
