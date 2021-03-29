//
//  ControlView.swift
//  Welcome Page
//
//  Created by Keeley Litzenberger on 2021-03-23.
//

//
//  ControlView.swift
//  VisionFaceTrack
//
//  Created by Keeley Litzenberger on 2021-03-09.
//  Copyright © 2021 Apple. All rights reserved.
//

import SwiftUI

struct ControlView: View {
    @Binding var showInfo: Bool

    var body: some View {

            ControllButton(systemIconName: "info.circle") {
                print("Info Button Pressed")
                self.showInfo.toggle()
            }.sheet(isPresented: $showInfo, content: {
                // InfoView
                InfoView(showInfo: $showInfo)
            })
            
            .frame(maxWidth: 500)
            .padding(10)
            .background(Color.black.opacity(0.25))

        }
    }


struct ControllButton: View {
    
    let systemIconName: String
    let action: () -> Void
    
    var body: some View {
        
        Button(action: {
            self.action()
        }){
            Image(systemName: systemIconName)
                .font(.system(size: 35))
                .foregroundColor(.white)
                .buttonStyle(PlainButtonStyle())
        }
//        .frame(width: 30, height: 30)
    }
}

