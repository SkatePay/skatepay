//
//  SpotRow.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/4/24.
//

import SwiftUI

struct SpotRow: View {
    var spot: Spot
    
    var body: some View {
        HStack {
            spot.image
                .resizable()
                .frame(width: 50, height: 50)
            Text(spot.name)
            
            Spacer()
            
            if spot.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }
}

#Preview {
    let spots = AppData().landmarks;
        
    return Group {
        SpotRow(spot: Spot(name: spots[0].name, address: spots[0].address, state: spots[0].state, icon: "", note: "", imageName: "venice-skate-park"))
        SpotRow(spot: Spot(name: spots[1].name, address: spots[1].address, state: spots[1].state, icon: "", note: "", imageName: "venice-skate-park"))
    }
}
