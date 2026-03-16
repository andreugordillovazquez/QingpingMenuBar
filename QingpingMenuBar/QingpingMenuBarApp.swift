import SwiftUI

@main
struct QingpingMenuBarApp: App {
    @State private var viewModel: AirQualityViewModel

    init() {
        CredentialsStore.migrateIfNeeded()
        _viewModel = State(initialValue: AirQualityViewModel())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
