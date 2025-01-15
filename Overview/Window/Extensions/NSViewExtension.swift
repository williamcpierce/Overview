/*
 Window/Extensions/NSViewExtension.swift
 Overview

 Created by William Pierce on 1/7/25.

 Provides type-safe view hierarchy traversal functionality.
*/

import AppKit

extension NSView {
    func ancestorOrSelf<T>(ofType type: T.Type) -> T? {
        if let self = self as? T {
            return self
        }
        return superview?.ancestorOrSelf(ofType: type)
    }
}
