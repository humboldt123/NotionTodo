//
//  ToastView.swift
//  NotionTodo
//
//  Created by Vish on 8/27/24.
//

import SwiftUI

struct ToastView: View {
    let item: String?
    var body: some View {
        HStack {
            if let item = item {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(item) added to todo list")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Failed to push todo item")
            }
        }
        .padding()
        .background(Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .black : .white
        }))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}
