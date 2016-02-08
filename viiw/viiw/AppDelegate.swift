//
//  AppDelegate.swift
//  SwOsxTest
//
//  Created by hideya kawahara on 2/6/16.
//  Copyright © 2016 hideya. All rights reserved.
//

import Cocoa


private let projectWebSiteUrl = "http://hideya.github.io/viiw/"
private let udkMotionMagnitude = "Motion Magnitude"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var statusMenuFirstItem: NSMenuItem!
    @IBOutlet weak var stautsMenuFirstView: NSBox!
    @IBOutlet weak var magnitudeSlider: NSSlider!
    @IBOutlet weak var infoPanel: NSPanel!
    @IBOutlet weak var imageViewInfoPanel: NSImageView!

    private let userDefaults = NSUserDefaults.standardUserDefaults()
    private let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    private var wallpaperUrl = NSURL.init(string: "dummy")!

    private var motionMagnitude = 0.5
    private var mx: CGFloat = 0.0
    private var my: CGFloat = 0.0
    private var amx: CGFloat = 0.0
    private var amy: CGFloat = 0.0

    func applicationDidFinishLaunching(aNotification: NSNotification) {

        statusItem.image = NSImage.init(named: "StatusBarIcon")
        statusItem.menu = statusMenu
        statusMenuFirstItem.view = stautsMenuFirstView
        imageViewInfoPanel.image = NSImage.init(named: "AppIcon")

        motionMagnitude = userDefaults.doubleForKey(udkMotionMagnitude)
        if motionMagnitude == 0.0 {
            motionMagnitude = 0.5
            userDefaults.setDouble(motionMagnitude, forKey: udkMotionMagnitude)
        }
        magnitudeSlider.doubleValue = motionMagnitude
        print("slider value: \(magnitudeSlider)")

        captureDesktopImageIfChanged()

        NSTimer.scheduledTimerWithTimeInterval(1.0 / 20, target: self, selector: "update", userInfo: nil, repeats: true)

        let windowWidth = window.frame.size.width
        let windowHeight = window.frame.size.height

        NSEvent.addGlobalMonitorForEventsMatchingMask([.MouseMovedMask, .LeftMouseDraggedMask, .RightMouseDraggedMask]) {event in
            let point = event.locationInWindow
            self.mx = point.x / windowWidth - 0.5
            self.my = point.y / windowHeight - 0.5
        }

        NSTimer.scheduledTimerWithTimeInterval(2.0, target: self, selector: "captureDesktopImageIfChanged", userInfo: nil, repeats: true)
    }

    func captureDesktopImageIfChanged() {
        guard window.onActiveSpace else {
            return
        }

        let newWallpaperUrl = NSWorkspace.sharedWorkspace().desktopImageURLForScreen(NSScreen.mainScreen()!)!
        if newWallpaperUrl == wallpaperUrl {
            return
        }
        wallpaperUrl = newWallpaperUrl
        print("capturing desktop image: \(wallpaperUrl)")

        let wallpaper = NSImage.desktopPicture()
        window.contentView!.wantsLayer = true
        let contentLayer = window.contentView!.layer!
        contentLayer.contents = wallpaper
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

        let mag = CGFloat(motionMagnitude)
        let persFactor: CGFloat = 2
        let scale: CGFloat      = 1 + 0.2 * mag
        let hFactor: CGFloat    = -0.05 * mag
        let hRotFactor: CGFloat = 0.1   * mag
        let vFactor: CGFloat    = -0.05 * mag
        let vRotFactor: CGFloat = -0.1  * mag

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

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    
    @IBAction func sliderChanged(sender: AnyObject) {
        let value = sender.doubleValue
        print("slider value: \(value)")
        motionMagnitude = value
        userDefaults.setDouble(motionMagnitude, forKey: udkMotionMagnitude)
        captureDesktopImageIfChanged()
    }

    @IBAction func showInfoPanel(sender: AnyObject) {
        let xRelativeToScreen = statusItem.button!.window!.convertRectToScreen(statusItem.button!.bounds).origin.x
        let infoWindowWidth = infoPanel.frame.size.width
        let mainScreenHeight = NSScreen.mainScreen()!.visibleFrame.size.height
        infoPanel.setFrameOrigin(CGPoint(x: xRelativeToScreen - infoWindowWidth - 10, y: mainScreenHeight))

        NSApp.activateIgnoringOtherApps(true)
        infoPanel.makeKeyAndOrderFront(self)
    }

    @IBAction func showMoreInfo(sender: AnyObject) {
        NSWorkspace.sharedWorkspace().openURL(NSURL.init(string: projectWebSiteUrl)!)
        infoPanel.close()
    }

    @IBAction func quitButtonPressed(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(self)
    }
}


// http://stackoverflow.com/questions/14099363/get-the-current-wallpaper-in-cocoa
extension NSImage {

    static func desktopPicture() -> NSImage {

        let windows = CGWindowListCopyWindowInfo(
            CGWindowListOption.OptionOnScreenOnly,
            CGWindowID(0))! as NSArray

        var index = 0
        for var i = 0; i < windows.count; i++  {
            let window = windows[i]

            // we need windows owned by Dock
            let owner = window["kCGWindowOwnerName"] as? String
            if let owner = owner where owner != "Dock" {
                continue
            }

            // we need windows named like "Desktop Picture %"
            let name = window["kCGWindowName"] as? String
            if let name = name where !name.hasPrefix("Desktop Picture") {
                continue
            }

            // wee need the one which belongs to the current screen
            let bounds = window["kCGWindowBounds"] as? NSDictionary
            if let bounds = bounds {
                let x = bounds["X"] as! CGFloat
                if x == NSScreen.mainScreen()!.frame.origin.x {
                    index = window["kCGWindowNumber"] as! Int
                    break
                }
            }
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

