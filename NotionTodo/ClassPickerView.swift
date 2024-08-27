//
//  ClassPickerView.swift
//  NotionTodo
//
//  Created by Vish on 8/26/24.
//

import SwiftUI

struct ClassPickerView: View {
    @Binding var selectedClass: String
    let classes: [String]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(classes, id: \.self) { className in
                Button(action: {
                    selectedClass = className
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(className)
                }
            }
            .navigationTitle("Select Class")
        }
    }
}
