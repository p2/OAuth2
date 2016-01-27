//
//  OAuth2+iOS.swift
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

import UIKit
import SafariServices


extension OAuth2 {
	
	/**
	Uses `UIApplication` to open the authorize URL in iOS's browser.
	
	- parameter params: Additional parameters to pass to the authorize URL
	- throws: UnableToOpenAuthorizeURL on failure
	*/
	public final func openAuthorizeURLInBrowser(params: OAuth2StringDict? = nil) throws {
		let url = try authorizeURL(params)
		if !UIApplication.sharedApplication().openURL(url) {
			throw OAuth2Error.UnableToOpenAuthorizeURL
		}
	}
	
	
	// MARK: - Authorize Embedded
	
	/**
	Tries to use the current auth config context, which on iOS should be a UIViewController, to present the authorization screen.
	
	- throws: Can throw several OAuth2Error if the method is unable to show the authorize screen
	*/
	public func authorizeEmbeddedWith(config: OAuth2AuthConfig, params: OAuth2StringDict? = nil) throws {
		if let controller = config.authorizeContext as? UIViewController {
			if #available(iOS 9, *), config.ui.useSafariView {
				let web = try authorizeSafariEmbeddedFrom(controller, params: params)
				if config.authorizeEmbeddedAutoDismiss {
					internalAfterAuthorizeOrFailure = { wasFailure, error in
						web.dismissViewControllerAnimated(true, completion: nil)
					}
				}
				return
			}
			let web = try authorizeEmbeddedFrom(controller, params: params)
			if config.authorizeEmbeddedAutoDismiss {
				internalAfterAuthorizeOrFailure = { wasFailure, error in
					web.dismissViewControllerAnimated(true, completion: nil)
				}
			}
			return
		}
		throw (nil == config.authorizeContext) ? OAuth2Error.NoAuthorizationContext : OAuth2Error.InvalidAuthorizationContext
	}
	
	
	// MARK: - Safari Web View Controller
	
	/**
	Presents a Safari view controller from the supplied view controller, loading the authorize URL.
	
	The mechanism works just like when you're using Safari itself to log the user in, hence you **need to implement**
	`application(application:openURL:sourceApplication:annotation:)` in your application delegate.
	
	This method does NOT dismiss the view controller automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure.
	Simply call this method first, then call `dismissViewController()` on the returned web view controller instance in that closure. Or use
	`authorizeEmbeddedWith()` which does all this automatically.
	
	- parameter controller: The view controller to use for presentation
	- parameter params: Optional additional URL parameters
	- returns: SFSafariViewController, being already presented automatically
	*/
	@available(iOS 9.0, *)
	public func authorizeSafariEmbeddedFrom(controller: UIViewController, params: OAuth2StringDict? = nil) throws -> SFSafariViewController {
		let url = try authorizeURL(params)
		return presentSafariViewFor(url, from: controller)
	}
	
	/**
	Presents a Safari view controller from the supplied view controller, loading the authorize URL.
	
	The mechanism works just like when you're using Safari itself to log the user in, hence you **need to implement**
	`application(application:openURL:sourceApplication:annotation:)` in your application delegate.
	
	Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the web view controller
	automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply call this method first, then assign
	that closure in which you call `dismissViewController()` on the returned web view controller instance.
	
	- parameter controller: The view controller to use for presentation
	- parameter redirect: The redirect URL to use
	- parameter scope: The scope to use
	- parameter params: Optional additional URL parameters
	- returns: SFSafariViewController, being already presented automatically
	*/
	@available(iOS 9.0, *)
	public func authorizeSafariEmbeddedFrom(controller: UIViewController, redirect: String, scope: String, params: OAuth2StringDict? = nil) throws -> SFSafariViewController {
		let url = try authorizeURLWithRedirect(redirect, scope: scope, params: params)
		return presentSafariViewFor(url, from: controller)
	}
	
	/**
	Presents and returns a Safari view controller loading the given URL and intercepting the given URL.
	
	- returns: SFSafariViewController, embedded in a UINavigationController being presented automatically
	*/
	@available(iOS 9.0, *)
	final func presentSafariViewFor(url: NSURL, from: UIViewController) -> SFSafariViewController {
		let web = SFSafariViewController(URL: url)
		web.title = authConfig.ui.title
		
		let delegate = OAuth2SFViewControllerDelegate(oauth: self)
		web.delegate = delegate
		authConfig.ui.safariViewDelegate = delegate
		
		from.presentViewController(web, animated: true, completion: nil)
		
		return web
	}
	
	/**
	Called from our delegate, which reacts to users pressing "Done". We can assume this is always a cancel as nomally the Safari view
	controller is dismissed automatically.
	*/
	@available(iOS 9.0, *)
	func safariViewControllerDidCancel(safari: SFSafariViewController) {
		authConfig.ui.safariViewDelegate = nil
		didFail(nil)
	}
	
	
	// MARK: - Custom Web View Controller
	
	/**
	Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads the authorize URL.
	
	Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the web view controller
	automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply call this method first, then assign
	that closure in which you call `dismissViewController()` on the returned web view controller instance.
	
	- parameter controller: The view controller to use for presentation
	- parameter params: Optional additional URL parameters
	- returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	*/
	public func authorizeEmbeddedFrom(controller: UIViewController, params: OAuth2StringDict? = nil) throws -> OAuth2WebViewController {
		let url = try authorizeURL(params)
		return presentAuthorizeViewFor(url, intercept: redirect!, from: controller)
	}
	
	/**
	Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads the authorize URL.
	
	Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the web view controller
	automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply call this method first, then assign
	that closure in which you call `dismissViewController()` on the returned web view controller instance.
	
	- parameter controller: The view controller to use for presentation
	- parameter redirect: The redirect URL to use
	- parameter scope: The scope to use
	- parameter params: Optional additional URL parameters
	- returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	*/
	public func authorizeEmbeddedFrom(controller: UIViewController,
	                                    redirect: String,
	                                       scope: String,
		                                  params: OAuth2StringDict? = nil) throws -> OAuth2WebViewController {
		let url = try authorizeURLWithRedirect(redirect, scope: scope, params: params)
		return presentAuthorizeViewFor(url, intercept: redirect, from: controller)
	}
	
	/**
	Presents and returns a web view controller loading the given URL and intercepting the given URL.
	
	- returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	*/
	final func presentAuthorizeViewFor(url: NSURL, intercept: String, from: UIViewController) -> OAuth2WebViewController {
		let web = OAuth2WebViewController()
		web.title = authConfig.ui.title
		web.backButton = authConfig.ui.backButton as? UIBarButtonItem
		web.startURL = url
		web.interceptURLString = intercept
		web.onIntercept = { url in
			do {
				try self.handleRedirectURL(url)
				return true
			}
			catch let err {
				self.logIfVerbose("Cannot intercept redirect URL: \(err)")
			}
			return false
		}
		web.onWillDismiss = { didCancel in
			if didCancel {
				self.didFail(nil)
			}
		}
		
		let navi = UINavigationController(rootViewController: web)
		from.presentViewController(navi, animated: true, completion: nil)
		
		return web
	}
}


class OAuth2SFViewControllerDelegate: NSObject, SFSafariViewControllerDelegate {
	
	let oauth: OAuth2
	
	init(oauth: OAuth2) {
		self.oauth = oauth
	}
	
	@available(iOS 9.0, *)
	func safariViewControllerDidFinish(controller: SFSafariViewController) {
		oauth.safariViewControllerDidCancel(controller)
	}
}

