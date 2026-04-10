import SwiftUI
import SwiftData
import PhotosUI

struct SessionDetailsForm: View {
    let climbCount: Int
    let autoMinutes: Int

    @Binding var gymName: String
    @Binding var date: Date
    @Binding var durationMinutes: Int
    @Binding var notes: String
    @Binding var caption: String
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var photoImages: [UIImage]

    let recentGyms: [String]
    let isSaving: Bool
    let onSave: () -> Void

    private var isButtonDisabled: Bool {
        gymName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving
    }

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
                    .foregroundStyle(.primary)
                Text("\(climbCount) climbs logged")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.geckoSpring.delay(0.1), value: appeared)

            // Gym name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Where did you climb?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Color.geckoPrimary)
                        .font(.system(size: 20))
                    TextField("Gym name", text: $gymName)
                        .font(.body.weight(.medium))
                        .focused($gymFieldFocused)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.geckoInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(gymFieldFocused ? Color.geckoPrimary : Color.geckoPrimary.opacity(0.2), lineWidth: gymFieldFocused ? 2 : 1)
                )

                // Recent gyms chips — show matching or all when empty
                if !recentGyms.isEmpty {
                    let filtered = gymName.isEmpty
                        ? recentGyms
                        : recentGyms.filter { $0.localizedCaseInsensitiveContains(gymName) && $0 != gymName }

                    if !filtered.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filtered, id: \.self) { gym in
                                    Button {
                                        withAnimation(.geckoSnappy) { gymName = gym }
                                    } label: {
                                        Text(gym)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.geckoPrimary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(Color.geckoPrimary.opacity(0.1), in: Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.geckoPrimary.opacity(0.2), lineWidth: 1)
                                            )
                                    }
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
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.geckoInputBackground)
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
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.geckoInputBackground)
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
                        .background(Color.geckoInputBackground)
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
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(.geckoSpring.delay(0.35), value: appeared)

            // Photos
            VStack(alignment: .leading, spacing: 8) {
                Text("Photos (optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // Existing photo thumbnails
                        ForEach(Array(photoImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    withAnimation(.geckoSnappy) {
                                        photoImages.remove(at: index)
                                        if index < selectedPhotos.count {
                                            selectedPhotos.remove(at: index)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }

                        // Add photo button
                        if photoImages.count < 5 {
                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 5 - photoImages.count,
                                matching: .images
                            ) {
                                VStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 20))
                                    Text("Add")
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(.secondary)
                                .frame(width: 80, height: 80)
                                .background(Color.geckoInputBackground, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                        .foregroundStyle(.secondary.opacity(0.3))
                                )
                            }
                        }
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(.geckoSpring.delay(0.4), value: appeared)

            // Caption for feed post
            VStack(alignment: .leading, spacing: 8) {
                Text("Feed caption (optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("How was this session?", text: $caption, axis: .vertical)
                    .lineLimit(3, reservesSpace: false)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color.geckoInputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .opacity(appeared ? 1 : 0)
            .animation(.geckoSpring.delay(0.4), value: appeared)

            Spacer().frame(height: 4)

            // Save & Share
            Button(action: onSave) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(isSaving ? "Saving..." : "Save & Share")
                        .fontWeight(.bold)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isButtonDisabled
                        ? AnyShapeStyle(Color.geckoInputBackground)
                        : AnyShapeStyle(Color.geckoPrimaryGradient)
                )
                .foregroundStyle(isButtonDisabled ? Color.secondary : Color.white)
                .clipShape(Capsule())
                .shadow(
                    color: isButtonDisabled ? .clear : Color.geckoPrimary.opacity(0.3),
                    radius: isButtonDisabled ? 0 : 8,
                    x: 0, y: 4
                )
            }
            .bouncePress()
            .disabled(isButtonDisabled)
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
