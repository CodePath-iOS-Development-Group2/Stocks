//
//  SearchResponse.swift
//  StockTracker
//
//  Created by Ramyar Daneshgar & Marlon Cuna
//

import Foundation


struct SearchResponse: Codable {
    let count: Int
    let result: [SearchResult]
}


struct SearchResult: Codable {
    let description: String
    let displaySymbol: String
    let symbol: String
    let type:  String
}
