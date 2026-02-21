import SwiftUI

// Standalone add climb view - thin wrapper around QuickAddClimbSheet
struct AddClimbView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, ClimbOutcome, Int) -> Void

    var body: some View {
        QuickAddClimbSheet { grade, outcome, attempts in
            onAdd(grade, outcome, attempts)
        }
    }
}
