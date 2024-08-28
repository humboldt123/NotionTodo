import SwiftUI
import NotionSwift

let notion = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey:"secret_bQSALZnIv8vymmCBwjecAAJOx9JckyBgzQlRmCKwFEd"))
let coursesDatabase = Database.Identifier("319ee0842bbb46da850973eb087f13fc")
let todoDatabase = Database.Identifier("46193d25615b4e31b54380b9d6c0a1bf")
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
        VStack(spacing: 20) {
            Text("Todo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 30)
            
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
                            .frame(maxWidth: 130) // todo: hack
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                }
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
                Text("Add Todo")
                    .padding()
                    .frame(width: 250)
                    .background(Color(UIColor { traitCollection in
                        traitCollection.userInterfaceStyle == .dark ?
                    
                        (isAddButtonDisabled ? .systemGray3 : .white)
                        : (isAddButtonDisabled ? .systemGray : .black)
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
        
        
        if showToast {
              VStack {
                  Spacer()
                  ToastView(item: toastItem)
              }
              .transition(.move(edge: .bottom))
              .animation(.easeInOut, value: showToast)
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
        let dateString = dueDate.ISO8601Format
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
             case .success(_):
                 DispatchQueue.main.async {
                     taskName = ""
                     self.toastItem = name
                     self.showToast = true
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                         self.showToast = false
                     }
                 }
             case .failure(_):
                 DispatchQueue.main.async {
                     self.toastItem = nil
                     self.showToast = true
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                         self.showToast = false
                     }
                 }
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
