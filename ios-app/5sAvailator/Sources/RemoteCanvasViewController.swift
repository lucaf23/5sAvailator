// RemoteCanvasViewController.swift
// Displays remote browser frames and forwards user input to the server.
// The app is a thin client: it polls for JPEG frames and maps touch → server coordinates.

import UIKit

/// Polling interval for frame refresh (milliseconds → seconds).
private let kFramePollInterval: TimeInterval = 0.5

final class RemoteCanvasViewController: UIViewController {

    // MARK: - Dependencies

    private let service: ServiceDefinition
    private let client: NetworkClient
    private let sessionStore: SessionStore

    // MARK: - State

    private var session: RemoteSession?
    private var pollTimer: Timer?
    private var isPolling = false

    // MARK: - UI

    private var frameImageView: UIImageView!
    private var activityIndicator: UIActivityIndicatorView!
    private var statusLabel: UILabel!
    private var inputToolbar: UIToolbar!
    private var inputField: UITextField!

    // MARK: - Init

    init(service: ServiceDefinition, client: NetworkClient, sessionStore: SessionStore) {
        self.service = service
        self.client = client
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
        title = service.name
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupFrameView()
        setupActivityIndicator()
        setupStatusLabel()
        setupGestures()
        setupToolbar()
        setupNavigationItems()
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPolling()
    }

    // MARK: - Setup

    private func setupFrameView() {
        frameImageView = UIImageView(frame: view.bounds)
        frameImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        frameImageView.contentMode = .scaleAspectFit
        frameImageView.backgroundColor = .black
        view.addSubview(frameImageView)
    }

    private func setupActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        activityIndicator.startAnimating()
    }

    private func setupStatusLabel() {
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 12)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        frameImageView.isUserInteractionEnabled = true
        frameImageView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        frameImageView.addGestureRecognizer(pan)
    }

    private func setupToolbar() {
        inputToolbar = UIToolbar()
        inputToolbar.translatesAutoresizingMaskIntoConstraints = false

        inputField = UITextField()
        inputField.borderStyle = .roundedRect
        inputField.placeholder = "Type text…"
        inputField.returnKeyType = .send
        inputField.delegate = self
        inputField.translatesAutoresizingMaskIntoConstraints = false

        let textItem = UIBarButtonItem(customView: inputField)
        let sendItem = UIBarButtonItem(
            title: "Send",
            style: .done,
            target: self,
            action: #selector(sendText)
        )
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        inputToolbar.items = [textItem, flex, sendItem]

        view.addSubview(inputToolbar)
        NSLayoutConstraint.activate([
            inputField.widthAnchor.constraint(equalToConstant: 180),
            inputToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func setupNavigationItems() {
        let closeBtn = UIBarButtonItem(
            barButtonSystemItem: .stop,
            target: self,
            action: #selector(closeSession)
        )
        let reloadBtn = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(reloadPage)
        )
        navigationItem.rightBarButtonItems = [closeBtn, reloadBtn]
    }

    // MARK: - Session lifecycle

    private func startSession() {
        statusLabel.text = "Connecting…"
        sessionStore.createSession(for: service) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let session):
                self.session = session
                self.activityIndicator.stopAnimating()
                self.statusLabel.text = nil
                self.startPolling()
            case .failure(let error):
                self.activityIndicator.stopAnimating()
                self.showError("Session failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func closeSession() {
        stopPolling()
        sessionStore.closeActiveSession { _ in }
        navigationController?.popViewController(animated: true)
    }

    @objc private func reloadPage() {
        guard let session = session else { return }
        client.navigate(sessionId: session.id, token: session.token, url: service.url) { [weak self] result in
            if case .failure(let err) = result {
                self?.showError("Reload failed: \(err.localizedDescription)")
            }
        }
    }

    // MARK: - Frame polling

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(
            timeInterval: kFramePollInterval,
            target: self,
            selector: #selector(pollFrame),
            userInfo: nil,
            repeats: true
        )
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc private func pollFrame() {
        guard let session = session, !isPolling else { return }
        isPolling = true
        client.getFrame(sessionId: session.id, token: session.token) { [weak self] result in
            guard let self = self else { return }
            self.isPolling = false
            switch result {
            case .success(let data):
                if let image = UIImage(data: data) {
                    self.frameImageView.image = image
                }
            case .failure(let error):
                self.showError("Frame error: \(error.localizedDescription)")
                self.stopPolling()
            }
        }
    }

    // MARK: - Gesture handlers

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let session = session else { return }
        let point = gesture.location(in: frameImageView)
        let server = mapToServerCoordinates(point: point, session: session)
        client.tap(sessionId: session.id, token: session.token, x: server.x, y: server.y) { [weak self] result in
            if case .failure(let err) = result {
                self?.showError("Tap failed: \(err.localizedDescription)")
            }
        }
    }

    private var panStartPoint: CGPoint = .zero

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let session = session else { return }
        switch gesture.state {
        case .began:
            panStartPoint = gesture.location(in: frameImageView)
        case .changed:
            let current = gesture.location(in: frameImageView)
            let delta = CGPoint(
                x: panStartPoint.x - current.x,
                y: panStartPoint.y - current.y
            )
            panStartPoint = current
            let origin = mapToServerCoordinates(point: current, session: session)
            let scale = serverScale(session: session)
            client.scroll(
                sessionId: session.id,
                token: session.token,
                x: origin.x,
                y: origin.y,
                deltaX: Double(delta.x * scale.x),
                deltaY: Double(delta.y * scale.y)
            ) { _ in }
        default:
            break
        }
    }

    // MARK: - Text input

    @objc private func sendText() {
        guard let session = session, let text = inputField.text, !text.isEmpty else { return }
        client.typeText(sessionId: session.id, token: session.token, text: text) { [weak self] result in
            if case .failure(let err) = result {
                self?.showError("Text input failed: \(err.localizedDescription)")
            }
        }
        inputField.text = nil
        inputField.resignFirstResponder()
    }

    // MARK: - Coordinate mapping

    /// Maps a point in the frameImageView to server viewport coordinates.
    private func mapToServerCoordinates(point: CGPoint, session: RemoteSession) -> (x: Double, y: Double) {
        let imageSize = frameImageView.bounds.size
        guard imageSize.width > 0, imageSize.height > 0 else { return (0, 0) }
        let scaleX = Double(session.viewportWidth) / Double(imageSize.width)
        let scaleY = Double(session.viewportHeight) / Double(imageSize.height)
        return (x: Double(point.x) * scaleX, y: Double(point.y) * scaleY)
    }

    private func serverScale(session: RemoteSession) -> CGPoint {
        let imageSize = frameImageView.bounds.size
        guard imageSize.width > 0, imageSize.height > 0 else { return CGPoint(x: 1, y: 1) }
        return CGPoint(
            x: CGFloat(session.viewportWidth) / imageSize.width,
            y: CGFloat(session.viewportHeight) / imageSize.height
        )
    }

    // MARK: - Error display

    private func showError(_ message: String) {
        statusLabel.text = message
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension RemoteCanvasViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendText()
        return true
    }
}
