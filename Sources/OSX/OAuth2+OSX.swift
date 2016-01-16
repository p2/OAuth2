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
import WebKit


extension OAuth2 {
	
	/**
	Uses `NSWorkspace` to open the authorize URL in the OS browser.
	
	- parameter params: Additional parameters to pass to the authorize URL
	- throws: UnableToOpenAuthorizeURL on failure
	*/
	public final func openAuthorizeURLInBrowser(params: OAuth2StringDict? = nil) throws {
		let url = try authorizeURL(params)
		if !NSWorkspace.sharedWorkspace().openURL(url) {
			throw OAuth2Error.UnableToOpenAuthorizeURL
		}
	}
	
	
	// MARK: - Authorize Embedded
	
	/**
	Tries to use the given context, which on OS X should be a NSViewController, to present the authorization screen.
	
	- throws: Can throw several OAuth2Error if the method is unable to show the authorize screen
	 */
	
	@available(iOS 10.10, *)
	public func authorizeEmbeddedWith(config: OAuth2AuthConfig, params: OAuth2StringDict? = nil) throws {
		if let controller = config.authorizeContext as? NSViewController {
			let web: OAuth2WkWebViewController = try authorizeEmbeddedFrom(controller, params: params)
			if config.authorizeEmbeddedAutoDismiss {
				internalAfterAuthorizeOrFailure = { wasFailure, error in
					self.logIfVerbose("Should now dismiss \(web)")
				}
			}
			return
		}
		throw (nil == config.authorizeContext) ? OAuth2Error.NoAuthorizationContext : OAuth2Error.InvalidAuthorizationContext

	}
	
	
	// MARK: - WKWeb View Controller
	
	/**
	Presents a OAuth2WKWebViewController from the supplied view controller, loading the authorize URL.
	
	The mechanism works differently from using Safari itself to log the user in, and unlike the iOS SafariWebViewCOntroller, 
	there is **NO need to implement** `application(application:openURL:sourceApplication:annotation:)` in your application delegate.
	
	The View controller is dismissed automatically
	
	- parameter controller: The view controller to use for presentation
	- parameter params: Optional additional URL parameters
	- returns: OAuth2WKWebViewController, being already presented automatically
	*/
	
	@available(iOS 10.10, *)
	public func authorizeEmbeddedFrom(controller: NSViewController, params: OAuth2StringDict?) throws -> OAuth2WkWebViewController {
		let url = try authorizeURL(params)
		return presentWKWebViewFor(url, from: controller)
	}
	
	@available(iOS 10.10, *)
	final func presentWKWebViewFor(url: NSURL, from: NSViewController) -> OAuth2WkWebViewController {
		
		//Create a view controller containing a wkwebview
		let vc = OAuth2WkWebViewController(startURL: url)
		vc.title = authConfig.ui.title
		
		from.presentViewControllerAsModalWindow(vc)
		return vc
	
		// Fallback on earlier versions
	}

	func wkWebViewControllerDidCancel() {
		didFail(nil)
	}
}
