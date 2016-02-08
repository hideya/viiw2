//
//  BackgroundWindow.swift
//  viiw
//
//  Created by hideya kawahara on 2/6/16.
//  Copyright © 2016 hideya kawahara. All rights reserved.
//

import Cocoa

class BackgroundWindow : NSWindow {
    override init(contentRect: NSRect, styleMask aStyle: Int, backing bufferingType: NSBackingStoreType, `defer` flag: Bool) {
        super.init(contentRect: contentRect, styleMask: aStyle, backing: bufferingType, `defer`: flag)

        setFrameOrigin(CGPointZero)
        var mainScreenSize = NSScreen.mainScreen()!.frame.size
        mainScreenSize.height -= NSStatusBar.systemStatusBar().thickness
        setContentSize(mainScreenSize)

        collectionBehavior = [.Stationary, .Transient, .IgnoresCycle, .CanJoinAllSpaces]
        level = Int(CGWindowLevelForKey(CGWindowLevelKey.DesktopWindowLevelKey))
        orderBack(self)

        backgroundColor = NSColor.blackColor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var canBecomeMainWindow: Bool {
        get {
            return false
        }
    }

    override var canBecomeKeyWindow: Bool {
        get {
            return false
        }
    }

    override var acceptsFirstResponder: Bool {
        get {
            return false
        }
    }
}
