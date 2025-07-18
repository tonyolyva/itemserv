import SwiftUI
struct PhotoSourcePickerView: View {
    let onSelectLibrary: () -> Void
    let onSelectCamera: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onSelectLibrary) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Photo Library")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .frame(height: 50)

            Button(action: onSelectCamera) {
                HStack {
                    Image(systemName: "camera")
                    Text("Camera")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .frame(height: 50)
        }
    }
}
