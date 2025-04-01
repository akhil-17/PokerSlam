import Foundation
import SwiftUI

/// ViewModel responsible for managing the game state and logic
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var cards: [[Card?]] = Array(repeating: Array(repeating: nil, count: 5), count: 5)
    @Published private(set) var selectedCards: Set<Card> = []
    @Published private(set) var eligibleCards: Set<Card> = []
    @Published private(set) var score: Int = 0
    @Published var isGameOver = false
    @Published var lastPlayedHand: HandType?
    
    private var deck: [Card] = []
    private let selectionFeedback = UINotificationFeedbackGenerator()
    private let deselectionFeedback = UIImpactFeedbackGenerator(style: .light)
    private var currentLineType: LineType?
    
    private enum LineType {
        case row(Int)
        case column(Int)
        case diagonal(slope: Int, intercept: Int) // slope: 1 for top-left to bottom-right, -1 for top-right to bottom-left
    }
    
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
        updateEligibleCards() // Update eligible cards after dealing initial cards
    }
    
    /// Selects or deselects a card based on straight-line rules
    /// - Parameter card: The card to select or deselect
    func selectCard(_ card: Card) {
        if selectedCards.contains(card) {
            selectedCards.remove(card)
            deselectionFeedback.impactOccurred()
            
            // If we're down to one card or no cards, reset the line type
            if selectedCards.count <= 1 {
                currentLineType = nil
            }
            
            // Update eligible cards after any state changes
            updateEligibleCards()
        } else if isCardEligibleForSelection(card) {
            selectedCards.insert(card)
            selectionFeedback.notificationOccurred(.success)
            updateEligibleCards()
        } else {
            // Invalid selection - play error feedback
            selectionFeedback.notificationOccurred(.error)
        }
    }
    
    private func isCardEligibleForSelection(_ card: Card) -> Bool {
        if selectedCards.isEmpty { return true }
        
        guard let cardPosition = findCardPosition(card) else { return false }
        
        // If we have a line type, check if the card is on that line
        if let lineType = currentLineType {
            switch lineType {
            case .row(let row):
                return cardPosition.row == row
            case .column(let col):
                return cardPosition.col == col
            case .diagonal(let slope, let intercept):
                // For slope 1 (top-left to bottom-right): row - col = intercept
                // For slope -1 (top-right to bottom-left): row + col = intercept
                if slope == 1 {
                    return cardPosition.row - cardPosition.col == intercept
                } else {
                    return cardPosition.row + cardPosition.col == intercept
                }
            }
        }
        
        // For the second card selection, determine the line type
        if selectedCards.count == 1 {
            guard let firstCardPosition = findCardPosition(Array(selectedCards)[0]) else { return false }
            
            // Check if cards are in the same row
            if cardPosition.row == firstCardPosition.row {
                currentLineType = .row(cardPosition.row)
                return true
            }
            
            // Check if cards are in the same column
            if cardPosition.col == firstCardPosition.col {
                currentLineType = .column(cardPosition.col)
                return true
            }
            
            // Check if cards are on the same diagonal
            let topLeftIntercept = firstCardPosition.row - firstCardPosition.col
            let topRightIntercept = firstCardPosition.row + firstCardPosition.col
            
            // Check if the second card is on either diagonal
            if cardPosition.row - cardPosition.col == topLeftIntercept {
                currentLineType = .diagonal(slope: 1, intercept: topLeftIntercept)
                return true
            }
            
            if cardPosition.row + cardPosition.col == topRightIntercept {
                currentLineType = .diagonal(slope: -1, intercept: topRightIntercept)
                return true
            }
        }
        
        return false
    }
    
    private func updateEligibleCards() {
        eligibleCards.removeAll()
        
        if selectedCards.isEmpty {
            // If no cards are selected, all cards are eligible
            for row in 0..<5 {
                for col in 0..<5 {
                    if let card = cards[row][col] {
                        eligibleCards.insert(card)
                    }
                }
            }
            return
        }
        
        // If we have a line type and more than one card selected, only show eligible cards on that line
        if let lineType = currentLineType, selectedCards.count > 1 {
            switch lineType {
            case .row(let row):
                for col in 0..<5 {
                    if let card = cards[row][col] {
                        eligibleCards.insert(card)
                    }
                }
            case .column(let col):
                for row in 0..<5 {
                    if let card = cards[row][col] {
                        eligibleCards.insert(card)
                    }
                }
            case .diagonal(let slope, let intercept):
                // Check all positions in the grid
                for row in 0..<5 {
                    for col in 0..<5 {
                        if slope == 1 {
                            // For top-left to bottom-right: row - col = intercept
                            if row - col == intercept {
                                if let card = cards[row][col] {
                                    eligibleCards.insert(card)
                                }
                            }
                        } else {
                            // For top-right to bottom-left: row + col = intercept
                            if row + col == intercept {
                                if let card = cards[row][col] {
                                    eligibleCards.insert(card)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // When only one card is selected, show all cards in the same row, column, and diagonals
            guard let firstCardPosition = findCardPosition(Array(selectedCards)[0]) else { return }
            
            // Add all cards in the same row
            for col in 0..<5 {
                if let card = cards[firstCardPosition.row][col] {
                    eligibleCards.insert(card)
                }
            }
            
            // Add all cards in the same column
            for row in 0..<5 {
                if let card = cards[row][firstCardPosition.col] {
                    eligibleCards.insert(card)
                }
            }
            
            // Add all cards in the top-left to bottom-right diagonal
            let topLeftIntercept = firstCardPosition.row - firstCardPosition.col
            for row in 0..<5 {
                for col in 0..<5 {
                    if row - col == topLeftIntercept {
                        if let card = cards[row][col] {
                            eligibleCards.insert(card)
                        }
                    }
                }
            }
            
            // Add all cards in the top-right to bottom-left diagonal
            let topRightIntercept = firstCardPosition.row + firstCardPosition.col
            for row in 0..<5 {
                for col in 0..<5 {
                    if row + col == topRightIntercept {
                        if let card = cards[row][col] {
                            eligibleCards.insert(card)
                        }
                    }
                }
            }
        }
        
        // Remove any selected cards from eligible cards
        eligibleCards.subtract(selectedCards)
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
        let selectedCardsArray = Array(selectedCards)
        
        // Detect the poker hand
        if let handType = PokerHandDetector.detectHand(cards: selectedCardsArray) {
            lastPlayedHand = handType
            score += handType.rawValue
            
            // Remove selected cards
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
            currentLineType = nil
            updateEligibleCards() // Update eligible cards after playing hand
            
            // Check if game is over (no valid hands possible)
            checkGameOver()
        }
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
        eligibleCards.removeAll()
        score = 0
        isGameOver = false
        lastPlayedHand = nil
        setupDeck()
        dealInitialCards()
    }
} 