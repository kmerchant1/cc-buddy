//
//  OffersView.swift
//  Boost
//
//  Created for TabView example
//

import SwiftUI

struct OffersView: View {
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Offers")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    OffersView()
        .preferredColorScheme(.dark)
} 