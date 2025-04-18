import SwiftUI

struct TabHeaderView<Content: View>: View {
    let title: String
    let trailingContent: Content
    
    init(title: String, @ViewBuilder trailingContent: () -> Content) {
        self.title = title
        self.trailingContent = trailingContent()
    }
    
    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.system(size: 28, weight: .bold))
            Spacer()
            trailingContent
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
} 