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
    private var selectedCardPositions: [(row: Int, col: Int)] = []
    
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
            // If only one card is selected, deselect it
            if selectedCards.count == 1 {
                selectedCards.remove(card)
                selectedCardPositions.removeAll()
                deselectionFeedback.impactOccurred()
                currentLineType = nil
            } else {
                // If multiple cards are selected, deselect all
                selectedCards.removeAll()
                selectedCardPositions.removeAll()
                deselectionFeedback.impactOccurred()
                currentLineType = nil
            }
            updateEligibleCards()
        } else if isCardEligibleForSelection(card) {
            selectedCards.insert(card)
            if let position = findCardPosition(card) {
                selectedCardPositions.append(position)
            }
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
        
        // If we have a line type, check if the card is on that line and adjacent
        if let lineType = currentLineType {
            switch lineType {
            case .row(let row):
                guard cardPosition.row == row else { return false }
                // Check if card is adjacent to either end of the selection
                if let firstPosition = selectedCardPositions.first,
                   let lastPosition = selectedCardPositions.last {
                    return abs(cardPosition.col - firstPosition.col) == 1 || 
                           abs(cardPosition.col - lastPosition.col) == 1
                }
            case .column(let col):
                guard cardPosition.col == col else { return false }
                // Check if card is adjacent to either end of the selection
                if let firstPosition = selectedCardPositions.first,
                   let lastPosition = selectedCardPositions.last {
                    return abs(cardPosition.row - firstPosition.row) == 1 || 
                           abs(cardPosition.row - lastPosition.row) == 1
                }
            case .diagonal(let slope, let intercept):
                // For slope 1 (top-left to bottom-right): row - col = intercept
                // For slope -1 (top-right to bottom-left): row + col = intercept
                if slope == 1 {
                    guard cardPosition.row - cardPosition.col == intercept else { return false }
                } else {
                    guard cardPosition.row + cardPosition.col == intercept else { return false }
                }
                // Check if card is adjacent to either end of the selection
                if let firstPosition = selectedCardPositions.first,
                   let lastPosition = selectedCardPositions.last {
                    return (abs(cardPosition.row - firstPosition.row) == 1 && 
                            abs(cardPosition.col - firstPosition.col) == 1) ||
                           (abs(cardPosition.row - lastPosition.row) == 1 && 
                            abs(cardPosition.col - lastPosition.col) == 1)
                }
            }
        }
        
        // For the second card selection, determine the line type
        if selectedCards.count == 1 {
            guard let firstCardPosition = findCardPosition(Array(selectedCards)[0]) else { return false }
            
            // Check if cards are in the same row and adjacent
            if cardPosition.row == firstCardPosition.row {
                if abs(cardPosition.col - firstCardPosition.col) == 1 {
                    currentLineType = .row(cardPosition.row)
                    return true
                }
            }
            
            // Check if cards are in the same column and adjacent
            if cardPosition.col == firstCardPosition.col {
                if abs(cardPosition.row - firstCardPosition.row) == 1 {
                    currentLineType = .column(cardPosition.col)
                    return true
                }
            }
            
            // Check if cards are on the same diagonal and adjacent
            let topLeftIntercept = firstCardPosition.row - firstCardPosition.col
            let topRightIntercept = firstCardPosition.row + firstCardPosition.col
            
            // Check if the second card is on either diagonal and adjacent
            if cardPosition.row - cardPosition.col == topLeftIntercept {
                if abs(cardPosition.row - firstCardPosition.row) == 1 && 
                   abs(cardPosition.col - firstCardPosition.col) == 1 {
                    currentLineType = .diagonal(slope: 1, intercept: topLeftIntercept)
                    return true
                }
            }
            
            if cardPosition.row + cardPosition.col == topRightIntercept {
                if abs(cardPosition.row - firstCardPosition.row) == 1 && 
                   abs(cardPosition.col - firstCardPosition.col) == 1 {
                    currentLineType = .diagonal(slope: -1, intercept: topRightIntercept)
                    return true
                }
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
        
        // If we have a line type, show eligible cards based on selection count
        if let lineType = currentLineType {
            switch lineType {
            case .row(let row):
                // For single card, show adjacent cards in the row
                if selectedCards.count == 1 {
                    guard let position = selectedCardPositions.first else { return }
                    let adjacentCols = [position.col - 1, position.col + 1]
                    for col in adjacentCols where col >= 0 && col < 5 {
                        if let card = cards[row][col] {
                            eligibleCards.insert(card)
                        }
                    }
                } else {
                    // For multiple cards, show adjacent cards to both ends
                    guard let firstPosition = selectedCardPositions.first,
                          let lastPosition = selectedCardPositions.last else { return }
                    
                    let adjacentCols = [firstPosition.col - 1, lastPosition.col + 1]
                    for col in adjacentCols where col >= 0 && col < 5 {
                        if let card = cards[row][col] {
                            eligibleCards.insert(card)
                        }
                    }
                }
            case .column(let col):
                // For single card, show adjacent cards in the column
                if selectedCards.count == 1 {
                    guard let position = selectedCardPositions.first else { return }
                    let adjacentRows = [position.row - 1, position.row + 1]
                    for row in adjacentRows where row >= 0 && row < 5 {
                        if let card = cards[row][col] {
                            eligibleCards.insert(card)
                        }
                    }
                } else {
                    // For multiple cards, show adjacent cards to both ends
                    guard let firstPosition = selectedCardPositions.first,
                          let lastPosition = selectedCardPositions.last else { return }
                    
                    let adjacentRows = [firstPosition.row - 1, lastPosition.row + 1]
                    for row in adjacentRows where row >= 0 && row < 5 {
                        if let card = cards[row][col] {
                            eligibleCards.insert(card)
                        }
                    }
                }
            case .diagonal(let slope, let intercept):
                // For single card, show adjacent cards in the diagonal
                if selectedCards.count == 1 {
                    guard let position = selectedCardPositions.first else { return }
                    let adjacentPositions = [
                        (row: position.row - 1, col: position.col - 1),
                        (row: position.row - 1, col: position.col + 1),
                        (row: position.row + 1, col: position.col - 1),
                        (row: position.row + 1, col: position.col + 1)
                    ]
                    
                    for position in adjacentPositions where 
                        position.row >= 0 && position.row < 5 && 
                        position.col >= 0 && position.col < 5 {
                        
                        if slope == 1 {
                            if position.row - position.col == intercept {
                                if let card = cards[position.row][position.col] {
                                    eligibleCards.insert(card)
                                }
                            }
                        } else {
                            if position.row + position.col == intercept {
                                if let card = cards[position.row][position.col] {
                                    eligibleCards.insert(card)
                                }
                            }
                        }
                    }
                } else {
                    // For multiple cards, show adjacent cards to both ends
                    guard let firstPosition = selectedCardPositions.first,
                          let lastPosition = selectedCardPositions.last else { return }
                    
                    let adjacentPositions = [
                        (row: firstPosition.row - 1, col: firstPosition.col - 1),
                        (row: firstPosition.row - 1, col: firstPosition.col + 1),
                        (row: firstPosition.row + 1, col: firstPosition.col - 1),
                        (row: firstPosition.row + 1, col: firstPosition.col + 1),
                        (row: lastPosition.row - 1, col: lastPosition.col - 1),
                        (row: lastPosition.row - 1, col: lastPosition.col + 1),
                        (row: lastPosition.row + 1, col: lastPosition.col - 1),
                        (row: lastPosition.row + 1, col: lastPosition.col + 1)
                    ]
                    
                    for position in adjacentPositions where 
                        position.row >= 0 && position.row < 5 && 
                        position.col >= 0 && position.col < 5 {
                        
                        if slope == 1 {
                            if position.row - position.col == intercept {
                                if let card = cards[position.row][position.col] {
                                    eligibleCards.insert(card)
                                }
                            }
                        } else {
                            if position.row + position.col == intercept {
                                if let card = cards[position.row][position.col] {
                                    eligibleCards.insert(card)
                                }
                            }
                        }
                    }
                }
            }
        } else if selectedCards.count == 1 {
            // When only one card is selected and no line type is set,
            // show all adjacent cards in all possible directions
            guard let position = selectedCardPositions.first else { return }
            
            // Check adjacent positions in all directions
            let adjacentPositions = [
                // Row adjacent
                (row: position.row, col: position.col - 1),
                (row: position.row, col: position.col + 1),
                // Column adjacent
                (row: position.row - 1, col: position.col),
                (row: position.row + 1, col: position.col),
                // Diagonal adjacent
                (row: position.row - 1, col: position.col - 1),
                (row: position.row - 1, col: position.col + 1),
                (row: position.row + 1, col: position.col - 1),
                (row: position.row + 1, col: position.col + 1)
            ]
            
            for position in adjacentPositions where 
                position.row >= 0 && position.row < 5 && 
                position.col >= 0 && position.col < 5 {
                if let card = cards[position.row][position.col] {
                    eligibleCards.insert(card)
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
        } else {
            // Reset lastPlayedHand if no valid hand was detected
            lastPlayedHand = nil
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