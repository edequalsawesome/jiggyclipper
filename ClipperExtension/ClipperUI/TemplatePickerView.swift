import SwiftUI

struct TemplatePickerView: View {
    @Binding var selectedTemplateId: String?
    let onSelectionChange: (String?) -> Void

    @StateObject private var templateStorage = TemplateStorage.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Template")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if templateStorage.templates.isEmpty {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text("No templates configured")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                Menu {
                    ForEach(templateStorage.templates) { template in
                        Button {
                            selectedTemplateId = template.id
                            onSelectionChange(template.id)
                        } label: {
                            HStack {
                                Text(template.name)
                                if selectedTemplateId == template.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let selectedId = selectedTemplateId,
                           let template = templateStorage.templates.first(where: { $0.id == selectedId }) {
                            Text(template.name)
                                .foregroundStyle(.primary)
                        } else {
                            Text("Select template...")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
}

#Preview {
    TemplatePickerView(selectedTemplateId: .constant(nil)) { _ in }
        .padding()
}
