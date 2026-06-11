import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var faceController: AppFaceController

    var body: some View {
        ZStack(alignment: .bottom) {
            LuminaColor.surface.ignoresSafeArea()

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
        .alert("提示", isPresented: alertBinding) {
            Button("好的", role: .cancel) {
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
        AppFaceController.showsManualFaceSwitchInUI
    }
}

#Preview {
    ContentView()
        .environmentObject(TaskStore())
        .environmentObject(AppFaceController())
}
