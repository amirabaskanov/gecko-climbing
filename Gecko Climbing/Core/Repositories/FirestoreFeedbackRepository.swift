import Foundation
import FirebaseFirestore
import FirebaseStorage

final class FirestoreFeedbackRepository: FeedbackRepositoryProtocol, @unchecked Sendable {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private var feedbackRef: CollectionReference { db.collection("feedback") }

    func submitFeedback(
        userId: String,
        category: FeedbackCategory,
        message: String,
        screenshotData: Data?
    ) async throws {
        let docId = UUID().uuidString

        // Upload screenshot if provided
        var screenshotURL: String?
        if let data = screenshotData {
            let ref = storage.reference().child("feedback/\(docId).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await ref.putDataAsync(data, metadata: metadata)
            screenshotURL = try await ref.downloadURL().absoluteString
        }

        // Build feedback document
        var data: [String: Any] = [
            "userId": userId,
            "category": category.rawValue,
            "message": message,
            "deviceInfo": DeviceInfo.current,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let url = screenshotURL {
            data["screenshotURL"] = url
        }

        try await feedbackRef.document(docId).setData(data)
    }

    // MARK: - Reports

    private var reportsRef: CollectionReference { db.collection("reports") }

    func submitReport(_ report: ReportModel) async throws {
        var data: [String: Any] = [
            "reporterUserId": report.reporterUserId,
            "targetType": report.targetType.rawValue,
            "targetId": report.targetId,
            "targetAuthorId": report.targetAuthorId,
            "reason": report.reason.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "deviceInfo": DeviceInfo.current
        ]
        if let postId = report.targetPostId {
            data["targetPostId"] = postId
        }
        try await reportsRef.document(report.id).setData(data)
    }
}
