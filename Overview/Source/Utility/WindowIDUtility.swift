/*
 Utility/WindowIDUtility.swift
 Overview

 Created by William Pierce on 02/20/25.

 Provides a utility function for extracting window IDs from Accessibility UI Elements,
 used by both SourceFocusService and SourceInfoService.
*/

import Cocoa

enum WindowIDUtility {
    /// Extracts the window ID from an Accessibility UI Element
    static func extractWindowID(from window: AXUIElement) -> CGWindowID {
        var windowID: CGWindowID = 0

        // Retrieve window ID using ApplicationServices framework
        typealias GetWindowFunc = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) ->
            AXError
        let frameworkHandle = dlopen(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW
        )

        guard let windowSymbol = dlsym(frameworkHandle, "_AXUIElementGetWindow") else {
            dlclose(frameworkHandle)
            return 0
        }

        let retrieveWindowIDFunction = unsafeBitCast(windowSymbol, to: GetWindowFunc.self)
        _ = retrieveWindowIDFunction(window, &windowID)
        dlclose(frameworkHandle)

        return windowID
    }
}
