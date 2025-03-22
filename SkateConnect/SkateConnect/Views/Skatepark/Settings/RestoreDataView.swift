//
//  RestoreDataView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/30/25.
//

import SwiftUI

struct RestoreDataView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var showRestoreNotification = false
    @State private var jsonInput: String = ""
    @State private var prettifiedJSON: String = ""
        
    var body: some View {
        ScrollView { // Wrap the entire content in a ScrollView
            VStack(spacing: 20) {
                // Paste JSON Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Paste JSON Below")
                            .font(.headline)
                        Spacer()
                        Button {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            prettifiedJSON = prettifyJSON(jsonInput)
                        } label: {
                            Text("🧹")
                        }
                        Button {
                            clear()
                        } label: {
                            Text("🗑️")
                        }
                    }
                    
                    ScrollView {
                        TextEditor(text: $jsonInput)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150, maxHeight: .infinity) // Flexible height
                            .padding()
                            .background(Color(.systemBackground)) // Use system background color
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    .frame(maxHeight: 200) // Set a maximum height for the scrollable area
                }
                
                // Prettified JSON Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prettified JSON:")
                        .font(.headline)
                    
                    ScrollView {
                        Text(prettifiedJSON)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 200) // Adjust maxHeight as needed
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Restore Data")
        .toolbar {
            // Restore button in the trailing position
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Import") {
                    showRestoreNotification = dataManager.restoreData(from: jsonInput)
                    walletManager.refreshAliases()
                }
            }
        }
        .overlay(
            Group {
                if showRestoreNotification {
                    Text("Data imported!")
                        .padding()
                        .background(Color.orange.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showRestoreNotification = false
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut, value: showRestoreNotification),
            alignment: .center
        )
        .ignoresSafeArea(.keyboard) // Prevent the keyboard from pushing the view up
    }
    
    func clear() {
        jsonInput = ""
        prettifiedJSON = ""
    }
    

}

func prettifyJSON(_ jsonString: String) -> String {
    guard let jsonData = jsonString.data(using: .utf8),
          let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
          let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
          let prettyPrintedJson = String(data: prettyJsonData, encoding: .utf8) else {
        return "Invalid JSON"
    }
    return prettyPrintedJson
}

