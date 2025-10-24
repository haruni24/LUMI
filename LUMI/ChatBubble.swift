import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 24) }
            Text(message.text)
                .foregroundColor(isUser ? .white : .primary)
                .padding(12)
                .background(isUser ? Color.blue : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: UIScreen.main.bounds.width * 0.68, alignment: .leading)
            if !isUser { Spacer(minLength: 24) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack {
        ChatBubble(message: .init(role: .user, text: "Hello!"))
        ChatBubble(message: .init(role: .assistant, text: "Hi there!"))
    }
}

