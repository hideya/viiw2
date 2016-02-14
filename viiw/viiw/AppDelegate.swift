//
//  AppDelegate.swift
//  SwOsxTest
//
//  Created by hideya kawahara on 2/6/16.
//  Copyright © 2016 hideya. All rights reserved.
//

import Cocoa


private let projectWebSiteUrl = "http://hideya.github.io/viiw2/"
private let udkMotionStrength = "Motion Strength"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var statusMenuFirstItem: NSMenuItem!
    @IBOutlet weak var stautsMenuFirstView: NSBox!
    @IBOutlet weak var disableOnBatteryCheckbox: NSButton!
    @IBOutlet weak var strengthSlider: NSSlider!
    @IBOutlet weak var infoPanel: NSPanel!
    @IBOutlet weak var imageViewInfoPanel: NSImageView!
    @IBOutlet weak var suspensionInfoPanel: NSPanel!
    @IBOutlet weak var checkboxInfoPanel: NSPanel!

    private let userDefaults = NSUserDefaults.standardUserDefaults()
    private let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    private var enabled = true
    private var lastTimestamp: NSTimeInterval = 0
    private var prevPowerPlugged = true
    private var currentWallpaper = NSURL.init(string: "dummy")!
    private var currentScreenFrame = CGRect()

    private var motionStrength = 0.5
    private var mx: CGFloat = 0.0
    private var my: CGFloat = 0.0
    private var amx: CGFloat = 0.0
    private var amy: CGFloat = 0.0

    func applicationDidFinishLaunching(aNotification: NSNotification) {

        statusItem.image = NSImage.init(named: "StatusBarIcon")
        statusItem.menu = statusMenu
        statusMenuFirstItem.view = stautsMenuFirstView
        imageViewInfoPanel.image = NSImage.init(named: "AppIcon")

        motionStrength = userDefaults.doubleForKey(udkMotionStrength)
        if motionStrength == 0.0 {
            motionStrength = 0.5
            userDefaults.setDouble(motionStrength, forKey: udkMotionStrength)
        }

        strengthSlider.doubleValue = motionStrength
        print("slider value: \(motionStrength)")

        captureDesktopImageIfChanged()

        NSTimer.scheduledTimerWithTimeInterval(1.0 / 20, target: self, selector: "update", userInfo: nil, repeats: true)

        NSEvent.addGlobalMonitorForEventsMatchingMask([.MouseMovedMask, .LeftMouseDraggedMask, .RightMouseDraggedMask]) {event in

            if event.timestamp - self.lastTimestamp  > 1 {
                self.lastTimestamp = event.timestamp

                if !self.powerPlugged() {
                    let disableChecked = (self.disableOnBatteryCheckbox.state == NSOffState)
                    self.enabled = disableChecked
                    if self.prevPowerPlugged {
                        if !disableChecked {
                            self.showInfoOnRunningOnBattery()
                        }
                        self.prevPowerPlugged = false
                    }
                } else {
                    self.enabled = true
                    self.prevPowerPlugged = true
                }
                guard self.enabled else {
                    return
                }
                self.captureDesktopImageIfChanged()
            }

            // TBD: remove this event callback when disabled; use power and desktop background change notifications to reinitiate
            guard self.enabled else {
                return
            }

            let point = event.locationInWindow
            self.mx = point.x / self.window.frame.size.width - 0.5
            self.my = point.y / self.window.frame.size.height - 0.5
        }

        NSWorkspace.sharedWorkspace().notificationCenter.addObserver(self, selector: "spaceChanged", name: NSWorkspaceActiveSpaceDidChangeNotification, object: NSWorkspace.sharedWorkspace())

        // ref: http://stackoverflow.com/questions/31633503/fetch-the-battery-status-of-my-macbook-with-swift
        // ref: http://stackoverflow.com/questions/31895449/using-unsafemutablepointer-and-cfrunloopobservercontext-in-swift-2
        // ref: http://stackoverflow.com/questions/33294620/how-to-cast-self-to-unsafemutablepointervoid-type-in-swift
        /* TBD
        var _self = self
        withUnsafeMutablePointer(&_self) { (pSelf) -> Void in
            let runLoopSource = IOPSNotificationCreateRunLoopSource({ (pSelf) in
                // "A C function pointer cannot be formed from a closure that captures context"
                // let _self = ... pSelf
            }, UnsafeMutablePointer(pSelf))
            if let runLoopSource = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource.takeRetainedValue(), kCFRunLoopDefaultMode);
            }
        }
        */
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    func captureDesktopImageIfChanged() {
        guard window.onActiveSpace else {
            return
        }

        let newWallpaper = NSWorkspace.sharedWorkspace().desktopImageURLForScreen(NSScreen.mainScreen()!)!
        let newScreenFrame = NSScreen.mainScreen()!.frame

        if newWallpaper == currentWallpaper && CGRectEqualToRect(newScreenFrame, currentScreenFrame){
            return
        }

        let wallpaperImageOp = NSImage.desktopPicture()
        guard let wallpaperImage = wallpaperImageOp else {
            return
        }
        currentWallpaper = newWallpaper
        print("captured desktop image: \(currentWallpaper)")

        currentScreenFrame = NSScreen.mainScreen()!.frame;
        window.setFrame(currentScreenFrame, display: true)

        window.contentView!.wantsLayer = true
        let contentLayer = window.contentView!.layer!
        contentLayer.contents = wallpaperImage
    }

    func update() {
        guard window.onActiveSpace else {
            return
        }

        let prevAmx = amx
        let prevAmy = amy

        let windowWidth = window.frame.size.width
        let windowHeight = window.frame.size.height

        amx = amx * 0.95 + mx * 0.05
        amy = amy * 0.95 + my * 0.05

        if abs(prevAmx - amx) + abs(prevAmy - amy) < 0.001 {
            return
        }

        let strength = CGFloat(motionStrength)
        let persFactor: CGFloat =  2
        let scale: CGFloat      =  1 + 0.15 * strength
        let hFactor: CGFloat    = -0.05 * strength
        let hRotFactor: CGFloat =  0.07 * strength
        let vFactor: CGFloat    = -0.05 * strength
        let vRotFactor: CGFloat = -0.07 * strength

        let targetLeft = hFactor * amx * windowWidth
        let targetTop = vFactor * amy * windowWidth
        let targetRotH = hRotFactor * amx
        let targetRotV = vRotFactor * amy

        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / windowWidth * persFactor
        transform = CATransform3DScale(transform, scale, scale, scale)
        transform = CATransform3DTranslate(transform, targetLeft, targetTop, 0)
        transform = CATransform3DRotate(transform, targetRotV, 1.0, 0.0, 0.0)
        transform = CATransform3DRotate(transform, targetRotH, 0.0, 1.0, 0.0)
        transform = CATransform3DTranslate(transform, -windowWidth / 2, -windowHeight / 2, 0)

        let contentLayer = window.contentView!.layer!
        contentLayer.position = CGPointMake(windowWidth / 2, windowHeight / 2)
        contentLayer.transform = transform
    }

    func spaceChanged() {
        print("space changed")
        captureDesktopImageIfChanged()
    }

    // ref: http://stackoverflow.com/questions/31633503/fetch-the-battery-status-of-my-macbook-with-swift
    func powerPlugged() -> Bool {
        let timeRemaining: CFTimeInterval = IOPSGetTimeRemainingEstimate()
        return timeRemaining <= -2
    }

    func showInfoOnRunningOnBattery() {
        NSApp.activateIgnoringOtherApps(true)
        setWindowNextToStatusMenu(suspensionInfoPanel, xBias: 10, yBias: 10)
        suspensionInfoPanel.makeKeyAndOrderFront(self)
        checkboxInfoPanel.close()
        statusItem.popUpStatusItemMenu(self.statusMenu)
    }

    private func setWindowNextToStatusMenu(window: NSWindow, xBias: CGFloat, yBias: CGFloat) {
        let xRelativeToScreen = statusItem.button!.window!.convertRectToScreen(statusItem.button!.bounds).origin.x
        let infoWindowWidth = window.frame.size.width
        let infoWindowHeight = window.frame.size.height
        let mainScreenHeight = NSScreen.mainScreen()!.visibleFrame.size.height
        window.setFrameOrigin(CGPoint(x: xRelativeToScreen - infoWindowWidth - xBias, y: mainScreenHeight - infoWindowHeight - yBias))
    }

    @IBAction func checkBoxChanged(sender: AnyObject) {
        let state = (sender as! NSButton).state
        print("checkbox value: \(state)")

        if state == NSOffState {
            infoPanel.close()
            suspensionInfoPanel.close()
            NSApp.activateIgnoringOtherApps(true)
            setWindowNextToStatusMenu(checkboxInfoPanel, xBias: 10, yBias: 10)
            checkboxInfoPanel.makeKeyAndOrderFront(self)
            self.checkboxInfoPanel.animator().alphaValue = 1.0
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
                self.checkboxInfoPanel.animator().alphaValue = 0.0
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
                    self.checkboxInfoPanel.close()
                });
            });
        }
    }

    @IBAction func sliderChanged(sender: AnyObject) {
        let value = sender.doubleValue
        print("slider value: \(value)")

        motionStrength = value
        userDefaults.setDouble(motionStrength, forKey: udkMotionStrength)
        captureDesktopImageIfChanged()
    }

    @IBAction func showInfoPanel(sender: AnyObject) {
        suspensionInfoPanel.close()
        checkboxInfoPanel.close()
        NSApp.activateIgnoringOtherApps(true)
        setWindowNextToStatusMenu(infoPanel, xBias: 20, yBias: 20)
        infoPanel.makeKeyAndOrderFront(self)
    }

    @IBAction func showMoreInfo(sender: AnyObject) {
        infoPanel.close()
        suspensionInfoPanel.close()
        checkboxInfoPanel.close()
        NSWorkspace.sharedWorkspace().openURL(NSURL.init(string: projectWebSiteUrl)!)
    }

    @IBAction func quitButtonPressed(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(self)
    }
}


// ref: http://stackoverflow.com/questions/14099363/get-the-current-wallpaper-in-cocoa
extension NSImage {

    static func desktopPicture() -> NSImage? {

        let windows = CGWindowListCopyWindowInfo(
            CGWindowListOption.OptionOnScreenOnly,
            CGWindowID(0))! as NSArray

        var index = -1
        for var i = 0; i < windows.count; i++  {
            let window = windows[i]

            // we need windows owned by Dock
            let ownerOp = window["kCGWindowOwnerName"] as? String
            guard let owner = ownerOp where owner == "Dock" else {
                continue
            }

            // we need windows named like "Desktop Picture %"
            let nameOp = window["kCGWindowName"] as? String
            guard let name = nameOp where name.hasPrefix("Desktop Picture") else {
                continue
            }

            // wee need the one which belongs to the current screen
            let boundsOp = window["kCGWindowBounds"] as? NSDictionary
            guard let bounds = boundsOp else {
                continue
            }
            let x = bounds["X"] as! CGFloat
            if x == NSScreen.mainScreen()!.frame.origin.x {
                index = window["kCGWindowNumber"] as! Int
                break
            }
        }

        if index < 0 {
            return nil
        }

        let cgImage = CGWindowListCreateImage(
            CGRectZero,
            CGWindowListOption(arrayLiteral: CGWindowListOption.OptionIncludingWindow),
            CGWindowID(index),
            CGWindowImageOption.Default)!

        let image = NSImage(CGImage: cgImage, size: NSScreen.mainScreen()!.frame.size)
        return image
    }        
}

