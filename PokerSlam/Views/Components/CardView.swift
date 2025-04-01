import SwiftUI

struct CardView: View {
    let card: Card
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: card.suit.color))
                    .frame(width: 60, height: 40)
                    .shadow(color: Color.black.opacity(0.3), radius: isSelected ? 4 : 2, x: 0, y: isSelected ? 4 : 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color(hex: "#d4d4d4") : Color.clear, lineWidth: 1)
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                
                VStack(spacing: 2) {
                    Text(card.rank.display)
                        .font(.system(size: 24, weight: .semibold))
                    Text(card.suit.rawValue)
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

#Preview {
    HStack {
        CardView(
            card: Card(suit: .hearts, rank: .ace),
            isSelected: false,
            onTap: {}
        )
        CardView(
            card: Card(suit: .spades, rank: .king),
            isSelected: true,
            onTap: {}
        )
    }
    .padding()
} 