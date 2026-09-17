import MinehutKit
import SwiftUI

extension APIError {
    var message: String {
        switch self {
        case .noData: return "The collector has not recorded any data yet. Try again in 15 minutes."
        case .http(let status): return "The server returned an error (\(status))."
        case .decoding: return "The server sent a response this app does not understand."
        case .transport(let detail): return "Can't reach the server. \(detail)"
        }
    }
}

struct UpdatedHeader: View {
    let updatedAt: Int
    let isOffline: Bool
    var isLoading = false

    var body: some View {
        HStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(Formatters.updated(updatedAt, now: context.date))
            }
            if isOffline {
                Label("Saved data", systemImage: "clock.arrow.circlepath").foregroundStyle(.orange)
            }
            Spacer()
            if isLoading { ProgressView().controlSize(.mini) }
        }
        .font(.caption)
        .textCase(nil)
    }
}

struct ErrorStateView: View {
    let error: APIError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            Button("Retry", action: retry).buttonStyle(.bordered)
        }
    }
}

struct LoadingRow: View {
    var body: some View {
        ProgressView().frame(maxWidth: .infinity).padding()
    }
}
