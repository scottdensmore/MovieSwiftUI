import SwiftUI

struct ReviewRow : View {
    let review: Review
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review written by \(review.author)")
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(1)
            Text(review.content)
                .font(.body)
                .lineLimit(nil)
        }
        .padding(.vertical)
    }
}

#Preview {
    ReviewRow(review: Review(id: "0", author: "Test", content: "Test body"))
}
