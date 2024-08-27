import SwiftUI
import NotionSwift

let notion = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey:"secret_bQSALZnIv8vymmCBwjecAAJOx9JckyBgzQlRmCKwFEd"))
let coursesDatabase = Database.Identifier("319ee0842bbb46da850973eb087f13fc")
let todoDatabase = Database.Identifier("46193d25615b4e31b54380b9d6c0a1bf")
let categoryMap: [String:String] = ["Personal":"brown", "School":"pink","Work":"orange"]

struct ContentView: View {
    @State private var todoName: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var category: Category = .personal
    @State private var selectedClass: String = ""
    @State private var showingClassPicker = false
    
    @State private var courseMap: [String: URL] = [:]
    
    enum Category: String, CaseIterable {
        case personal = "Personal"
        case school = "School"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Todo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            TextField("Todo Item Name", text: $todoName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                .padding(.horizontal)
            
            Picker("Category", selection: $category) {
                ForEach(Category.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            if category == .school {
                Button(action: {
                    showingClassPicker = true
                }) {
                    Text(selectedClass.isEmpty ? "Select Class" : selectedClass)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            Button(action: {
                pushTaskToNotion(
                    name: todoName,
                    dueDate: dueDate,
                    category: category,
                    associatedClass: category == .school ? selectedClass : nil
                )
            }) {
                Text("Add Todo")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
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
            case .success(let response):
                print("Item added successfully.") // \(response)")
            case .failure(let error):
                print("Error adding item.")// \(error)")
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
