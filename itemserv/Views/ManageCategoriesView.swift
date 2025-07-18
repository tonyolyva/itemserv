import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.categoryName) private var categories: [Category]
    
    @State private var categoryToDelete: Category?
    @State private var categoryToEdit: Category?
    @State private var newCategoryName = ""
    @State private var categoryExists = false
    @State private var editedCategoryName = ""
    @State private var addButtonBounce = false
    @State private var sortAscending = true
    @State private var searchText = ""
    // CSV import/export state
    @State private var isImportingFile = false
    @State private var exportURL: URL?
    @State private var isShowingExportSheet = false
    
    var body: some View {
        VStack {
            Text("Manage Categories")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            // Import/Export buttons
            HStack {
                Button("Import") {
                    isImportingFile = true
                }
                Spacer()
                Button("Export") {
                    exportCategories()
                }
            }
            .padding(.horizontal)
            HStack {
                TextField("Search Categories", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale)
                }
            }
            .padding(.horizontal)
            Picker("Sort Order", selection: $sortAscending) {
                Text("A → Z").tag(true)
                Text("Z → A").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)
            List {
                Section {
                    ForEach(filteredCategories, id: \.id) { category in
                        HStack {
                            highlightedText(for: category.categoryName ?? "", matching: searchText)
                            Spacer()
                        }
                        .contentShape(Rectangle()) // Makes the entire row tappable
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                categoryToDelete = category
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                categoryToEdit = category
                                editedCategoryName = category.categoryName ?? ""
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                Section(header: Text("Add New Category")) {
                    VStack(spacing: 12) {
                        HStack {
                            TextField("Category Name", text: $newCategoryName)
                                .onChange(of: newCategoryName) {
                                    categoryExists = false
                                }
                            
                            Button(action: {
                                addNewCategory()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.5)) {
                                    addButtonBounce.toggle()
                                }
                            }) {
                                Text("Add")
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                    .background(newCategoryName.trimmed().isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .scaleEffect(addButtonBounce ? 1.1 : 1.0)
                                    .shadow(color: (newCategoryName.trimmed().isEmpty ? Color.clear : Color.blue.opacity(0.4)), radius: addButtonBounce ? 8 : 4, x: 0, y: 0)
                                    .opacity(newCategoryName.trimmed().isEmpty ? 0.6 : 1.0)
                                    .animation(.easeInOut(duration: 0.3), value: newCategoryName)
                                    .animation(.spring(), value: addButtonBounce)
                            }
                            .disabled(newCategoryName.trimmed().isEmpty)
                        }
                        if categoryExists {
                            Text("Category already exists")
                                .foregroundColor(.red)
                                .font(.caption)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
//            .listStyle(.plain)
            .animation(.easeInOut(duration: 0.3), value: categories) // 📦 Animate List changes!
            .alert("Delete Category", isPresented: .constant(categoryToDelete != nil), presenting: categoryToDelete) { category in
                Button(role: .destructive) {
                    deleteCategory(category)
                } label: {
                    Text("Delete “\(category.categoryName ?? "this category")”")
                }
                
                Button(role: .cancel) {
                    categoryToDelete = nil
                } label: {
                    Text("Cancel")
                }
            } message: { category in
                Text("Are you sure you want to permanently delete “\(category.categoryName ?? "this category")”? This action cannot be undone.")
            }
            .sheet(item: $categoryToEdit) { category in
                NavigationStack {
                    Form {
                        TextField("Category Name", text: $editedCategoryName)
                    }
                    .navigationTitle("Edit Category")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveEditedCategory(category)
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                categoryToEdit = nil
                            }
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.commaSeparatedText]) { result in
            switch result {
            case .success(let url):
                importCategories(from: url)
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: Binding(get: {
            exportURL != nil && isShowingExportSheet
        }, set: { newValue in
            if !newValue {
                isShowingExportSheet = false
                exportURL = nil
            }
        })) {
            NavigationStack {
                VStack {
                    ShareLink(item: exportURL!)
                        .padding()
                }
                .navigationTitle("Export Categories")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isShowingExportSheet = false
                            exportURL = nil
                        }
                    }
                }
            }
        }
        .onAppear {
        }
    }
    
    // MARK: - Actions
    private func addNewCategory() {
        let trimmedName = newCategoryName.trimmed()
        guard !trimmedName.isEmpty else { return }
        
        let existingNames = categories.map { ($0.categoryName ?? "").lowercased() }
        if existingNames.contains(trimmedName.lowercased()) {
            withAnimation {
                categoryExists = true
            }
            return
        }
        
        let newCategory = Category(categoryName: trimmedName)
        modelContext.insert(newCategory)
        try? modelContext.save()
        
        withAnimation(.easeOut(duration: 0.4)) { }
        
        newCategoryName = ""
        categoryExists = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func deleteCategory(_ category: Category) {
        withAnimation(.easeInOut(duration: 0.4)) {
            modelContext.delete(category)
            try? modelContext.save()
        }
        categoryToDelete = nil
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        withAnimation(.easeInOut(duration: 0.4)) {
            for index in offsets {
                let category = categories[index]
                modelContext.delete(category)
            }
            try? modelContext.save()
        }
    }
    
    private func saveEditedCategory(_ category: Category) {
        let trimmedName = editedCategoryName.trimmed()
        guard !trimmedName.isEmpty else {
            categoryToEdit = nil
            return
        }
        
        withAnimation {
            category.categoryName = trimmedName
            try? modelContext.save()
        }
        categoryToEdit = nil
    }
    
    // MARK: - Computed Properties
    private var sortedCategories: [Category] {
        if sortAscending {
            return categories.sorted { ($0.categoryName ?? "") < ($1.categoryName ?? "") }
        } else {
            return categories.sorted { ($0.categoryName ?? "") > ($1.categoryName ?? "") }
        }
    }
    
    private var filteredCategories: [Category] {
        if searchText.trimmed().isEmpty {
            return sortedCategories
        } else {
            return sortedCategories.filter { category in
                (category.categoryName ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - CSV Import/Export
    private func exportCategories() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "categories_\(timestamp).csv"

        let content = categories
            .compactMap { $0.categoryName }
            .joined(separator: "\n")

        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try content.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
            isShowingExportSheet = true
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }

    private func importCategories(from url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try String(contentsOf: url, encoding: .utf8)
                let lines = data.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                // Delete all existing
                for cat in categories {
                    modelContext.delete(cat)
                }

                // Insert new
                for name in lines {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        let newCategory = Category(categoryName: trimmedName)
                        modelContext.insert(newCategory)
                    }
                }

                try? modelContext.save()
            } catch {
                print("Import failed: \(error.localizedDescription)")
            }
        } else {
            print("Access to the file was denied.")
        }
    }
}
