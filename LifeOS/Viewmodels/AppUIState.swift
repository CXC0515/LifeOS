import Foundation
import SwiftUI
import Combine

@MainActor
final class AppUIState: ObservableObject {
    @Published var isTabBarHidden: Bool = false
}
