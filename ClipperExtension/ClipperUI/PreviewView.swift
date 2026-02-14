import SwiftUI

struct PreviewView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            Text(markdown)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    PreviewView(markdown: """
    # Sample Article

    This is a preview of the clipped content.

    ## Features

    - Point one
    - Point two
    - Point three

    > A blockquote for emphasis

    ```swift
    let code = "example"
    ```
    """)
}
