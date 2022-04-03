//
//  SearchResultTableViewCell.swift
//  StockTracker
//
//  Created Ramyar Daneshgar & Marlon Cuna
//

import UIKit


final class SearchResultTableViewCell: UITableViewCell {
   
    static let identifier = "SearchResultTableViewCell"

    

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
