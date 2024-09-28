//
//  VideoPreviewView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/26/24.
//

import AVFoundation
import AVKit
import ConnectFramework
import SwiftUI

struct VideoPreviewView: View {
    var url: URL?
    
    @State private var player: AVPlayer
    
    init(url: URL?) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url!))
    }
    
    var body: some View {
        VStack {
            VideoPlayerView(player: player)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    player.play()
                }
        }
    }
}

#Preview {
    VideoPreviewView(url: nil)
}
