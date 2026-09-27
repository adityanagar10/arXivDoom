import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: FeedViewModel?
    @State private var readerPaper: Paper?

    var body: some View {
        Group {
            if let viewModel {
                if let errorMessage = viewModel.errorMessage, viewModel.papers.isEmpty {
                    ContentUnavailableView {
                        Label("Can't Load Feed", systemImage: "wifi.slash")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadInitial() }
                        }
                    }
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.papers) { paper in
                                PaperCardView(
                                    paper: paper,
                                    isSaved: viewModel.isSaved(paper),
                                    onOpen: { readerPaper = paper },
                                    onToggleSave: { viewModel.toggleSave(paper) }
                                )
                                .frame(height: 600)
                                .onDisappear {
                                    viewModel.markSeen(paper)
                                    Task { await viewModel.loadMoreIfNeeded(currentPaper: paper) }
                                }
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                }
            } else {
                ProgressView()
                    .task {
                        let vm = FeedViewModel(context: modelContext)
                        viewModel = vm
                        await vm.loadInitial()
                    }
            }
        }
        .onDisappear {
            // Ensure any buffered "seen" marks are persisted even if the feed is
            // dismissed before another page-load flush point is reached.
            viewModel?.flushSeenPapers()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Ensure buffered "seen" marks are persisted before the app is
            // backgrounded (and possibly killed while backgrounded), since
            // `.onDisappear` alone doesn't fire in that case.
            if newPhase == .background || newPhase == .inactive {
                viewModel?.flushSeenPapers()
            }
        }
        .sheet(item: $readerPaper) { paper in
            PDFReaderScreen(paper: paper)
        }
    }
}
