import SwiftUI
import PhotosUI

struct PhotoPickerButton<Label: View>: View {
    @Binding var selectedImage: UIImage?
    let label: () -> Label

    @State private var photosPickerItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $photosPickerItem, matching: .images) {
            label()
        }
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }
}
