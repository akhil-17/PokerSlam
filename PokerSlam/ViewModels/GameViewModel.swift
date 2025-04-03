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

extension Array {
    func combinations(ofCount count: Int) -> [[Element]] {
        guard count > 0 && count <= self.count else { return [] }
        
        if count == 1 {
            return self.map { [$0] }
        }
        
        var result: [[Element]] = []
        for i in 0...(self.count - count) {
            let first = self[i]
            let remaining = Array(self[(i + 1)...])
            let subCombinations = remaining.combinations(ofCount: count - 1)
            result.append(contentsOf: subCombinations.map { [first] + $0 })
        }
        return result
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
    @Published private(set) var lastPlayedHand: HandType?
    @Published private(set) var isAnimating = false
    @Published private(set) var currentHandText: String?
    @Published private(set) var isAnimatingHandText = false
    
    private var deck: [Card] = []
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let deselectionFeedback = UIImpactFeedbackGenerator(style: .light)
    private let errorFeedback = UINotificationFeedbackGenerator()
    private let successFeedback = UINotificationFeedbackGenerator()
    private let shiftFeedback = UIImpactFeedbackGenerator(style: .light)
    private let newCardFeedback = UIImpactFeedbackGenerator(style: .soft)
    private var selectedCardPositions: [(row: Int, col: Int)] = []
    
    /// Returns whether cards are currently interactive
    var areCardsInteractive: Bool {
        !isGameOver
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
    
    /// Selects or deselects a card based on adjacency rules
    /// - Parameter card: The card to select or deselect
    func selectCard(_ card: Card) {
        guard areCardsInteractive else { return }
        
        if selectedCards.contains(card) {
            // If only one card is selected, deselect it
            if selectedCards.count == 1 {
                selectedCards.remove(card)
                selectedCardPositions.removeAll()
                deselectionFeedback.impactOccurred()
            } else {
                // If multiple cards are selected, deselect all
                selectedCards.removeAll()
                selectedCardPositions.removeAll()
                deselectionFeedback.impactOccurred()
            }
            updateEligibleCards()
            updateCurrentHandText()
        } else if isCardEligibleForSelection(card) && selectedCards.count < 5 {
            selectedCards.insert(card)
            if let position = findCardPosition(card) {
                selectedCardPositions.append(position)
            }
            selectionFeedback.selectionChanged()
            updateEligibleCards()
            updateCurrentHandText()
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
        currentHandText = nil
        deselectionFeedback.impactOccurred()
        updateEligibleCards()
    }
    
    private func isCardEligibleForSelection(_ card: Card) -> Bool {
        if selectedCards.isEmpty { return true }
        
        guard let cardPosition = findCardPosition(card) else { return false }
        
        // Check if the card is adjacent to any of the currently selected cards
        for position in selectedCardPositions {
            if isAdjacent(position1: cardPosition, position2: position) {
                return true
            }
        }
        
        return false
    }
    
    private func isAdjacent(position1: (row: Int, col: Int), position2: (row: Int, col: Int)) -> Bool {
        let rowDiff = abs(position1.row - position2.row)
        let colDiff = abs(position1.col - position2.col)
        return rowDiff <= 1 && colDiff <= 1
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
        
        // Find all cards adjacent to any selected card
        for position in cardPositions {
            if isCardEligibleForSelection(position.card) {
                eligibleCards.insert(position.card)
            }
        }
        
        // Remove any selected cards from eligible cards
        eligibleCards.subtract(selectedCards)
    }
    
    private func findCardPosition(_ card: Card) -> (row: Int, col: Int)? {
        return cardPositions.first { $0.card.id == card.id }
            .map { ($0.currentRow, $0.currentCol) }
    }
    
    private func updateCurrentHandText() {
        guard !selectedCards.isEmpty else {
            currentHandText = nil
            return
        }
        
        let selectedCardsArray = Array(selectedCards)
        if let handType = PokerHandDetector.detectHand(cards: selectedCardsArray) {
            currentHandText = "\(handType.displayName) +\(handType.rawValue)"
        } else {
            currentHandText = nil
        }
    }
    
    /// Plays the currently selected hand and updates the game state
    func playHand() {
        let selectedCardsArray = Array(selectedCards)
        
        // Detect the poker hand
        if let handType = PokerHandDetector.detectHand(cards: selectedCardsArray) {
            lastPlayedHand = handType
            score += handType.rawValue
            successFeedback.notificationOccurred(.success)
            
            // Animate the hand text before proceeding
            isAnimatingHandText = true
            currentHandText = "\(handType.displayName) +\(handType.rawValue)"
            
            // Clear selection state immediately to prevent button from reappearing
            selectedCards.removeAll()
            selectedCardPositions.removeAll()
            
            // Get positions of selected cards
            let emptyPositions = selectedCardsArray.compactMap { card in
                cardPositions.first { $0.card.id == card.id }
                    .map { ($0.currentRow, $0.currentCol) }
            }
            
            print("🔍 Debug: Selected cards positions to remove: \(emptyPositions)")
            
            // Remove selected cards
            cardPositions.removeAll { position in
                selectedCardsArray.contains(position.card)
            }
            
            print("🔍 Debug: Remaining cards after removal: \(cardPositions.count)")
            
            // First, shift existing cards down
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7), ({
                shiftFeedback.impactOccurred()
                // Update target positions for shifting
                for (col, positions) in Dictionary(grouping: emptyPositions, by: { pos in pos.1 }) {
                    let highestEmptyRow = positions.map { $0.0 }.min() ?? 0
                    print("🔍 Debug: Column \(col) - Highest empty row: \(highestEmptyRow)")
                    
                    // Get all cards in this column that need to shift
                    let cardsToShift = cardPositions.filter { position in
                        position.currentCol == col && position.currentRow < highestEmptyRow
                    }.sorted { $0.currentRow < $1.currentRow }
                    
                    print("🔍 Debug: Cards to shift in column \(col): \(cardsToShift.count)")
                    
                    // For each card that needs to shift
                    for cardPosition in cardsToShift {
                        // Count how many empty positions are below this card
                        let emptyPositionsBelow = positions.filter { $0.0 > cardPosition.currentRow }.count
                        if let index = cardPositions.firstIndex(where: { $0.id == cardPosition.id }) {
                            // Shift the card down by the number of empty positions below it
                            let newRow = cardPosition.currentRow + emptyPositionsBelow
                            cardPositions[index].targetRow = newRow
                            print("🔍 Debug: Shifting card from row \(cardPosition.currentRow) to \(newRow)")
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
            
            // Sort empty positions by column then row to ensure consistent filling
            newEmptyPositions.sort { (pos1, pos2) in
                if pos1.1 == pos2.1 {
                    return pos1.0 < pos2.0
                }
                return pos1.1 < pos2.1
            }
            
            // Then, after animation completes, add new cards to the new empty positions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7), ({
                    self.newCardFeedback.impactOccurred()
                    print("🔍 Debug: Starting to add new cards")
                    print("🔍 Debug: Remaining cards in deck: \(self.deck.count)")
                    print("🔍 Debug: New empty positions: \(newEmptyPositions)")
                    
                    // Get all current cards sorted by column and row (bottom to top)
                    let currentCards = self.cardPositions.sorted { 
                        if $0.currentCol == $1.currentCol {
                            return $0.currentRow > $1.currentRow
                        }
                        return $0.currentCol < $1.currentCol
                    }
                    
                    // Remove all cards
                    self.cardPositions.removeAll()
                    
                    // Create a grid to track occupied positions
                    var occupiedPositions = Set<Int>()
                    
                    // First, try to place cards in their original columns, shifting down to fill gaps
                    for col in 0..<5 {
                        let columnCards = currentCards.filter { $0.currentCol == col }
                        let columnEmptyPositions = newEmptyPositions.filter { $0.1 == col }
                        
                        if !columnCards.isEmpty {
                            // Start from the bottom row and work up
                            var currentRow = 4
                            for cardPosition in columnCards {
                                while currentRow >= 0 {
                                    let position = (currentRow, col)
                                    let positionHash = currentRow * 5 + col
                                    // Only place card if position is not marked as empty (will be filled with new card)
                                    if !columnEmptyPositions.contains(where: { $0.0 == position.0 && $0.1 == position.1 }) && !occupiedPositions.contains(positionHash) {
                                        self.cardPositions.append(CardPosition(
                                            card: cardPosition.card,
                                            row: position.0,
                                            col: position.1
                                        ))
                                        occupiedPositions.insert(positionHash)
                                        currentRow -= 1
                                        break
                                    }
                                    currentRow -= 1
                                }
                            }
                        }
                    }
                    
                    // Then, fill any remaining gaps with cards from other columns
                    let remainingCards = currentCards.filter { cardPosition in
                        !self.cardPositions.contains { $0.card.id == cardPosition.card.id }
                    }
                    
                    // Sort remaining cards by row (bottom to top)
                    var sortedRemainingCards = remainingCards.sorted { $0.currentRow > $1.currentRow }
                    
                    // Fill gaps from bottom up
                    for row in (0..<5).reversed() {
                        for col in 0..<5 {
                            let positionHash = row * 5 + col
                            // Only fill if position is not occupied and not marked for new cards
                            if !occupiedPositions.contains(positionHash) && !newEmptyPositions.contains(where: { $0.0 == row && $0.1 == col }) {
                                if let cardPosition = sortedRemainingCards.first {
                                    self.cardPositions.append(CardPosition(
                                        card: cardPosition.card,
                                        row: row,
                                        col: col
                                    ))
                                    occupiedPositions.insert(positionHash)
                                    sortedRemainingCards.removeFirst()
                                    print("🔍 Debug: Filled gap at row \(row), col \(col) with card from another column")
                                }
                            }
                        }
                    }
                    
                    // Finally, add new cards from the deck to the empty positions at the top
                    var remainingEmptyPositions = newEmptyPositions
                    for position in newEmptyPositions {
                        if let card = self.deck.popLast() {
                            print("🔍 Debug: Adding new card at row \(position.0), col \(position.1)")
                            self.cardPositions.append(CardPosition(card: card, row: position.0, col: position.1))
                            remainingEmptyPositions.removeAll { $0.0 == position.0 && $0.1 == position.1 }
                        } else {
                            print("🔍 Debug: No more cards in deck to add")
                            break
                        }
                    }
                    
                    // If we have remaining empty positions and cards, shift cards down to fill them
                    if !remainingEmptyPositions.isEmpty && !sortedRemainingCards.isEmpty {
                        print("🔍 Debug: Shifting remaining cards to fill empty positions")
                        // Sort remaining empty positions by row (bottom to top)
                        let sortedEmptyPositions = remainingEmptyPositions.sorted { $0.0 > $1.0 }
                        
                        // Fill empty positions from bottom up with remaining cards
                        for position in sortedEmptyPositions {
                            if let cardPosition = sortedRemainingCards.first {
                                self.cardPositions.append(CardPosition(
                                    card: cardPosition.card,
                                    row: position.0,
                                    col: position.1
                                ))
                                sortedRemainingCards.removeFirst()
                                print("🔍 Debug: Filled empty position at row \(position.0), col \(position.1) with remaining card")
                            }
                        }
                    }
                    
                    print("🔍 Debug: Final card count: \(self.cardPositions.count)")
                    
                    // Update eligible cards after adding new cards
                    self.updateEligibleCards()
                }))
            }
            
            // Reset animation state and clear hand text after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isAnimatingHandText = false
                    self.currentHandText = nil
                }
                self.updateEligibleCards()
            }
            
            // Check if game is over
            checkGameOver()
        } else {
            lastPlayedHand = nil
            errorFeedback.notificationOccurred(.error)
        }
    }
    
    private func checkGameOver() {
        // Check if there are any valid poker hands possible in the current grid
        let allCards = cardPositions.map { $0.card }
        print("🔍 Debug: Checking for valid poker hands with \(allCards.count) cards")
        
        // Check all possible combinations of 2-5 cards
        for size in 2...5 {
            let combinations = allCards.combinations(ofCount: size)
            print("🔍 Debug: Checking combinations of size \(size), found \(combinations.count) combinations")
            
            for cards in combinations {
                if let handType = PokerHandDetector.detectHand(cards: cards) {
                    print("🔍 Debug: Found valid hand: \(handType.displayName)")
                    // Found a valid poker hand, game is not over
                    isGameOver = false
                    return
                }
            }
        }
        
        print("🔍 Debug: No valid poker hands found, game is over")
        // No valid poker hands found, game is over
        isGameOver = true
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
