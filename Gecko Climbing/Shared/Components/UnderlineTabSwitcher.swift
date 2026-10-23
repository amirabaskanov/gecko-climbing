import SwiftUI

/// Two-or-more tab switcher with the feed's soft underline indicator.
/// Generic so lists (followers / following) and other paired views share
/// the same gesture and motion as the Following / Discover rails.
struct UnderlineTabSwitcher<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item

    @Namespace private var underline

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    tab(item)
                }
            }
            .padding(.top, 6)

            Divider().overlay(Color.geckoDivider)
        }
        .background(Color.geckoBackground)
    }

    private func tab(_ item: Item) -> some View {
        let isSelected = selection == item
        return Button {
            guard !isSelected else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                selection = item
            }
        } label: {
            VStack(spacing: 8) {
                Text(title(item))
                    .font(.system(size: 16, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.primary : Color.geckoSecondaryText)
                    .padding(.horizontal, 2)

                ZStack {
                    Color.clear.frame(height: 2)
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Color.geckoMint)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: underline)
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
