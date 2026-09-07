import SwiftUI

/// Module 2 — Lingo. Plain explanations of football words: a search box that
/// filters as you type against the term and its meaning, terms grouped by
/// category, and rows that expand in place. No detail view, no nesting.
struct LingoView: View {
    let content: LingoContent
    @Bindable var store: MyTurnStore

    private var query: String { store.lingoQuery.trimmingCharacters(in: .whitespaces).lowercased() }

    private var filtered: [LingoTerm] {
        guard !query.isEmpty else { return content.terms }
        return content.terms.filter {
            $0.term.lowercased().contains(query) || $0.meaning.lowercased().contains(query)
        }
    }

    private var byId: [String: LingoTerm] {
        Dictionary(uniqueKeysWithValues: content.terms.map { ($0.id, $0) })
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                        if filtered.isEmpty {
                            MyTurnEmptyText(text: "Nothing for that yet. Try a shorter word.")
                        } else {
                            ForEach(LingoCategory.allCases, id: \.self) { category in
                                let terms = filtered.filter { $0.category == category }
                                if !terms.isEmpty {
                                    MyTurnSectionLabel(text: category.title)
                                        .padding(.top, 8)
                                    ForEach(terms) { term in
                                        termRow(term, proxy: proxy)
                                            .id(term.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.warmWhite.opacity(0.6))
            TextField("", text: $store.lingoQuery, prompt: Text("Search a word you heard").foregroundColor(.warmWhite.opacity(0.45)))
                .font(.jakarta(16, weight: .regular))
                .foregroundColor(.warmWhite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !store.lingoQuery.isEmpty {
                Button {
                    store.lingoQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.warmWhite.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.warmWhite.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hotRose.opacity(0.35), lineWidth: 1))
        .cornerRadius(12)
    }

    private func termRow(_ term: LingoTerm, proxy: ScrollViewProxy) -> some View {
        let expanded = store.lingoExpandedId == term.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.lingoExpandedId = expanded ? nil : term.id
                }
            } label: {
                HStack(spacing: 12) {
                    Text(term.term)
                        .font(.jakarta(16, weight: .semiBold))
                        .foregroundColor(.textPrimaryOnCard)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.hotRose)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(term.meaning)
                        .font(.jakarta(15, weight: .regular))
                        .foregroundColor(.textPrimaryOnCard)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "ear")
                            .font(.system(size: 12))
                            .foregroundColor(.hotRose)
                            .padding(.top, 2)
                        Text(term.heard)
                            .font(.jakarta(13, weight: .italic))
                            .foregroundColor(.textSecondaryOnCard)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let refs = term.seeAlso?.compactMap({ byId[$0] }), !refs.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Not to be confused with")
                                .font(.jakarta(12, weight: .regular))
                                .foregroundColor(.textSecondaryOnCard)
                            ForEach(refs) { ref in
                                Button {
                                    // If the reference is filtered out by the
                                    // search, clear it so the term can be shown.
                                    if !filtered.contains(where: { $0.id == ref.id }) { store.lingoQuery = "" }
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        store.lingoExpandedId = ref.id
                                        proxy.scrollTo(ref.id, anchor: .top)
                                    }
                                } label: {
                                    Text(ref.term)
                                        .font(.jakarta(12, weight: .semiBold))
                                        .foregroundColor(.hotRose)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
    }
}
