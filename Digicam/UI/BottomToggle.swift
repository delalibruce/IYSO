import SwiftUI

enum AppTab {
    case camera, gallery
}

struct BottomToggle: View {
    @Binding var activeTab: AppTab

    var body: some View {
        HStack(spacing: 18) {
            // Gallery icon (left, active when in gallery)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { activeTab = .gallery }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 22.9)
                        .fill(Color(red: 127/255, green: 104/255, blue: 96/255).opacity(activeTab == .gallery ? 0.7 : 0))
                        .frame(width: 47, height: 47)
                    Image(systemName: "circle.grid.2x2.fill")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white)
                }
                .frame(width: 47, height: 47)
            }

            // Camera icon (right, active when in camera)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { activeTab = .camera }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 22.9)
                        .fill(Color(red: 127/255, green: 104/255, blue: 96/255).opacity(activeTab == .camera ? 0.7 : 0))
                        .frame(width: 47, height: 47)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white)
                }
                .frame(width: 47, height: 47)
            }
        }
        .frame(width: 124, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 33.7)
                .fill(Color(white: 145/255).opacity(0.21))
        )
    }
}
