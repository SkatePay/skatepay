//
//  Blacklist.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import SwiftData
import SwiftUI

struct Blacklist: View {
    @Query(sort: \Foe.birthday) private var foes: [Foe]
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            if (foes.isEmpty) {
                Text("0 Foes")
            } else {
                List(foes) { foe in
                    HStack {
                        Text(foe.npub)
                            .contextMenu {
                                Button(action: {
                                    context.delete(foe)
                                }) {
                                    Text("Unblock")
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
    Blacklist()
}
