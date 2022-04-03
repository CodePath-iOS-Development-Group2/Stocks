//
//  ViewController.swift
//  StockTracker
//
//  Created by Ramyar Daneshgar & Marlon Cuna
//

import FloatingPanel
import UIKit


final class WatchListViewController: UIViewController {
   
    private var searchTimer: Timer?

  
    private var panel: FloatingPanelController?

    
    static var maxChangeWidth: CGFloat = 0

   
    private var watchlistMap: [String: [CandleStick]] = [:]

    
    private var viewModels: [WatchListTableViewCell.ViewModel] = []

   
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(WatchListTableViewCell.self,
                       forCellReuseIdentifier: WatchListTableViewCell.identifier)
        return table
    }()

    
    private var observer: NSObjectProtocol?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setUpSearchController()
        setUpTableView()
        fetchWatchlistData()
        setUpFloatingPanel()
        setUpTitleView()
        setUpObserver()
    }

   
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }

  
    private func setUpObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: .addedToWatchList,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.viewModels.removeAll()
            self?.fetchWatchlistData()
        }
    }

   
    private func fetchWatchlistData() {
        let symbols = PersistenceManager.shared.watchlist

        createPlaceholderViewModels()

        let group = DispatchGroup()

        for symbol in symbols where watchlistMap[symbol] == nil {
            group.enter()

            APICaller.shared.marketData(for: symbol) { [weak self] result in
                defer {
                    group.leave()
                }

                switch result {
                case .success(let data):
                    let candleSticks = data.candleSticks
                    self?.watchlistMap[symbol] = candleSticks
                case .failure(let error):
                    print(error)
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.createViewModels()
            self?.tableView.reloadData()
        }
    }

    private func createPlaceholderViewModels() {
        let symbols = PersistenceManager.shared.watchlist
        symbols.forEach { item in
            viewModels.append(
                .init(symbol: item,
                      companyName: UserDefaults.standard.string(forKey: item) ?? "Company",
                      price: "0.00",
                      changeColor: .systemGreen,
                      changePercentage: "0.00",
                      chartViewModel: .init(
                        data: [],
                        showLegend: false,
                        showAxis: false,
                        fillColor: .clear
                      )
                )
            )
        }

        self.viewModels = viewModels.sorted(by: { $0.symbol < $1.symbol })
        tableView.reloadData()
    }

   
    private func createViewModels() {
        var viewModels = [WatchListTableViewCell.ViewModel]()

        for (symbol, candleSticks) in watchlistMap {
            let changePercentage = candleSticks.getPercentage()

            viewModels.append(
                .init(
                    symbol: symbol,
                    companyName: UserDefaults.standard.string(forKey: symbol) ?? "Company",
                    price: getLatestClosingPrice(from: candleSticks),
                    changeColor: changePercentage < 0 ? .systemRed : .systemGreen,
                    changePercentage: .percentage(from: changePercentage),
                    chartViewModel: .init(
                        data: candleSticks.reversed().map { $0.close },
                        showLegend: false,
                        showAxis: false,
                        fillColor: changePercentage < 0 ? .systemRed : .systemGreen
                    )
                )
            )
        }

        self.viewModels = viewModels.sorted(by: { $0.symbol < $1.symbol })
    }

    
    private func getLatestClosingPrice(from data: [CandleStick]) -> String {
        guard let closingPrice = data.first?.close else {
            return ""
        }

        return .formatted(number: closingPrice)
    }

    
    private func setUpTableView() {
        view.addSubviews(tableView)
        tableView.delegate = self
        tableView.dataSource = self
    }

  
    private func setUpFloatingPanel() {
        let vc = NewsViewController(type: .topStories)
        let panel = FloatingPanelController(delegate: self)
        panel.surfaceView.backgroundColor = .secondarySystemBackground
        panel.set(contentViewController: vc)
        panel.addPanel(toParent: self)
        panel.track(scrollView: vc.tableView)
    }

  
    private func setUpTitleView() {
        let titleView = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: view.width,
                height: navigationController?.navigationBar.height ?? 100
            )
        )

        let label = UILabel(frame: CGRect(x: 10, y: 0, width: titleView.width-20, height: titleView.height))
        label.text = "StockTracker"
        label.font = .systemFont(ofSize: 40, weight: .medium)
        titleView.addSubview(label)

        navigationItem.titleView = titleView
    }

   
    private func setUpSearchController() {
        let resultVC = SearchResultsViewController()
        resultVC.delegate = self
        let searchVC = UISearchController(searchResultsController: resultVC)
        searchVC.searchResultsUpdater = self
        navigationItem.searchController = searchVC
    }

}

// MARK: - UISearchResultsUpdating

extension WatchListViewController: UISearchResultsUpdating {
    /// Update search on key tap
    /// - Parameter searchController: Ref of the search controlelr
    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text,
              let resultsVC = searchController.searchResultsController as? SearchResultsViewController,
              !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        // Reset timer
        searchTimer?.invalidate()

        // Kick off new timer
        // Optimize to reduce number of searches for when user stops typing
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { _ in
            // Call API to search
            APICaller.shared.search(query: query) { result in
                switch result {
                case .success(let response):
                    DispatchQueue.main.async {
                        resultsVC.update(with: response.result)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        resultsVC.update(with: [])
                    }
                    print(error)
                }
            }
        })
    }
}

// MARK: - SearchResultsViewControllerDelegate

extension WatchListViewController: SearchResultsViewControllerDelegate {
    /// Notify of search result selection
    /// - Parameter searchResult: Search result that was selected
    func searchResultsViewControllerDidSelect(searchResult: SearchResult) {
        navigationItem.searchController?.searchBar.resignFirstResponder()

        HapticsManager.shared.vibrateForSelection()

        let vc = StockDetailsViewController(
            symbol: searchResult.displaySymbol,
            companyName: searchResult.description
        )
        let navVC = UINavigationController(rootViewController: vc)
        vc.title = searchResult.description
        present(navVC, animated: true)
    }
}

// MARK: -FloatingPanelControllerDelegate

extension WatchListViewController: FloatingPanelControllerDelegate {
    /// Gets floating panel state change
    /// - Parameter fpc: Ref of controller
    func floatingPanelDidChangeState(_ fpc: FloatingPanelController) {
        navigationItem.titleView?.isHidden = fpc.state == .full
    }
}

// MARK: - TableView

extension WatchListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
                withIdentifier: WatchListTableViewCell.identifier,
                for: indexPath
        ) as? WatchListTableViewCell else {
            fatalError()
        }
        cell.delegate = self
        cell.configure(with: viewModels[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return WatchListTableViewCell.preferredHeight
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()

            // Update persistence
            PersistenceManager.shared.removeFromWatchlist(symbol: viewModels[indexPath.row].symbol)

            // Update viewModels
            viewModels.remove(at: indexPath.row)

            // Delete Row
            tableView.deleteRows(at: [indexPath], with: .automatic)

            tableView.endUpdates()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        HapticsManager.shared.vibrateForSelection()

        let viewModel = viewModels[indexPath.row]
        let vc = StockDetailsViewController(
            symbol: viewModel.symbol,
            companyName: viewModel.companyName,
            candleStickData: watchlistMap[viewModel.symbol] ?? []
        )
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
}



extension WatchListViewController: WatchListTableViewCellDelegate {
   
    func didUpdateMaxWidth() {
       
        tableView.reloadData()
    }
}
