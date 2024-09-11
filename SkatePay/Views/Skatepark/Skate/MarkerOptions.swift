//
//  MarkerOptions.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/10/24.
//

import SwiftUI

struct MarkerOptions: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    var npub: String?
    var marks: [Mark]
    
    @State private var showChatView = false
    
    var landmarks: [Landmark] = SkatePayData().landmarks
    
    func getLandmark() -> Landmark? {
        return landmarks.first { $0.npub == npub }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Marker Options")
                .font(.title2)
                .padding()
            
            Button(action: {
                showChatView = true
            }) {
                Text("Join Active Chat")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                dismiss()
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
        .fullScreenCover(isPresented: $showChatView) {
            let landmark = getLandmark()
            NavigationView {
                SpotFeed(npub: npub ?? "")
                    .navigationBarTitle("\(npub ?? "")")
                    .navigationBarItems(leading:
                                            Button(action: {
                        showChatView = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            
                            if let image = landmark?.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 35, height: 35)
                                    .clipShape(Circle())
                            }
                            if let name = landmark?.name {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(name)
                                        .fontWeight(.semibold)
                                        .font(.headline)
                                        .foregroundColor(.black)
                                }
                            }
                            Spacer()
                        }
                    }
                    )
            }
        }
        .padding()
    }
}
#Preview {
    MarkerOptions(npub: "", marks: [])
}
