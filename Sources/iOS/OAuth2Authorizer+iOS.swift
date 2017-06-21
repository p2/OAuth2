//
//  OAuth2Authorizer+iOS.swift
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
#if os(iOS)

import UIKit
import SafariServices
#if !NO_MODULE_IMPORT
import Base
#endif


/**
This authorizer takes care of iOS-specific tasks when showing the authorization UI.

You can subclass this class and override `willPresent(viewController:naviController:)` in order to further customize presentation of the UI.
*/
open class OAuth2Authorizer: OAuth2AuthorizerUI {
	
	/// The OAuth2 instance this authorizer belongs to.
	public unowned let oauth2: OAuth2Base
	
	/// Used to store the `SFSafariViewControllerDelegate`.
	private var safariViewDelegate: AnyObject?
	
	
	public init(oauth2: OAuth2) {
		self.oauth2 = oauth2
	}
	
	
	// MARK: - OAuth2AuthorizerUI
	
	/**
	Uses `UIApplication` to open the authorize URL in iOS's browser.
	
	- parameter url: The authorize URL to open
	- throws: UnableToOpenAuthorizeURL on failure
	*/
	public func openAuthorizeURLInBrowser(_ url: URL) throws {
		
		// By asking for the shared instance method by using the "value for key" method on UIApplication, we are able to
		// bypass the Swift compilation restriction that blocks the library from being compiled for an extension when 
		// directly referencing it. We do it as an optional so in the advent of this method being called, like in an 
		// extension, we handle it as though its not supported.
		guard let application = UIApplication.value(forKey: "sharedApplication") as? UIApplication else {
			throw OAuth2Error.unableToOpenAuthorizeURL
		}
		
		if !application.openURL(url) {
			throw OAuth2Error.unableToOpenAuthorizeURL
		}
	}
	
	/**
	Tries to use the current auth config context, which on iOS should be a UIViewController, to present the authorization screen.
	
	- throws:         Can throw OAuth2Error if the method is unable to show the authorize screen
	- parameter with: The configuration to be used; usually uses the instance's `authConfig`
	- parameter at:   The authorize URL to open
	*/
	public func authorizeEmbedded(with config: OAuth2AuthConfig, at url: URL) throws {
		guard let controller = config.authorizeContext as? UIViewController else {
			throw (nil == config.authorizeContext) ? OAuth2Error.noAuthorizationContext : OAuth2Error.invalidAuthorizationContext
		}
		
		if #available(iOS 9, *), config.ui.useSafariView {
			let web = try authorizeSafariEmbedded(from: controller, at: url)
			if config.authorizeEmbeddedAutoDismiss {
				oauth2.internalAfterAuthorizeOrFail = { wasFailure, error in
					web.dismiss(animated: true)
				}
			}
		}
		else {
			let web = try authorizeEmbedded(from: controller, at: url)
			if config.authorizeEmbeddedAutoDismiss {
				oauth2.internalAfterAuthorizeOrFail = { wasFailure, error in
					web.dismiss(animated: true)
				}
			}
		}
	}
	
	/**
	Called with the view- and (possibly) navigation-controller that is about to be presented. Useful for subclasses, default implementation
	does nothing.
	
	- parameter viewController: The Safari- or web view controller that will be presented
	- parameter naviController: The navigation controller embedding the view controller, if any
	*/
	open func willPresent(viewController: UIViewController, in naviController: UINavigationController?) {
	}
	
	
	// MARK: - Safari Web View Controller
	
	/**
	Presents a Safari view controller from the supplied view controller, loading the authorize URL.
	
	The mechanism works just like when you're using Safari itself to log the user in, hence you **need to implement**
	`application(application:openURL:sourceApplication:annotation:)` in your application delegate.
	
	This method does NOT dismiss the view controller automatically, you probably want to do this in the callback.
	Simply call this method first, then call `dismissViewController()` on the returned web view controller instance in that closure. Or use
	`authorizeEmbedded(with:at:)` which does all this automatically.
	
	- parameter from: The view controller to use for presentation
	- parameter at:   The authorize URL to open
	- returns:        SFSafariViewController, being already presented automatically
	*/
	@available(iOS 9.0, *)
	@discardableResult
	public func authorizeSafariEmbedded(from controller: UIViewController, at url: URL) throws -> SFSafariViewController {
		safariViewDelegate = OAuth2SFViewControllerDelegate(authorizer: self)
		let web = SFSafariViewController(url: url)
		web.title = oauth2.authConfig.ui.title
		web.delegate = safariViewDelegate as! OAuth2SFViewControllerDelegate
		if #available(iOS 10.0, *), let barTint = oauth2.authConfig.ui.barTintColor {
			web.preferredBarTintColor = barTint
		}
		if #available(iOS 10.0, *), let tint = oauth2.authConfig.ui.controlTintColor {
			web.preferredControlTintColor = tint
		}
		web.modalPresentationStyle = oauth2.authConfig.ui.modalPresentationStyle
        
		willPresent(viewController: web, in: nil)
		controller.present(web, animated: true, completion: nil)
		
		return web
	}
	
	/**
	Called from our delegate, which reacts to users pressing "Done". We can assume this is always a cancel as nomally the Safari view
	controller is dismissed automatically.
	*/
	@available(iOS 9.0, *)
	func safariViewControllerDidCancel(_ safari: SFSafariViewController) {
		safariViewDelegate = nil
		oauth2.didFail(with: nil)
	}
	
	
	// MARK: - Custom Web View Controller
	
	/**
	Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads the authorize URL.
	
	Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the web view controller
	automatically, you probably want to do this in the callback. Simply call this method first, then assign that closure in which you call
	`dismissViewController()` on the returned web view controller instance.
	
	- parameter from: The view controller to use for presentation
	- parameter at:   The authorize URL to open
	- returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	*/
	public func authorizeEmbedded(from controller: UIViewController, at url: URL) throws -> OAuth2WebViewController {
		guard let redirect = oauth2.redirect else {
			throw OAuth2Error.noRedirectURL
		}
		return presentAuthorizeView(forURL: url, intercept: redirect, from: controller)
	}
	
	/**
	Presents and returns a web view controller loading the given URL and intercepting the given URL.
	
	- returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	*/
	final func presentAuthorizeView(forURL url: URL, intercept: String, from controller: UIViewController) -> OAuth2WebViewController {
		let web = OAuth2WebViewController()
		web.title = oauth2.authConfig.ui.title
		web.backButton = oauth2.authConfig.ui.backButton as? UIBarButtonItem
		web.showCancelButton = oauth2.authConfig.ui.showCancelButton
		web.startURL = url
		web.interceptURLString = intercept
		web.onIntercept = { url in
			do {
				try self.oauth2.handleRedirectURL(url as URL)
				return true
			}
			catch let err {
				self.oauth2.logger?.warn("OAuth2", msg: "Cannot intercept redirect URL: \(err)")
			}
			return false
		}
		web.onWillDismiss = { didCancel in
			if didCancel {
				self.oauth2.didFail(with: nil)
			}
		}
		
		let navi = UINavigationController(rootViewController: web)
		navi.modalPresentationStyle = oauth2.authConfig.ui.modalPresentationStyle
		if let barTint = oauth2.authConfig.ui.barTintColor {
			navi.navigationBar.barTintColor = barTint
		}
		if let tint = oauth2.authConfig.ui.controlTintColor {
			navi.navigationBar.tintColor = tint
		}
		
		willPresent(viewController: web, in: navi)
		controller.present(navi, animated: true)
		
		return web
	}
}


/**
A custom `SFSafariViewControllerDelegate` that we use with the safari view controller.
*/
class OAuth2SFViewControllerDelegate: NSObject, SFSafariViewControllerDelegate {
	
	let authorizer: OAuth2Authorizer
	
	init(authorizer: OAuth2Authorizer) {
		self.authorizer = authorizer
	}
	
	@available(iOS 9.0, *)
	func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
		authorizer.safariViewControllerDidCancel(controller)
	}
}

#endif
