//
//  OAuth2+OSX.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 4/19/15.
//  Copyright 2015 Pascal Pfiffner
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa


extension OAuth2
{
	/**
	Uses `NSWorkspace` to open the authorize URL in the OS browser.
	
	- parameter params: Additional parameters to pass to the authorize URL
	:returs: A bool indicating success
	*/
	public final func openAuthorizeURLInBrowser(params: OAuth2StringDict? = nil) -> Bool {
		do {
			let url = try authorizeURL(params)
			return NSWorkspace.sharedWorkspace().openURL(url)
		}
		catch let err {
			logIfVerbose("Cannot open authorize URL: \(err)")
		}
		return false
	}
	
	
	// MARK: - Embedded View
	
	/**
	Tries to use the given context, which on OS X should be a NSViewController, to present the authorization screen.
	
	- returns: A bool indicating whether the method was able to show the authorize screen
	*/
	public func authorizeEmbeddedWith(config: OAuth2AuthConfig, params: OAuth2StringDict? = nil, autoDismiss: Bool = true) -> Bool {
		guard #available(OSX 10.11, *) else {
			logIfVerbose("authorizeEmbedded is only available for OS X 10.11 and later")
			return false
		}
		
		let controller = OAuth2WebViewController()
		controller.interceptURLString = redirect
		controller.onIntercept = { url in
			do {
				try self.handleRedirectURL(url)
				return true
			}
			catch let err {
				self.logIfVerbose("Cannot intercept redirect URL: \(err)")
			}
			return false
		}
		controller.onWillDismiss = { didCancel in
			if didCancel {
				self.didFail(nil)
			}
		}
		
		if let presentationBlock = config.authorizeContext {
			presentationBlock(webViewController: controller)
			return true
		}
		
		let window = NSWindow(contentRect: NSMakeRect(0, 0, OAuth2WebViewController.WebViewWindowWidth, OAuth2WebViewController.WebViewWindowHeight), styleMask: NSTitledWindowMask|NSClosableWindowMask|NSFullSizeContentViewWindowMask, backing: .Buffered, `defer`: false)
		window.backgroundColor = NSColor.whiteColor()
		window.movableByWindowBackground = true
		window.titlebarAppearsTransparent = true
		window.titleVisibility = .Hidden
		window.animationBehavior = .AlertPanel
		if let title = config.ui.title {
			window.title = title
		}
		let windowController = NSWindowController(window: window)
		authConfig.ui.windowController = windowController
		windowController.contentViewController = controller
		windowController.window?.center()
		windowController.showWindow(nil)
		
		do {
			let url = try authorizeURL(params)
			controller.startURL = url
		} catch let err {
			logIfVerbose("Cannot get authorize URL for embedded authorization: \(err)")
			return false
		}
		
		if autoDismiss {
			internalAfterAuthorizeOrFailure = { wasFailure, error in
				if !wasFailure {
					windowController.close()
				}
				
				self.authConfig.ui.windowController = nil
			}
		}
		
		return true
	}
	
	public func authorizeEmbeddedFrom(controller: NSViewController, params: OAuth2StringDict?) -> AnyObject {
		fatalError("Not yet implemented")
	}
}

