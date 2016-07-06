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


extension OAuth2 {
	
	/**
	Uses `NSWorkspace` to open the authorize URL in the OS browser.
	
	- parameter params: Additional parameters to pass to the authorize URL
	- throws: UnableToOpenAuthorizeURL on failure
	*/
	public final func openAuthorizeURLInBrowser(params: OAuth2StringDict? = nil) throws {
		let url = try authorizeURL(params: params)
		if !NSWorkspace.shared().open(url) {
			throw OAuth2Error.unableToOpenAuthorizeURL
		}
	}
	
	
	// MARK: - Embedded View
	
	/**
	Tries to use the given context, which on OS X should be a NSViewController, to present the authorization screen.
	
	You should use `authorizeEmbeddedFrom(<# NSWindow #>)` (to not use a sheet don't provide a window), use this method if you have specific
	reasons.
	
	- parameter config: The configuration to be used; usually uses the instance's `authConfig`
	- parameter params: Additional authorization parameters to supply during the OAuth dance
	- throws: Can throw several OAuth2Error if the method is unable to show the authorize screen
	*/
	public func authorizeEmbeddedWith(_ config: OAuth2AuthConfig, params: OAuth2StringDict? = nil) throws {
		guard #available(OSX 10.10, *) else {
			throw OAuth2Error.generic("Embedded authorizing is only available in OS X 10.10 and later")
		}
		
		// present as sheet
		if let window = config.authorizeContext as? NSWindow {
			try authorizeEmbeddedFromWindow(window, config: config, params: params)
		}
		
		// present in new window (or with custom block)
		else {
			try authorizeInNewWindow(config, params: params)
		}
	}
	
	/**
	Presents a modal sheet from the given window.
	
	- parameter window: The window from which to present the sheet
	- parameter config: The auth configuration to take into consideration
	- parameter params: Additional parameters to pass to the authorize URL
	- returns: The sheet that is being queued for presentation
	*/
	@available(OSX 10.10, *)
	@discardableResult
	public func authorizeEmbeddedFromWindow(_ window: NSWindow, config: OAuth2AuthConfig, params: OAuth2StringDict? = nil) throws -> NSWindow {
		let controller = try presentableAuthorizeViewController(params)
		controller.willBecomeSheet = true
		let sheet = windowControllerForViewController(controller, withConfiguration: config).window!
		
		if config.authorizeEmbeddedAutoDismiss {
			internalAfterAuthorizeOrFailure = { wasFailure, error in
				window.endSheet(sheet)
			}
		}
		window.makeKeyAndOrderFront(nil)
		window.beginSheet(sheet, completionHandler: nil)
		
		return sheet
	}
	
	/**
	Creates a new window, containing our `OAuth2WebViewController`, and centers it on the screen.
	
	- parameter config: The auth configuration to take into consideration
	- parameter params: Additional parameters to pass to the authorize URL
	*/
	@available(OSX 10.10, *)
	public func authorizeInNewWindow(_ config: OAuth2AuthConfig, params: OAuth2StringDict? = nil) throws {
		let controller = try presentableAuthorizeViewController(params)
		let windowController = windowControllerForViewController(controller, withConfiguration: config)
		authConfig.ui.windowController = windowController
		
		if config.authorizeEmbeddedAutoDismiss {
			internalAfterAuthorizeOrFailure = { wasFailure, error in
				controller.view.window?.close()
				self.authConfig.ui.windowController = nil
			}
		}
		windowController.window?.center()
		windowController.showWindow(nil)
	}
	
	/**
	Instantiates and configures an `OAuth2WebViewController`, ready to be used in a window.
	
	- parameter params: Additional parameters to pass to the authorize URL
	- returns: A web view controller that you can present to the user for login
	*/
	@available(OSX 10.10, *)
	public func presentableAuthorizeViewController(_ params: OAuth2StringDict? = nil) throws -> OAuth2WebViewController {
		let url = try authorizeURL(params: params)
		let controller = OAuth2WebViewController()
		controller.startURL = url
		controller.interceptURLString = redirect!
		controller.onIntercept = { url in
			do {
				try self.handleRedirectURL(url)
				return true
			}
			catch let error {
				self.logger?.warn("OAuth2", msg: "Cannot intercept redirect URL: \(error)")
			}
			return false
		}
		controller.onWillCancel = {
			self.didFail(nil)
		}
		return controller
	}
	
	/**
	Prepares a window controller with the given web view controller as content.
	
	- parameter controller: The web view controller to use as content
	- parameter withConfiguration: The auth config to use
	- returns: A window controller, ready to be presented
	*/
	@available(OSX 10.10, *)
	func windowControllerForViewController(_ controller: OAuth2WebViewController, withConfiguration config: OAuth2AuthConfig) -> NSWindowController {
		let rect = NSMakeRect(0, 0, OAuth2WebViewController.WebViewWindowWidth, OAuth2WebViewController.WebViewWindowHeight)
		let window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
		window.backgroundColor = NSColor.white()
		window.isMovableByWindowBackground = true
		window.titlebarAppearsTransparent = true
		window.titleVisibility = .hidden
		window.animationBehavior = .alertPanel
		if let title = config.ui.title {
			window.title = title
		}
		
		let windowController = NSWindowController(window: window)
		windowController.contentViewController = controller
		
		return windowController
	}
}

