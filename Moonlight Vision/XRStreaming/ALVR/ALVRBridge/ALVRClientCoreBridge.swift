//
//  ALVRClientCoreBridge.swift
//  Moonlight Vision
//
//  Bridge skeleton for the generated ALVRClientCore.xcframework.
//

import Foundation

#if canImport(ALVRClientCore)
import ALVRClientCore
#endif

struct SymbolSmokeResult {
    let success: Bool
    let messages: [String]
    let pathId: UInt64?
    let errorDescription: String?
}

@MainActor
final class ALVRClientCoreBridge {
    static let shared = ALVRClientCoreBridge()

    var isFrameworkAvailable: Bool {
        #if canImport(ALVRClientCore)
        true
        #else
        false
        #endif
    }

    var frameworkStatusDescription: String {
        #if canImport(ALVRClientCore)
        "ALVRClientCore import: available"
        #else
        "ALVRClientCore import: unavailable"
        #endif
    }

    private init() {}

    func runSymbolSmokeTest() -> SymbolSmokeResult {
        #if canImport(ALVRClientCore)
        alvr_initialize_logging()

        let pathId = "/user/head".withCString { pathPointer in
            alvr_path_string_to_id(pathPointer)
        }

        "Moonlight Vision ALVR symbol smoke test".withCString { messagePointer in
            alvr_log(AlvrLogLevel(ALVR_LOG_LEVEL_INFO.rawValue), messagePointer)
        }

        return SymbolSmokeResult(
            success: true,
            messages: [
                "ALVRClientCore import available",
                "Called alvr_initialize_logging()",
                "Called alvr_path_string_to_id(\"/user/head\")",
                "Called alvr_log(ALVR_LOG_LEVEL_INFO, ...)"
            ],
            pathId: pathId,
            errorDescription: nil
        )
        #else
        return SymbolSmokeResult(
            success: false,
            messages: ["ALVRClientCore import unavailable"],
            pathId: nil,
            errorDescription: "ALVRClientCore is not available to this target."
        )
        #endif
    }

    func initializePlaceholder() {
        // TODO: Bridge alvr_initialize once the framework is linked and symbols are verified.
    }

    func resumePlaceholder() {
        // TODO: Bridge alvr_resume once lifecycle ownership is isolated from the upstream app.
    }

    func pollEventPlaceholder() {
        // TODO: Bridge alvr_poll_event into ALVRSessionManager's event loop.
    }

    func stopPlaceholder() {
        // TODO: Bridge alvr_pause and alvr_destroy for teardown.
    }

    // TODO: Bridge alvr_initialize.
    // TODO: Bridge alvr_resume.
    // TODO: Bridge alvr_pause.
    // TODO: Bridge alvr_destroy.
    // TODO: Bridge alvr_poll_event.
    // TODO: Bridge alvr_send_tracking_and_face_data.
    // TODO: Bridge alvr_send_views_config.
}
