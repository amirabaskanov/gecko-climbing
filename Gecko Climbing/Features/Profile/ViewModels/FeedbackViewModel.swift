import Foundation
import SwiftUI
import PhotosUI

@Observable @MainActor
final class FeedbackViewModel {
    var category: FeedbackCategory = .bug
    var message: String = ""
    var selectedPhoto: PhotosPickerItem?
    var screenshotPreview: Image?
    var isLoading = false
    var error: Error?
    var didSubmit = false

    private var screenshotData: Data?
    private let feedbackRepository: any FeedbackRepositoryProtocol
    private let userId: String

    var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(feedbackRepository: any FeedbackRepositoryProtocol, userId: String) {
        self.feedbackRepository = feedbackRepository
        self.userId = userId
    }

    func loadScreenshot() async {
        guard let item = selectedPhoto else {
            screenshotData = nil
            screenshotPreview = nil
            return
        }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        screenshotData = data

        if let uiImage = UIImage(data: data) {
            screenshotPreview = Image(uiImage: uiImage)
        }
    }

    func removeScreenshot() {
        selectedPhoto = nil
        screenshotData = nil
        screenshotPreview = nil
    }

    func submit() async {
        guard canSubmit else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await feedbackRepository.submitFeedback(
                userId: userId,
                category: category,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                screenshotData: screenshotData
            )
            didSubmit = true
        } catch {
            self.error = error
        }
    }

    func clearError() {
        error = nil
    }
}
