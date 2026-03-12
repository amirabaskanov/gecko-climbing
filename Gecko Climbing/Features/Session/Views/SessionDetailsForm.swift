import SwiftUI
import SwiftData

struct SessionDetailsForm: View {
    let climbCount: Int
    let autoMinutes: Int

    @Binding var gymName: String
    @Binding var date: Date
    @Binding var durationMinutes: Int
    @Binding var notes: String
    @Binding var caption: String

    let recentGyms: [String]
    let onSave: () -> Void

    @State private var showNotes = false
    @State private var showDatePicker = false
    @State private var showDurationPicker = false
    @State private var appeared = false
    @FocusState private var gymFieldFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Session Complete!")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("\(climbCount) climbs logged")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.geckoSpring.delay(0.1), value: appeared)

            // Gym name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Where did you climb?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.geckoGreen)
                        .font(.system(size: 20))
                    TextField("Gym name", text: $gymName)
                        .font(.body.weight(.medium))
                        .focused($gymFieldFocused)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(gymFieldFocused ? Color.geckoGreen : Color.geckoGreen.opacity(0.2), lineWidth: gymFieldFocused ? 2 : 1)
                )

                // Recent gyms chips
                if !recentGyms.isEmpty && gymName.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentGyms, id: \.self) { gym in
                                Button {
                                    withAnimation(.geckoSnappy) { gymName = gym }
                                } label: {
                                    Text(gym)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.geckoGreen)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.geckoGreen.opacity(0.1), in: Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.geckoGreen.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.geckoSpring.delay(0.2), value: appeared)

            // Duration + Date row
            HStack(spacing: 12) {
                // Duration
                Button {
                    withAnimation(.geckoSnappy) { showDurationPicker.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 14))
                        Text(durationMinutes.durationFormatted)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Date
                Button {
                    withAnimation(.geckoSnappy) { showDatePicker.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                        Text(Calendar.current.isDateInToday(date) ? "Today" : date.dayMonthFormatted)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.geckoSpring.delay(0.3), value: appeared)

            // Duration picker (expandable)
            if showDurationPicker {
                HStack(spacing: 8) {
                    Picker("Hours", selection: Binding(
                        get: { durationMinutes / 60 },
                        set: { durationMinutes = $0 * 60 + (durationMinutes % 60) }
                    )) {
                        ForEach(0...8, id: \.self) { Text("\($0)h") }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Minutes", selection: Binding(
                        get: { (durationMinutes % 60) / 5 * 5 },
                        set: { durationMinutes = (durationMinutes / 60) * 60 + $0 }
                    )) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0)m") }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 120)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            // Date picker (expandable)
            if showDatePicker {
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            // Notes (tap to expand)
            VStack(alignment: .leading, spacing: 8) {
                if showNotes {
                    TextField("Add notes about your session...", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .font(.subheadline)
                        .padding(12)
                        .background(Color.surfaceBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                } else {
                    Button {
                        withAnimation(.geckoSnappy) { showNotes = true }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 14))
                            Text("Add notes...")
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(.geckoSpring.delay(0.35), value: appeared)

            // Caption for feed post
            VStack(alignment: .leading, spacing: 8) {
                Text("Feed caption (optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                TextField("How was this session?", text: $caption, axis: .vertical)
                    .lineLimit(3, reservesSpace: false)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .opacity(appeared ? 1 : 0)
            .animation(.geckoSpring.delay(0.4), value: appeared)

            Spacer().frame(height: 4)

            // Save & Share
            Button(action: onSave) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text("Save & Share")
                        .fontWeight(.bold)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    gymName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? AnyShapeStyle(Color.gray.opacity(0.2))
                        : AnyShapeStyle(Color.geckoGreenGradient)
                )
                .foregroundColor(gymName.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .white)
                .clipShape(Capsule())
                .shadow(
                    color: gymName.trimmingCharacters(in: .whitespaces).isEmpty ? .clear : Color.geckoGreen.opacity(0.3),
                    radius: gymName.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 8,
                    x: 0, y: 4
                )
            }
            .bouncePress()
            .disabled(gymName.trimmingCharacters(in: .whitespaces).isEmpty)
            .sensoryFeedback(.impact(weight: .heavy), trigger: gymName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.geckoSpring.delay(0.45), value: appeared)
        }
        .padding(24)
        .onAppear {
            durationMinutes = autoMinutes
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                gymFieldFocused = true
            }
        }
    }
}
