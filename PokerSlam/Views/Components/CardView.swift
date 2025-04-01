import SwiftUI

struct CardView: View {
    let card: Card
    let isSelected: Bool
    let isEligible: Bool
    let onTap: () -> Void
    
    @State private var borderOpacity: Double = 0.0
    
    var body: some View {
        Button(action: onTap) {
            // Fixed size container to maintain grid layout
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#191919"))
                    .frame(width: isSelected ? 64 : 60, height: isSelected ? 94 : 90)
                    .shadow(
                        color: Color(hex: "#191919").opacity(isSelected ? 0.5 : 0.3),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 4 : 1
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color(hex: "#d4d4d4") :
                                isEligible ? Color(hex: "#999999").opacity(borderOpacity) : Color.clear,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                
                // Card content
                VStack(spacing: 0) {
                    Text(card.rank.display)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: card.suit.color))
                    
                    Text(card.suit.rawValue)
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: card.suit.color))
                }
            }
            .frame(width: 64, height: 94) // Fixed container size
            .contentShape(Rectangle()) // Ensure the entire area is tappable
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .onAppear {
            if isEligible {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    borderOpacity = 1.0
                }
            }
        }
        .onChange(of: isEligible) { newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    borderOpacity = 1.0
                }
            } else {
                borderOpacity = 0.0
            }
        }
    }
}

#Preview {
    ZStack {
        MeshGradientBackground()
        
        HStack {
            CardView(
                card: Card(suit: .hearts, rank: .ace),
                isSelected: false,
                isEligible: false,
                onTap: {}
            )
            CardView(
                card: Card(suit: .spades, rank: .king),
                isSelected: true,
                isEligible: false,
                onTap: {}
            )
            CardView(
                card: Card(suit: .diamonds, rank: .queen),
                isSelected: false,
                isEligible: true,
                onTap: {}
            )
        }
        .padding()
    }
} 