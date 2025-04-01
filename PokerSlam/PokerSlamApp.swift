//
//  PokerSlamApp.swift
//  PokerSlam
//
//  Created by Akhil Dakinedi on 4/2/25.
//

import SwiftUI
import SwiftData

@main
struct PokerSlamApp: App {
    @StateObject private var gameState = GameState()
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environmentObject(gameState)
        }
    }
}

// Global state manager
class GameState: ObservableObject {
    @Published var currentScore: Int = 0
    @Published var highScore: Int = 0
    
    init() {
        // Load high score from UserDefaults
        highScore = UserDefaults.standard.integer(forKey: "highScore")
    }
    
    func updateHighScore() {
        if currentScore > highScore {
            highScore = currentScore
            UserDefaults.standard.set(highScore, forKey: "highScore")
        }
    }
}
