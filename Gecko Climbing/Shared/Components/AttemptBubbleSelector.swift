import SwiftUI

struct AttemptBubbleSelector: View {
    var accentColor: Color = .geckoGreen
    let onSelect: (Int) -> Void

    @State private var selectedNumber: Int = 2
    @State private var showCustomField = false
    @State private var customText = ""
    @FocusState private var customFieldFocused: Bool

    private let bubbleNumbers = [2, 3, 4, 5, 6]
    private let bubbleSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
                Text("How many tries?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            if showCustomField {
                customInputRow
            } else {
                bubbleRow
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var bubbleRow: some View {
        HStack(spacing: 10) {
            ForEach(bubbleNumbers, id: \.self) { number in
                bubbleButton(number: number)
            }

            // 7+ button
            Button {
                withAnimation(.geckoSnappy) {
                    showCustomField = true
                    customText = "7"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    customFieldFocused = true
                }
            } label: {
                Text("7+")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .frame(width: bubbleSize, height: bubbleSize)
                    .background(
                        Circle()
                            .fill(accentColor.opacity(0.1))
                    )
                    .overlay(
                        Circle()
                            .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .sensoryFeedback(.selection, trigger: selectedNumber)
    }

    private func bubbleButton(number: Int) -> some View {
        let isDefault = number == 2

        return Button {
            selectedNumber = number
            onSelect(number)
        } label: {
            Text("\(number)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(isDefault ? .white : accentColor)
                .frame(width: bubbleSize, height: bubbleSize)
                .background(
                    Circle()
                        .fill(isDefault ? accentColor : accentColor.opacity(0.1))
                )
                .overlay(
                    Circle()
                        .stroke(isDefault ? Color.clear : accentColor.opacity(0.3), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .bouncePress()
    }

    private var customInputRow: some View {
        HStack(spacing: 12) {
            TextField("", text: $customText)
                .keyboardType(.numberPad)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(width: 60, height: 44)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentColor, lineWidth: 2)
                )
                .focused($customFieldFocused)

            Button {
                let count = Int(customText) ?? 7
                onSelect(max(count, 2))
            } label: {
                Text("Log")
                    .font(.callout.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 44)
                    .background(accentColor, in: Capsule())
            }
            .bouncePress()

            Button {
                withAnimation(.geckoSnappy) {
                    showCustomField = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.surfaceBackground, in: Circle())
            }
        }
    }
}
