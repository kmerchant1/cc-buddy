//
//  WalletCard+RewardRate.swift
//  Boost
//
//  Created for Reward Rate Calculation
//

import Foundation

// Extension for getting reward rate for a category
extension WalletCard {
    // Get the reward rate for a specific category
    func getRewardRate(for category: String) -> Double? {
        // Clean up and normalize the category
        let normalizedCategory = category.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct match in rewards dictionary
        if let directRate = rewards[normalizedCategory] {
            return directRate
        }
        
        // Check for alternative keys through category mapping
        if let mappedKeys = CategoryMapping.mappings.first(where: { 
            $0.key.lowercased() == normalizedCategory || 
            $0.value.contains(normalizedCategory)
        }) {
            // Check each possible key
            for key in mappedKeys.value {
                if let rate = rewards[key] {
                    return rate
                }
            }
            
            // Also check the display name as a key
            if let rate = rewards[mappedKeys.key.lowercased()] {
                return rate
            }
        }
        
        // Check for "other" category as fallback
        if let otherRate = rewards["other"] {
            return otherRate
        }
        
        // Default to 1% if nothing else matches
        return 1.0
    }
} 