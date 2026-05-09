//
//  WatchSessionManager.swift
//  Super Fitness Coach Watch App
//

import Foundation
import WatchConnectivity
import os

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private let logger = Logger(subsystem: "com.superfitnesscoach.watch", category: "WatchSessionManager")

    @Published var recoveryScore: Int = 50
    @Published var statusIndicator: String = "yellow"
    @Published var exercises: [WatchExercise] = []

    /// Queue of completion updates to send when phone becomes reachable.
    private var pendingCompletions: [WatchCompletionUpdate] = []

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send Completion to Phone

    func sendExerciseCompletion(_ update: WatchCompletionUpdate) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        guard let data = try? JSONEncoder().encode(update) else {
            logger.error("Failed to encode WatchCompletionUpdate")
            return
        }

        let payload: [String: Any] = ["completionUpdate": data]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                self?.logger.warning("Message send failed, queuing: \(error.localizedDescription)")
                self?.pendingCompletions.append(update)
            }
        } else {
            // Use transferUserInfo for guaranteed delivery
            session.transferUserInfo(payload)
            logger.info("Queued completion via transferUserInfo: \(update.exerciseId)")
        }
    }

    private func flushPendingCompletions() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        for update in pendingCompletions {
            if let data = try? JSONEncoder().encode(update) {
                session.transferUserInfo(["completionUpdate": data])
            }
        }
        let count = pendingCompletions.count
        pendingCompletions.removeAll()
        if count > 0 {
            logger.info("Flushed \(count) pending completions to phone")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WCSession activated on watch")
            flushPendingCompletions()
        }
    }

    /// Receive context updates from the iOS app via transferUserInfo.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["watchContext"] as? Data else { return }

        do {
            let context = try JSONDecoder().decode(WatchContext.self, from: data)
            DispatchQueue.main.async { [weak self] in
                self?.recoveryScore = context.recoveryScore
                self?.statusIndicator = context.statusIndicator
                self?.exercises = context.exercises
            }
            logger.info("Received context from phone: score=\(context.recoveryScore)")
        } catch {
            logger.error("Failed to decode WatchContext: \(error.localizedDescription)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            flushPendingCompletions()
        }
    }
}
