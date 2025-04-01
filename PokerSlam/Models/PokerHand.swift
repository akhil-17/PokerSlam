import Foundation

/// Represents the different types of poker hands that can be formed
enum HandType: Int, Comparable {
    // 5-card hands (highest scoring)
    case royalFlush = 100
    case straightFlush = 95
    case fullHouse = 90
    case flush = 85
    case straight = 80
    
    // 4-card hands
    case fourOfAKind = 75
    case nearlyRoyalFlush = 70
    case nearlyFlush = 65
    case nearlyStraight = 60
    case twoPair = 55
    
    // 3-card hands
    case threeOfAKind = 50
    case miniRoyalFlush = 45
    case miniFlush = 40
    case miniStraight = 35
    
    // 2-card hands (lowest scoring)
    case onePair = 5
    
    static func < (lhs: HandType, rhs: HandType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Handles the detection and validation of poker hands
struct PokerHandDetector {
    /// Detects the highest-ranking valid poker hand from a set of cards
    /// - Parameter cards: Array of cards to evaluate
    /// - Returns: The highest-ranking valid hand type, or nil if no valid hand is found
    static func detectHand(cards: [Card]) -> HandType? {
        guard cards.count >= 2 else { return nil }
        
        // Sort cards by rank for easier evaluation
        let sortedCards = cards.sorted { $0.rank.rawValue < $1.rank.rawValue }
        
        // Check for royal flush first (highest ranking)
        if isRoyalFlush(cards: sortedCards) {
            return .royalFlush
        }
        
        // Check for nearly royal flush
        if isNearlyRoyalFlush(cards: sortedCards) {
            return .nearlyRoyalFlush
        }
        
        // Check for mini royal flush
        if isMiniRoyalFlush(cards: sortedCards) {
            return .miniRoyalFlush
        }
        
        // Check for straight flush
        if isStraightFlush(cards: sortedCards) {
            return .straightFlush
        }
        
        // Check for four of a kind
        if isFourOfAKind(cards: sortedCards) {
            return .fourOfAKind
        }
        
        // Check for full house
        if isFullHouse(cards: sortedCards) {
            return .fullHouse
        }
        
        // Check for flush
        if isFlush(cards: sortedCards) {
            return .flush
        }
        
        // Check for nearly flush
        if isNearlyFlush(cards: sortedCards) {
            return .nearlyFlush
        }
        
        // Check for mini flush
        if isMiniFlush(cards: sortedCards) {
            return .miniFlush
        }
        
        // Check for straight
        if isStraight(cards: sortedCards) {
            return .straight
        }
        
        // Check for nearly straight
        if isNearlyStraight(cards: sortedCards) {
            return .nearlyStraight
        }
        
        // Check for mini straight
        if isMiniStraight(cards: sortedCards) {
            return .miniStraight
        }
        
        // Check for three of a kind
        if isThreeOfAKind(cards: sortedCards) {
            return .threeOfAKind
        }
        
        // Check for two pair
        if isTwoPair(cards: sortedCards) {
            return .twoPair
        }
        
        // Check for one pair
        if isOnePair(cards: sortedCards) {
            return .onePair
        }
        
        // No valid hand found
        return nil
    }
    
    // MARK: - Individual Hand Checks
    
    private static func isRoyalFlush(cards: [Card]) -> Bool {
        guard cards.count == 5 else { return false }
        return isStraightFlush(cards: cards) && cards.last?.rank == .ace
    }
    
    private static func isNearlyRoyalFlush(cards: [Card]) -> Bool {
        guard cards.count == 4 else { return false }
        let suits = cards.map { $0.suit }
        guard Set(suits).count == 1 else { return false }
        
        let ranks = Set(cards.map { $0.rank })
        let requiredRanks: Set<Rank> = [.jack, .queen, .king, .ace]
        return ranks == requiredRanks
    }
    
    private static func isMiniRoyalFlush(cards: [Card]) -> Bool {
        guard cards.count == 3 else { return false }
        let suits = cards.map { $0.suit }
        guard Set(suits).count == 1 else { return false }
        
        let ranks = Set(cards.map { $0.rank })
        let requiredRanks: Set<Rank> = [.jack, .queen, .king]
        return ranks == requiredRanks
    }
    
    private static func isStraightFlush(cards: [Card]) -> Bool {
        guard cards.count == 5 else { return false }
        return isFlush(cards: cards) && isStraight(cards: cards)
    }
    
    private static func isFourOfAKind(cards: [Card]) -> Bool {
        guard cards.count == 4 else { return false }
        let ranks = cards.map { $0.rank }
        return Set(ranks).count == 1
    }
    
    private static func isFullHouse(cards: [Card]) -> Bool {
        guard cards.count == 5 else { return false }
        let ranks = cards.map { $0.rank }
        let uniqueRanks = Set(ranks)
        guard uniqueRanks.count == 2 else { return false }
        
        let firstRankCount = ranks.filter { $0 == ranks[0] }.count
        return firstRankCount == 2 || firstRankCount == 3
    }
    
    private static func isFlush(cards: [Card]) -> Bool {
        guard cards.count == 5 else { return false }
        let suits = cards.map { $0.suit }
        return Set(suits).count == 1
    }
    
    private static func isNearlyFlush(cards: [Card]) -> Bool {
        guard cards.count == 4 else { return false }
        let suits = cards.map { $0.suit }
        return Set(suits).count == 1
    }
    
    private static func isMiniFlush(cards: [Card]) -> Bool {
        guard cards.count == 3 else { return false }
        let suits = cards.map { $0.suit }
        return Set(suits).count == 1
    }
    
    private static func isStraight(cards: [Card]) -> Bool {
        guard cards.count == 5 else { return false }
        let ranks = cards.map { $0.rank.rawValue }
        
        // Check for consecutive ranks
        for i in 0...(ranks.count - 2) {
            if ranks[i + 1] - ranks[i] != 1 {
                return false
            }
        }
        return true
    }
    
    private static func isNearlyStraight(cards: [Card]) -> Bool {
        guard cards.count == 4 else { return false }
        let ranks = cards.map { $0.rank.rawValue }
        
        // Check for consecutive ranks
        for i in 0...(ranks.count - 2) {
            if ranks[i + 1] - ranks[i] != 1 {
                return false
            }
        }
        return true
    }
    
    private static func isMiniStraight(cards: [Card]) -> Bool {
        guard cards.count == 3 else { return false }
        let ranks = cards.map { $0.rank.rawValue }
        
        // Check for consecutive ranks
        for i in 0...(ranks.count - 2) {
            if ranks[i + 1] - ranks[i] != 1 {
                return false
            }
        }
        return true
    }
    
    private static func isThreeOfAKind(cards: [Card]) -> Bool {
        guard cards.count == 3 else { return false }
        let ranks = cards.map { $0.rank }
        return Set(ranks).count == 1
    }
    
    private static func isTwoPair(cards: [Card]) -> Bool {
        guard cards.count == 4 else { return false }
        let ranks = cards.map { $0.rank }
        let uniqueRanks = Set(ranks)
        return uniqueRanks.count == 2
    }
    
    private static func isOnePair(cards: [Card]) -> Bool {
        guard cards.count == 2 else { return false }
        return cards[0].rank == cards[1].rank
    }
} 