import SwiftUI

struct BottomSendBar: View {
    var sendAction: () -> Void
    var enabled: Bool = true

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: { if enabled { sendAction() } }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .disabled(!enabled)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack {
        Spacer()
        BottomSendBar(sendAction: {})
            .padding()
    }
}

