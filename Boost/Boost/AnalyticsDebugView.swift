//
//  AnalyticsDebugView.swift
//  Boost
//
//  Created for debugging user analytics
//

import SwiftUI

struct AnalyticsDebugView: View {
    @State private var userMetrics: UserMetrics = UserMetrics()
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Total Cards Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("📊 Total Cards")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("\(userMetrics.totalCards)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                        }
                        
                        // Card Usage by Category Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("💳 Card Usage by Category")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if userMetrics.cardUsageByCategory.isEmpty {
                                Text("No usage data yet")
                                    .foregroundColor(.gray)
                                    .italic()
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(userMetrics.cardUsageByCategory.keys.sorted()), id: \.self) { cardKey in
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Card name header
                                            Text(cardKey.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.blue)
                                            
                                            // Categories for this card
                                            if let categories = userMetrics.cardUsageByCategory[cardKey], !categories.isEmpty {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    ForEach(Array(categories.keys.sorted()), id: \.self) { category in
                                                        HStack {
                                                            Text("• \(category)")
                                                                .foregroundColor(.white)
                                                            Spacer()
                                                            Text("\(categories[category] ?? 0)")
                                                                .fontWeight(.bold)
                                                                .foregroundColor(.green)
                                                        }
                                                    }
                                                }
                                                .padding(.leading, 16)
                                            } else {
                                                Text("• No categories used yet")
                                                    .foregroundColor(.gray)
                                                    .italic()
                                                    .padding(.leading, 16)
                                            }
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        
                        // Refresh Button
                        Button(action: {
                            loadAnalytics()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Data")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading)
                        
                        // Error Message
                        if let error = errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Analytics Debug")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadAnalytics()
            }
            .refreshable {
                loadAnalytics()
            }
        }
        .overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                        ProgressView("Loading...")
                            .padding()
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            }
        )
    }
    
    private func loadAnalytics() {
        isLoading = true
        errorMessage = nil
        
        UserAnalytics.shared.fetchUserMetrics { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let metrics):
                    userMetrics = metrics
                    print("📊 AnalyticsDebugView: Successfully loaded metrics")
                    print("   - Total Cards: \(metrics.totalCards)")
                    print("   - Card Usage by Category: \(metrics.cardUsageByCategory)")
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    print("❌ AnalyticsDebugView: Error loading analytics: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    AnalyticsDebugView()
        .preferredColorScheme(.dark)
} 