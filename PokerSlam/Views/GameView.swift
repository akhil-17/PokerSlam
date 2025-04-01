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
                viewModel.resetGame()
                gameState.currentScore = 0
            }
            Button("Main Menu") {
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
            
            VStack(spacing: 20) {
                ScoreDisplay(score: gameState.currentScore)
                CardGridView(viewModel: viewModel)
                GameControls(
                    viewModel: viewModel,
                    gameState: gameState,
                    showingHandReference: $showingHandReference,
                    dismiss: dismiss
                )
            }
        }
    }
}

private struct ScoreDisplay: View {
    let score: Int
    
    var body: some View {
        Text("Score: \(score)")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
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
                                onTap: { viewModel.selectCard(card) }
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }
}

private struct GameControls: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var gameState: GameState
    @Binding var showingHandReference: Bool
    let dismiss: DismissAction
    
    var body: some View {
        HStack {
            Button(action: { showingHandReference = true }) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            if !viewModel.selectedCards.isEmpty {
                Button(action: {
                    viewModel.playHand()
                    // TODO: Update score based on hand value
                    gameState.currentScore += 10
                }) {
                    Text("Play Hand")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                }
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
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
                        HandReferenceRow(
                            title: "Royal Flush",
                            description: "A, K, Q, J, 10 of same suit",
                            score: "100"
                        )
                        HandReferenceRow(
                            title: "Straight Flush",
                            description: "Five consecutive cards of same suit",
                            score: "90"
                        )
                        HandReferenceRow(
                            title: "Four of a Kind",
                            description: "Four cards of same rank",
                            score: "80"
                        )
                        HandReferenceRow(
                            title: "Full House",
                            description: "Three of a kind plus a pair",
                            score: "70"
                        )
                        HandReferenceRow(
                            title: "Flush",
                            description: "Five cards of same suit",
                            score: "60"
                        )
                        HandReferenceRow(
                            title: "Straight",
                            description: "Five consecutive cards",
                            score: "50"
                        )
                        HandReferenceRow(
                            title: "Three of a Kind",
                            description: "Three cards of same rank",
                            score: "40"
                        )
                        HandReferenceRow(
                            title: "Two Pair",
                            description: "Two different pairs",
                            score: "30"
                        )
                        HandReferenceRow(
                            title: "One Pair",
                            description: "Two cards of same rank",
                            score: "20"
                        )
                        HandReferenceRow(
                            title: "High Card",
                            description: "Highest card when no other hand",
                            score: "10"
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