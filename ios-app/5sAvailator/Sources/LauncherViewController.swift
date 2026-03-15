// LauncherViewController.swift
// Home screen showing configured services in a table view.
// Selecting a service opens it in the appropriate mode.

import UIKit

final class LauncherViewController: UITableViewController {

    // MARK: - Dependencies

    private let services: [ServiceDefinition]
    private let client: NetworkClient
    private let sessionStore: SessionStore

    // MARK: - Init

    init(services: [ServiceDefinition], client: NetworkClient, sessionStore: SessionStore) {
        self.services = services
        self.client = client
        self.sessionStore = sessionStore
        super.init(style: .plain)
        title = "5sAvailator"
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do not register the cell class here — cells are created manually with .subtitle style
        // so that detailTextLabel is available.
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Settings",
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        services.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ServiceCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ServiceCell")
        let service = services[indexPath.row]
        cell.textLabel?.text = service.name
        cell.detailTextLabel?.text = service.mode == .localWeb ? "Local" : "Remote"
        if #available(iOS 13.0, *) {
            cell.imageView?.image = UIImage(systemName: service.iconSystemName)
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let service = services[indexPath.row]
        switch service.mode {
        case .localWeb:
            openLocalWeb(service: service)
        case .remoteBrowser:
            openRemoteBrowser(service: service)
        }
    }

    // MARK: - Navigation

    private func openLocalWeb(service: ServiceDefinition) {
        guard let url = URL(string: service.url) else {
            showError("Invalid URL: \(service.url)")
            return
        }
        let vc = WebContainerViewController(url: url, title: service.name)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openRemoteBrowser(service: ServiceDefinition) {
        let vc = RemoteCanvasViewController(
            service: service,
            client: client,
            sessionStore: sessionStore
        )
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openSettings() {
        let alert = UIAlertController(
            title: "Settings",
            message: "Server: \(client.baseURL.absoluteString)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
