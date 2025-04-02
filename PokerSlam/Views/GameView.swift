import SwiftUI

struct GameView: View {
    @StateObject private var viewModel = GameViewModel()
    @EnvironmentObject private var gameState: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var showingHandReference = false
    
    var body: some View {
        GameContainer(
            viewModel: viewModel,
            gameState: gameState,
            showingHandReference: $showingHandReference,
            dismiss: dismiss
        )
        .sheet(isPresented: $showingHandReference) {
            HandReferenceView()
        }
        .alert("Game Over", isPresented: $viewModel.isGameOver) {
            Button("Play Again") {
                // Update high score if current score is higher
                if viewModel.score > gameState.currentScore {
                    gameState.currentScore = viewModel.score
                }
                viewModel.resetGame()
            }
            Button("Main Menu") {
                // Update high score if current score is higher
                if viewModel.score > gameState.currentScore {
                    gameState.currentScore = viewModel.score
                }
                dismiss()
            }
        } message: {
            Text("No more valid hands possible!")
        }
    }
}

private struct GameContainer: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var gameState: GameState
    @Binding var showingHandReference: Bool
    let dismiss: DismissAction
    
    var body: some View {
        ZStack {
            MeshGradientBackground()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(viewModel.score > gameState.currentScore ? "New high score!" : "Score")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(viewModel.score)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingHandReference = true }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                // Main Content
                VStack(spacing: 20) {
                    CardGridView(viewModel: viewModel)
                    Spacer()
                }
                
                // Play Hand Button
                if viewModel.selectedCards.count >= 2 {
                    Button(action: {
                        viewModel.playHand()
                    }) {
                        Text("Play Hand")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black.opacity(0.3))
                    }
                    .padding()
                }
            }
        }
    }
}

private struct CardGridView: View {
    @ObservedObject var viewModel: GameViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { col in
                        if let card = viewModel.cards[row][col] {
                            CardView(
                                card: card,
                                isSelected: viewModel.selectedCards.contains(card),
                                isEligible: viewModel.eligibleCards.contains(card),
                                onTap: { viewModel.selectCard(card) }
                            )
                        }
                    }
                }
                .frame(height: 94) // Fixed height for each row
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            // Only unselect if there are selected cards
            if !viewModel.selectedCards.isEmpty {
                viewModel.unselectAllCards()
            }
        }
    }
}

struct HandReferenceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            MeshGradientBackground()
            
            VStack(spacing: 20) {
                Text("Poker Hands")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // 5-card hands
                        HandReferenceRow(
                            title: "Royal Flush",
                            description: "A, K, Q, J, 10 of same suit (e.g., A♥ K♥ Q♥ J♥ 10♥)",
                            score: "100"
                        )
                        HandReferenceRow(
                            title: "Straight Flush",
                            description: "Five consecutive cards of same suit (e.g., 9♠ 8♠ 7♠ 6♠ 5♠)",
                            score: "95"
                        )
                        HandReferenceRow(
                            title: "Full House",
                            description: "Three of a kind plus a pair (e.g., 3♣ 3♦ 3♥ 2♠ 2♣)",
                            score: "90"
                        )
                        HandReferenceRow(
                            title: "Flush",
                            description: "Five cards of same suit (e.g., A♦ 8♦ 6♦ 4♦ 2♦)",
                            score: "85"
                        )
                        HandReferenceRow(
                            title: "Straight",
                            description: "Five consecutive cards (e.g., 9♠ 8♥ 7♦ 6♣ 5♠)",
                            score: "80"
                        )
                        
                        // 4-card hands
                        HandReferenceRow(
                            title: "Four of a Kind",
                            description: "Four cards of same rank (e.g., 7♠ 7♥ 7♦ 7♣)",
                            score: "75"
                        )
                        HandReferenceRow(
                            title: "Nearly Royal Flush",
                            description: "J, Q, K, A of same suit (e.g., J♥ Q♥ K♥ A♥)",
                            score: "70"
                        )
                        HandReferenceRow(
                            title: "Nearly Flush",
                            description: "Four cards of same suit (e.g., A♠ K♠ Q♠ J♠)",
                            score: "65"
                        )
                        HandReferenceRow(
                            title: "Nearly Straight",
                            description: "Four consecutive cards (e.g., 5♠ 4♥ 3♦ 2♣)",
                            score: "60"
                        )
                        HandReferenceRow(
                            title: "Two Pair",
                            description: "Two different pairs (e.g., J♠ J♥ Q♣ Q♦)",
                            score: "55"
                        )
                        
                        // 3-card hands
                        HandReferenceRow(
                            title: "Three of a Kind",
                            description: "Three cards of same rank (e.g., 4♠ 4♥ 4♦)",
                            score: "50"
                        )
                        HandReferenceRow(
                            title: "Mini Royal Flush",
                            description: "J, Q, K of same suit (e.g., J♣ Q♣ K♣)",
                            score: "45"
                        )
                        HandReferenceRow(
                            title: "Mini Flush",
                            description: "Three cards of same suit (e.g., A♥ K♥ Q♥)",
                            score: "40"
                        )
                        HandReferenceRow(
                            title: "Mini Straight",
                            description: "Three consecutive cards (e.g., 3♠ 4♥ 5♦)",
                            score: "35"
                        )
                        
                        // 2-card hands
                        HandReferenceRow(
                            title: "One Pair",
                            description: "Two cards of same rank (e.g., 2♠ 2♥)",
                            score: "5"
                        )
                    }
                    .padding()
                }
                
                Button(action: { dismiss() }) {
                    Text("Close")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                }
                .padding(.bottom, 30)
            }
        }
    }
}

struct HandReferenceRow: View {
    let title: String
    let description: String
    let score: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(score)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Text(description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

#Preview {
    GameView()
        .environmentObject(GameState())
} 