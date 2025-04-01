import Foundation
import SwiftUI

/// ViewModel responsible for managing the game state and logic
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var cards: [[Card?]] = Array(repeating: Array(repeating: nil, count: 5), count: 5)
    @Published private(set) var selectedCards: Set<Card> = []
    @Published private(set) var score: Int = 0
    @Published var isGameOver = false
    
    private var deck: [Card] = []
    
    init() {
        setupDeck()
        dealInitialCards()
    }
    
    private func setupDeck() {
        deck = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                deck.append(Card(suit: suit, rank: rank))
            }
        }
        deck.shuffle()
    }
    
    private func dealInitialCards() {
        for row in 0..<5 {
            for col in 0..<5 {
                if let card = deck.popLast() {
                    cards[row][col] = card
                }
            }
        }
    }
    
    /// Selects or deselects a card based on adjacency rules
    /// - Parameter card: The card to select or deselect
    func selectCard(_ card: Card) {
        if selectedCards.contains(card) {
            selectedCards.remove(card)
        } else if isCardAdjacentToSelection(card) {
            selectedCards.insert(card)
        }
    }
    
    private func isCardAdjacentToSelection(_ card: Card) -> Bool {
        if selectedCards.isEmpty { return true }
        
        guard let cardPosition = findCardPosition(card) else { return false }
        
        for selectedCard in selectedCards {
            guard let selectedPosition = findCardPosition(selectedCard) else { continue }
            
            let rowDiff = abs(cardPosition.row - selectedPosition.row)
            let colDiff = abs(cardPosition.col - selectedPosition.col)
            
            if (rowDiff == 1 && colDiff == 0) || // Same column, adjacent row
               (rowDiff == 0 && colDiff == 1) || // Same row, adjacent column
               (rowDiff == 1 && colDiff == 1) {  // Diagonal
                return true
            }
        }
        
        return false
    }
    
    private func findCardPosition(_ card: Card) -> (row: Int, col: Int)? {
        for row in 0..<5 {
            for col in 0..<5 {
                if cards[row][col]?.id == card.id {
                    return (row, col)
                }
            }
        }
        return nil
    }
    
    /// Plays the currently selected hand and updates the game state
    func playHand() {
        // TODO: Implement poker hand evaluation and scoring
        // For now, just remove selected cards and fill with new ones
        for card in selectedCards {
            if let position = findCardPosition(card) {
                cards[position.row][position.col] = nil
            }
        }
        
        // Fill empty spaces with new cards
        for row in 0..<5 {
            for col in 0..<5 {
                if cards[row][col] == nil {
                    cards[row][col] = deck.popLast()
                }
            }
        }
        
        selectedCards.removeAll()
        
        // Check if game is over (no valid hands possible)
        checkGameOver()
    }
    
    private func checkGameOver() {
        // TODO: Implement proper game over check
        // For now, just check if we have enough cards to continue
        if deck.isEmpty {
            isGameOver = true
        }
    }
    
    /// Resets the game to its initial state
    func resetGame() {
        cards = Array(repeating: Array(repeating: nil, count: 5), count: 5)
        selectedCards.removeAll()
        score = 0
        isGameOver = false
        setupDeck()
        dealInitialCards()
    }
} 