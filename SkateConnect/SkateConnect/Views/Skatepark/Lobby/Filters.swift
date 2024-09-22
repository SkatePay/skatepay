//
//  Filters.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import SwiftData
import SwiftUI

func friendlyKey(npub: String) -> String {
    return "skater-\(npub.suffix(3))"
}

struct Filters: View {
    @Query(sort: \Foe.birthday) private var foes: [Foe]
    @Environment(\.modelContext) private var context
    
    var body: some View {
        NavigationStack {
            if (foes.isEmpty) {
                Text("0 Muted Users")
            } else {
                List(foes) { foe in
                    HStack {
                        Text(friendlyKey(npub: foe.npub))
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = foe.npub
                                }) {
                                    Text("Copy npub")
                                }
                                Button(action: {
                                    context.delete(foe)
                                }) {
                                    Text("Unmute")
                                }
                            }
                        
                        Spacer()
                        
                    }
                }
            }
        }
    }
}

#Preview {
    Filters()
}
