//
//  LeadOptions.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/10/24.
//

import SwiftUI

struct LeadOptions: View {
    @Environment(\.dismiss) private var dismiss

    var lead: Lead?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Lead Options")
                .font(.title2)
                .padding()
            
            if let name = lead?.name {
                Text("\(name)")
                    .padding()
            }

            Button(action: {
                dismiss()
            }) {
                Text("Read Instructions")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                dismiss()
            }) {
                Text("Claim Reward")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

#Preview {
    LeadOptions()
}
