import SwiftUI

struct PaperCardView: View {
    let paper: Paper
    let isSaved: Bool
    let onOpen: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(paper.categories.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(paper.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(paper.authors.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(paper.abstract)
                    .font(.body)
            }

            Spacer()

            HStack {
                Button(action: onToggleSave) {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                }
                Spacer()
                Button("Read PDF", action: onOpen)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
