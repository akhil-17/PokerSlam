import SwiftUI

struct CardView: View {
    let card: Card
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#191919"))
                    .frame(width: 60, height: 90)
                    .shadow(
                        color: Color(hex: "#191919").opacity(0.3),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 4 : 1
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color(hex: "#d4d4d4") : Color.clear, lineWidth: 1)
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