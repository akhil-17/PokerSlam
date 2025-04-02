import Foundation
import SwiftUI

/// Represents a card's position in the grid, including its current and target positions
struct CardPosition: Identifiable {
    let id = UUID()
    let card: Card
    var currentRow: Int
    var currentCol: Int
    var targetRow: Int
    var targetCol: Int
    
    init(card: Card, row: Int, col: Int) {
        self.card = card
        self.currentRow = row
        self.currentCol = col
        self.targetRow = row
        self.targetCol = col
    }
}

/// ViewModel responsible for managing the game state and logic
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var cardPositions: [CardPosition] = []
    @Published private(set) var selectedCards: Set<Card> = []
    @Published private(set) var eligibleCards: Set<Card> = []
    @Published private(set) var score: Int = 0
    @Published var isGameOver = false
    @Published var lastPlayedHand: HandType?
    @Published private(set) var isAnimating = false
    
    private var deck: [Card] = []
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let deselectionFeedback = UIImpactFeedbackGenerator(style: .light)
    private let errorFeedback = UINotificationFeedbackGenerator()
    private let successFeedback = UINotificationFeedbackGenerator()
    private let shiftFeedback = UIImpactFeedbackGenerator(style: .light)
    private let newCardFeedback = UIImpactFeedbackGenerator(style: .soft)
    private var currentLineType: LineType?
    private var selectedCardPositions: [(row: Int, col: Int)] = []
    
    private enum LineType {
        case row(Int)
        case column(Int)
        case diagonal(slope: Int, intercept: Int)
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
        cardPositions.removeAll()
        for row in 0..<5 {
            for col in 0..<5 {
                if let card = deck.popLast() {
                    cardPositions.append(CardPosition(card: card, row: row, col: col))
                }
            }
        }
        updateEligibleCards()
    }
    
    /// Gets the card at a specific position in the grid
    private func cardAt(row: Int, col: Int) -> Card? {
        return cardPositions.first { $0.currentRow == row && $0.currentCol == col }?.card
    }
    
    /// Gets all cards in the grid as a 2D array for compatibility with existing code
    private var cards: [[Card?]] {
        var grid = Array(repeating: Array(repeating: Card?.none, count: 5), count: 5)
        for position in cardPositions {
            grid[position.currentRow][position.currentCol] = position.card
        }
        return grid
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
            selectionFeedback.selectionChanged()
            updateEligibleCards()
        } else if !selectedCards.isEmpty {
            // If tapping an ineligible card with cards selected, unselect all
            unselectAllCards()
        } else {
            // Invalid selection - play error feedback
            errorFeedback.notificationOccurred(.error)
        }
    }
    
    /// Unselects all currently selected cards and resets the selection state
    func unselectAllCards() {
        selectedCards.removeAll()
        selectedCardPositions.removeAll()
        currentLineType = nil
        deselectionFeedback.impactOccurred()
        updateEligibleCards()
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
                
                // Check if card is adjacent to any part of the selection
                for position in selectedCardPositions {
                    if abs(cardPosition.row - position.row) == 1 && 
                       abs(cardPosition.col - position.col) == 1 {
                        return true
                    }
                }
                return false
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
            for position in cardPositions {
                eligibleCards.insert(position.card)
            }
            return
        }
        
        // If we have a line type, show eligible cards based on selection count
        if let lineType = currentLineType {
            switch lineType {
            case .row(let row):
                // Get all positions in the row that are adjacent to the selection
                let selectedCols = selectedCardPositions.map { $0.col }
                let minCol = selectedCols.min() ?? 0
                let maxCol = selectedCols.max() ?? 4
                
                // Add positions adjacent to the entire selection
                let adjacentCols = [minCol - 1, maxCol + 1]
                for col in adjacentCols where col >= 0 && col < 5 {
                    if let card = cardAt(row: row, col: col) {
                        eligibleCards.insert(card)
                    }
                }
                
            case .column(let col):
                // Get all positions in the column that are adjacent to the selection
                let selectedRows = selectedCardPositions.map { $0.row }
                let minRow = selectedRows.min() ?? 0
                let maxRow = selectedRows.max() ?? 4
                
                // Add positions adjacent to the entire selection
                let adjacentRows = [minRow - 1, maxRow + 1]
                for row in adjacentRows where row >= 0 && row < 5 {
                    if let card = cardAt(row: row, col: col) {
                        eligibleCards.insert(card)
                    }
                }
                
            case .diagonal(let slope, let intercept):
                // Get all positions on the diagonal that are adjacent to the selection
                let selectedPositions = selectedCardPositions
                let minRow = selectedPositions.map { $0.row }.min() ?? 0
                let maxRow = selectedPositions.map { $0.row }.max() ?? 4
                let minCol = selectedPositions.map { $0.col }.min() ?? 0
                let maxCol = selectedPositions.map { $0.col }.max() ?? 4
                
                // Calculate the direction of the diagonal
                let rowStep = (maxRow - minRow).signum()
                let colStep = (maxCol - minCol).signum()
                
                // Add positions adjacent to both ends of the selection
                let firstAdjacent = (row: minRow - rowStep, col: minCol - colStep)
                let lastAdjacent = (row: maxRow + rowStep, col: maxCol + colStep)
                
                let adjacentPositions = [firstAdjacent, lastAdjacent]
                
                // Also check positions adjacent to any card in the selection
                for position in selectedPositions {
                    let adjacentToPosition = [
                        (row: position.row - 1, col: position.col - 1),
                        (row: position.row - 1, col: position.col + 1),
                        (row: position.row + 1, col: position.col - 1),
                        (row: position.row + 1, col: position.col + 1)
                    ]
                    
                    for adjPosition in adjacentToPosition where 
                        adjPosition.row >= 0 && adjPosition.row < 5 && 
                        adjPosition.col >= 0 && adjPosition.col < 5 {
                        
                        if slope == 1 {
                            if adjPosition.row - adjPosition.col == intercept {
                                if let card = cardAt(row: adjPosition.row, col: adjPosition.col) {
                                    eligibleCards.insert(card)
                                }
                            }
                        } else {
                            if adjPosition.row + adjPosition.col == intercept {
                                if let card = cardAt(row: adjPosition.row, col: adjPosition.col) {
                                    eligibleCards.insert(card)
                                }
                            }
                        }
                    }
                }
                
                // Add the end positions
                for position in adjacentPositions where 
                    position.row >= 0 && position.row < 5 && 
                    position.col >= 0 && position.col < 5 {
                    
                    if slope == 1 {
                        if position.row - position.col == intercept {
                            if let card = cardAt(row: position.row, col: position.col) {
                                eligibleCards.insert(card)
                            }
                        }
                    } else {
                        if position.row + position.col == intercept {
                            if let card = cardAt(row: position.row, col: position.col) {
                                eligibleCards.insert(card)
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
                if let card = cardAt(row: position.row, col: position.col) {
                    eligibleCards.insert(card)
                }
            }
        }
        
        // Remove any selected cards from eligible cards
        eligibleCards.subtract(selectedCards)
    }
    
    private func findCardPosition(_ card: Card) -> (row: Int, col: Int)? {
        return cardPositions.first { $0.card.id == card.id }
            .map { ($0.currentRow, $0.currentCol) }
    }
    
    /// Plays the currently selected hand and updates the game state
    func playHand() {
        let selectedCardsArray = Array(selectedCards)
        
        // Detect the poker hand
        if let handType = PokerHandDetector.detectHand(cards: selectedCardsArray) {
            lastPlayedHand = handType
            score += handType.rawValue
            successFeedback.notificationOccurred(.success)
            
            // Get positions of selected cards
            let emptyPositions = selectedCards.compactMap { card in
                cardPositions.first { $0.card.id == card.id }
                    .map { ($0.currentRow, $0.currentCol) }
            }
            
            print("🔍 Debug: Selected cards positions to remove: \(emptyPositions)")
            
            // Remove selected cards
            cardPositions.removeAll { position in
                selectedCards.contains(position.card)
            }
            
            print("🔍 Debug: Remaining cards after removal: \(cardPositions.count)")
            
            // First, shift existing cards down
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7), ({
                shiftFeedback.impactOccurred()
                // Update target positions for shifting
                for (col, positions) in Dictionary(grouping: emptyPositions, by: { pos in pos.1 }) {
                    let highestEmptyRow = positions.map { $0.0 }.min() ?? 0
                    print("🔍 Debug: Column \(col) - Highest empty row: \(highestEmptyRow)")
                    
                    let cardsToShift = cardPositions.filter { position in
                        position.currentCol == col && position.currentRow < highestEmptyRow
                    }.sorted { $0.currentRow < $1.currentRow }
                    
                    print("🔍 Debug: Cards to shift in column \(col): \(cardsToShift.count)")
                    
                    for cardPosition in cardsToShift {
                        let emptyPositionsBelow = positions.filter { $0.0 > cardPosition.currentRow }.count
                        if let index = cardPositions.firstIndex(where: { $0.id == cardPosition.id }) {
                            cardPositions[index].targetRow = cardPosition.currentRow + emptyPositionsBelow
                            print("🔍 Debug: Shifting card from row \(cardPosition.currentRow) to \(cardPosition.currentRow + emptyPositionsBelow)")
                        }
                    }
                }
                
                // Update current positions to match target positions
                for index in cardPositions.indices {
                    cardPositions[index].currentRow = cardPositions[index].targetRow
                    cardPositions[index].currentCol = cardPositions[index].targetCol
                }
            }))
            
            // Calculate new empty positions at the top of each column
            var newEmptyPositions: [(Int, Int)] = []
            for (col, positions) in Dictionary(grouping: emptyPositions, by: { pos in pos.1 }) {
                let cardsRemovedFromColumn = positions.count
                // Add positions from top down for the number of cards removed
                for row in 0..<cardsRemovedFromColumn {
                    newEmptyPositions.append((row, col))
                }
            }
            
            // Then, after animation completes, add new cards to the new empty positions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7), ({
                    self.newCardFeedback.impactOccurred()
                    print("🔍 Debug: Starting to add new cards")
                    print("🔍 Debug: Remaining cards in deck: \(self.deck.count)")
                    print("🔍 Debug: New empty positions: \(newEmptyPositions)")
                    
                    for position in newEmptyPositions {
                        if let card = self.deck.popLast() {
                            print("🔍 Debug: Adding new card at row \(position.0), col \(position.1)")
                            self.cardPositions.append(CardPosition(card: card, row: position.0, col: position.1))
                        } else {
                            print("🔍 Debug: No more cards in deck to add")
                        }
                    }
                    print("🔍 Debug: Final card count: \(self.cardPositions.count)")
                    
                    // Update eligible cards after adding new cards
                    self.updateEligibleCards()
                }))
            }
            
            // Reset selection state
            selectedCards.removeAll()
            selectedCardPositions.removeAll()
            currentLineType = nil
            updateEligibleCards()
            
            // Check if game is over
            checkGameOver()
        } else {
            lastPlayedHand = nil
            errorFeedback.notificationOccurred(.error)
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
        cardPositions.removeAll()
        selectedCards.removeAll()
        eligibleCards.removeAll()
        score = 0
        isGameOver = false
        lastPlayedHand = nil
        setupDeck()
        dealInitialCards()
    }
}
