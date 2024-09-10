//
//  LeadAnnotationView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import SwiftUI

struct LeadAnnotationView: View {
    let lead: Lead
    @Binding var isPressed: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isPressed ? Color.green.opacity(0.8) : Color.green)
            Text("🪣")
                .padding(5)
        }
        .scaleEffect(isPressed ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        .gesture(
            LongPressGesture(minimumDuration: 1.0)
                .onEnded { _ in
                    handleLongPress(lead: lead)
                }
                .onChanged { state in
                    print(state)
                }
        )
    }
    
    func handleLongPress(lead: Lead) {
        // Logic for handling long press
        print("Long press detected on lead: \(lead.name)")
    }
}

#Preview {
    LeadAnnotationView(lead: Lead(name: "Job", coordinate: SkatePayData().landmarks[0].locationCoordinate), isPressed: .constant(false))
}
