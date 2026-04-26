import Foundation
import SwiftUI

@Observable
final class TabRouter<Route: Hashable> {
    var path = NavigationPath()

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    /// Replace the entire stack with the given routes.
    func setPath(_ routes: [Route]) {
        var newPath = NavigationPath()
        for route in routes { newPath.append(route) }
        path = newPath
    }
}
