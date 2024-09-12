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
    @EnvironmentObject var viewModel: ContentViewModel
    
    var npub: String?
    var marks: [Mark]
    
    @State private var showCreateChannel = false
    @State private var showChannelView = false
    
    var landmarks: [Landmark] = AppData().landmarks
    
    func getLandmark() -> Landmark? {
        return landmarks.first { $0.npub == npub }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Marker Options")
                .font(.title2)
                .padding()
            
            Button(action: {
                showChannelView = true
            }) {
                Text("Join Official Chat")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                showCreateChannel = true
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
        .fullScreenCover(isPresented: $showChannelView) {
            let landmark = getLandmark()
            
            if let landmark = getLandmark() {
                NavigationView {
                    ChannelFeed(eventId: landmark.eventId)
                        .navigationBarTitle("\(npub ?? "")")
                        .navigationBarItems(leading:
                                                Button(action: {
                            showChannelView = false
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                
                                landmark.image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 35, height: 35)
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(landmark.name) \(landmark.eventId.prefix(4))...\(landmark.eventId.suffix(4))")
                                        .fontWeight(.semibold)
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    
                                }
                                Spacer()
                            }
                        }
                        )
                }
            }
        }
        .fullScreenCover(isPresented: $showCreateChannel) {
            NavigationView {
                CreateChannel()
                    .navigationBarItems(leading:
                                            Button(action: {
                        showCreateChannel = false
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
    MarkerOptions(npub: "", marks: [])
}
