//
//  HapticsManager.swift
//  Stocks
//
//  Created by Ramyar Daneshgar & Marlon Cuna
//

import Foundation
import UIKit


final class HapticsManager {
    
    static let shared = HapticsManager()

    
    private init() {}

  
    public func vibrateForSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    
    public func vibrate(for type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
