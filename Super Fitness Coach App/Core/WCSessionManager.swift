//
//  WCSessionManager.swift
//  Super Fitness Coach App
//

import Foundation
import WatchConnectivity
import Combine
import os

final class WCSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WCSessionManager()

    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "WCSessionManager")

    /// Queue of updates to send when watch becomes reachable.
    private var pendingUpdates: [[String: Any]] = []

    /// Callback invoked on the main thread when an exercise completion arrives from the watch.
    var onExerciseCompletion: ((WatchCompletionUpdate) -> Void)?

    // MARK: - Activation

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send Context to Watch

    /// Send the current recovery score, status, and exercises to the watch.
    /// Uses `transferUserInfo` for guaranteed delivery even when the watch is not reachable.
    func sendContextToWatch(recoveryScore: Int, status: String, exercises: [WatchExercise]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            logger.warning("WCSession not activated, queuing context update")
            queueUpdate(recoveryScore: recoveryScore, status: status, exercises: exercises)
            return
        }

        let context = WatchContext(recoveryScore: recoveryScore, statusIndicator: status, exercises: exercises)
        do {
            let data = try JSONEncoder().encode(context)
            let payload: [String: Any] = ["watchContext": data]

            if session.isPaired && session.isWatchAppInstalled {
                session.transferUserInfo(payload)
                logger.info("Transferred context to watch: score=\(recoveryScore)")
            } else {
                logger.info("Watch not paired or app not installed, queuing update")
                pendingUpdates.append(payload)
            }
        } catch {
            logger.error("Failed to encode WatchContext: \(error.localizedDescription)")
        }
    }

    // MARK: - Message Queuing

    private func queueUpdate(recoveryScore: Int, status: String, exercises: [WatchExercise]) {
        let context = WatchContext(recoveryScore: recoveryScore, statusIndicator: status, exercises: exercises)
        guard let data = try? JSONEncoder().encode(context) else { return }
        pendingUpdates.append(["watchContext": data])
    }

    /// Flush any queued updates when the watch becomes reachable.
    private func flushPendingUpdates() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }

        for payload in pendingUpdates {
            session.transferUserInfo(payload)
        }
        let count = pendingUpdates.count
        pendingUpdates.removeAll()
        if count > 0 {
            logger.info("Flushed \(count) pending updates to watch")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WCSession activated: \(activationState.rawValue)")
            flushPendingUpdates()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WCSession deactivated, reactivating")
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            flushPendingUpdates()
        }
    }

    /// Handle messages received from the watch (exercise completions).
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["completionUpdate"] as? Data else {
            logger.warning("Received unknown message from watch")
            return
        }

        do {
            let update = try JSONDecoder().decode(WatchCompletionUpdate.self, from: data)
            logger.info("Received exercise completion from watch: \(update.exerciseId)")
            DispatchQueue.main.async { [weak self] in
                self?.onExerciseCompletion?(update)
            }
        } catch {
            logger.error("Failed to decode WatchCompletionUpdate: \(error.localizedDescription)")
        }
    }

    /// Handle user info transfers from the watch (exercise completions via guaranteed delivery).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["completionUpdate"] as? Data else { return }

        do {
            let update = try JSONDecoder().decode(WatchCompletionUpdate.self, from: data)
            logger.info("Received exercise completion (userInfo) from watch: \(update.exerciseId)")
            DispatchQueue.main.async { [weak self] in
                self?.onExerciseCompletion?(update)
            }
        } catch {
            logger.error("Failed to decode WatchCompletionUpdate from userInfo: \(error.localizedDescription)")
        }
    }
}
