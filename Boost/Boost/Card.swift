//
//  Card.swift
//  Boost
//
//  Created for Card model
//

import SwiftUI

struct Card: Identifiable, Equatable, Codable {
    let id = UUID()
    let issuer: String
    let cardType: String
    let userName: String = ""
    var rewards: [String: Int]?
    var imgURL: String? // Add imgURL property for card background image
    
    // Computed property to determine gradient based on issuer
    var gradientColors: [Color] {
        switch issuer {
        case "American Express", "Amex":
            return [Color.black, Color.yellow, Color.yellow.opacity(0.7)]
        case "Citi":
            return [Color.black, Color.green.opacity(0.8)]
        case "Chase":
            return [Color.black, Color.blue.opacity(0.8)]
        case "Discover":
            return [Color.black, Color.orange.opacity(0.8)]
        case "Capital One":
            return [Color.black, Color.red.opacity(0.8)]
        case "Bank of America":
            return [Color.black, Color.red.opacity(0.6), Color.blue.opacity(0.8)]
        case "U.S Bank":
            return [Color.black, Color.red.opacity(0.6), Color.blue.opacity(0.8)]
        case "Wells Fargo":
            return [Color.black, Color.red.opacity(0.7), Color.yellow.opacity(0.8)]
        case "Synchrony":
            return [Color.black, Color.blue.opacity(0.4)]
        case "Barclays":
            return [Color.black, Color.blue.opacity(0.4)]
        default:
            return [Color.black, Color.gray.opacity(1)]
        }
    }
    
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.issuer == rhs.issuer && lhs.cardType == rhs.cardType
    }
}

// Virtual card for default
extension Card {
    static let virtualCard = Card(issuer: "Virtual", cardType: "Debit Card", imgURL: nil)
} 