import SwiftUI
import NotionSwift
import Foundation

let notion = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey:"SECRET"))
let coursesDatabase = Database.Identifier("DOESNT_MATTER")
let todoDatabase = Database.Identifier("IDK")
let categoryMap: [String:String] = ["Personal":"brown", "School":"pink","Work":"orange"]

struct ContentView: View {
    @State private var taskName: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var category: Category = .personal
    @State private var selectedClass: String = ""
    @State private var showingClassPicker = false
    
    @State private var showToast = false
    @State private var toastItem: String? = nil
    
    @State private var courseMap: [String: URL] = [:]
    
    enum Category: String, CaseIterable {
        case personal = "Personal"
        case school = "School"
    }
    
    var isAddButtonDisabled: Bool {
        return taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ?
                UIColor(Color.darkModeBackground) : UIColor(Color.lightModeBackground)
            }).ignoresSafeArea()
            if showToast {
                  VStack {
                      ToastView(item: toastItem)
                      Spacer()
                  }
                  .transition(.move(edge: .top))
                  .animation(.bouncy(duration: 0.2), value: showToast)
              }
            VStack(spacing: 20) {
                Text("Todo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                TextField("Task Name", text: $taskName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                
                VStack {
                    DatePicker("Deadline", selection: $dueDate, displayedComponents: .date)
                        .padding(.horizontal)
                    
                    if category == .school {
                        HStack {
                            Text("Class")
                            Spacer()
                            Button(action: {
                                showingClassPicker = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text(selectedClass.isEmpty ? "Select Class" : selectedClass)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .padding(.vertical, 8)
                                .padding(.trailing, 18)
                                // todo: FIX SIZE WITH REGARDS TO TEXT BRUH
                                .frame(maxWidth: 130) // todo: hack
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .foregroundColor(.primary)
                        }
                        .padding(.horizontal)                    }
                }
                .frame(height: 75, alignment: .top)
                .padding(.bottom)
                
                Picker("Category", selection: $category) {
                    ForEach(Category.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                Button(action: {
                    pushTaskToNotion(
                        name: taskName,
                        dueDate: dueDate,
                        category: category,
                        associatedClass: category == .school ? selectedClass : nil
                    )
                }) {
                    Text("Push Task")
                        .padding()
                        .frame(width: 250)
                        .background(Color(UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark ?
                        
                            (isAddButtonDisabled ? .systemGray5 : .white)
                            : (isAddButtonDisabled ? .systemGray3 : .black)
                        }))
                        .foregroundColor(Color(UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark ? .black : .white
                        }))
                        .cornerRadius(5)
                        .disabled(isAddButtonDisabled)
                }
                .padding(.vertical, 40)
                
                Spacer()
            }
            .padding()
            .sheet(isPresented: $showingClassPicker) {
                ClassPickerView(selectedClass: $selectedClass, classes: Array(courseMap.keys))
            }
            .task {
                 await fetchCourses()
            }
        }
    }
    
    // p-body
    
    func fetchCourses() async {
        do {
            courseMap = try await fetchCoursesDb()
        } catch {
            print("Error fetching courses: \(error)")
        }
    }
    
    func pushTaskToNotion(name: String, dueDate: Date, category: Category, associatedClass: String?) {
        let request = PageCreateRequest(
            parent: .database(todoDatabase),
            properties: [
                "Name": .init(
                    type: .title([
                        .init(string: name)
                    ])
                ),
                "Type": .init(
                    type: .select(PagePropertyType.SelectPropertyValue(id: nil, name: category.rawValue, color: categoryMap[category.rawValue]))
                ),
                "Deadline": .init(
                    type: .date(.init(start: DateValue.dateOnly(dueDate), end: nil))
                ),
                "Associated With": .init(
                           type: .richText(
                               associatedClass != nil ? [
                                   RichText(
                                       plainText: nil,
                                       type: .mention(
                                           MentionTypeValue(
                                               type: .page(MentionTypeValue.PageMentionValue(
                                                   Page.Identifier(
                                                       courseMap[associatedClass!]!.absoluteString.components(separatedBy: "-").last!
                                                   )
                                               ))
                                           )
                                       )
                                   )
                               ] : []
                           )
                       )
            ]
        )
        
        notion.pageCreate(request: request) { result in
             switch result {
             case .success(let page):
                 DispatchQueue.main.async {
                     self.setIconForPage(page: page, icon: "🤔")
                     taskName = ""
                     self.toastItem = name
                     withAnimation {
                         self.showToast = true
                     }
                     DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                         withAnimation {
                             self.showToast = false
                         }
                     }
                 }
             case .failure(_):
                 DispatchQueue.main.async {
                     self.toastItem = nil
                     withAnimation {
                         self.showToast = true
                     }
                     DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                         withAnimation {
                             self.showToast = false
                         }
                     }
                 }
             }
         }
    }
    
    // 🤔
    func setIconForPage(page: Page, icon: String) {
        let updateRequest = PageProperiesUpdateRequest(
            //icon: .emoji(icon)
            icon: .external(url: "https://www.notion.so/icons/paste_gray.svg")
        )
        
        notion.pageUpdateProperties(pageId: page.id, request: updateRequest) { result in
            switch result {
            case .success(_):
                print("Icon set successfully")
            case .failure(let error):
                print("Failed to set icon: \(error)")
            }
        }
    }
}


func fetchCoursesDb() async throws -> [String: URL] {
    return try await withCheckedThrowingContinuation { continuation in
        notion.databaseQuery(databaseId: coursesDatabase) { result in
            switch result {
            case .success(let response):
                var courseMap: [String: URL] = [:]
                for page in response.results {
                    let properties = page.properties
                    if let codeProperty = properties["Course Code"],
                       case .richText(let codeArray) = codeProperty.type,
                       let soleCode = codeArray.first,
                       let courseCode = soleCode.plainText {
                        let url = page.url
                        courseMap[courseCode] = url
                    }
                }
                continuation.resume(returning: courseMap)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}

#Preview {
    ContentView()
}
