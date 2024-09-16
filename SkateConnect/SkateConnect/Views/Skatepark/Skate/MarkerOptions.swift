//
//  MarkerOptions.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/10/24.
//

import Combine
import NostrSDK
import SwiftUI

struct MarkerOptions: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @EnvironmentObject var viewModel: ContentViewModel
    
    @ObservedObject var navigation = NavigationManager.shared

    var marks: [Mark]
    
    let keychainForNostr = NostrKeychainStorage()
        
    var body: some View {
        VStack(spacing: 20) {
            Text("Marker Options")
                .font(.title2)
                .padding()
            
            Button(action: {
                navigation.isShowingCreateChannel = true
                viewModel.mark = marks[0]
            }) {
                Text("Start New Chat")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                for mark in marks {
                    let spot = Spot(name: mark.name, address: "", state: "", note: "", latitude: mark.coordinate.latitude, longitude: mark.coordinate.longitude)
                    context.insert(spot)
                }
                
                dismiss()
            }) {
                Text("Add to Address Book")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .fullScreenCover(isPresented: $navigation.isShowingCreateChannel) {
            NavigationView {
                CreateChannel()
                    .navigationBarItems(leading:
                    Button(action: {
                        navigation.isShowingCreateChannel = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Spacer()
                        }
                    })
            }
        }
        .padding()
    }
}
#Preview {
    MarkerOptions(marks: [])
}
