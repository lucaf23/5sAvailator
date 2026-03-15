// WebContainerViewController.swift
// Renders locally-compatible pages using WKWebView.
// Use only for simple/static pages known to work on iOS 12 WebKit.

import UIKit
import WebKit

final class WebContainerViewController: UIViewController {

    // MARK: - Properties

    private let initialURL: URL
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var progressObservation: NSKeyValueObservation?

    // MARK: - Init

    init(url: URL, title: String) {
        self.initialURL = url
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupWebView()
        setupProgressView()
        setupToolbar()
        load(url: initialURL)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        progressObservation = nil
    }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        view.addSubview(webView)
    }

    private func setupProgressView() {
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
        ])
        progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
            let progress = Float(webView.estimatedProgress)
            self?.progressView.setProgress(progress, animated: true)
            self?.progressView.isHidden = progress >= 1.0
        }
    }

    private func setupToolbar() {
        let back = UIBarButtonItem(
            title: "‹ Back",
            style: .plain,
            target: self,
            action: #selector(goBack)
        )
        let reload = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(reloadPage)
        )
        navigationItem.rightBarButtonItems = [reload, back]
    }

    // MARK: - Actions

    @objc private func goBack() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func reloadPage() {
        webView.reload()
    }

    private func load(url: URL) {
        webView.load(URLRequest(url: url))
    }
}

// MARK: - WKNavigationDelegate

extension WebContainerViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        showError(error)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Navigation Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
