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
import AuthenticationServices
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
	
	/// Used to store the `SFSafariViewControllerDelegate` || `UIAdaptivePresentationControllerDelegate`
	private var safariViewDelegate: OAuth2SFViewControllerDelegate?
	
	/// Used to store the authentication session.
	private var authenticationSession: AnyObject?
	
	/// Used to store the ASWebAuthenticationPresentationContextProvider
	private var webAuthenticationPresentationContextProvider: AnyObject?
	
	public init(oauth2: OAuth2Base) {
		self.oauth2 = oauth2
	}
	
	
	// MARK: - OAuth2AuthorizerUI
	
	/**
	Uses `UIApplication` to open the authorize URL in iOS's browser.
	
	- parameter url: The authorize URL to open
	- throws: UnableToOpenAuthorizeURL on failure
	*/
	public func openAuthorizeURLInBrowser(_ url: URL) throws {
		
		#if !P2_APP_EXTENSIONS
		if !UIApplication.shared.openURL(url) {
			throw OAuth2Error.unableToOpenAuthorizeURL
		}
		#else
		throw OAuth2Error.unableToOpenAuthorizeURL
		#endif
	}
	
	/**
	Tries to use the current auth config context, which on iOS should be a UIViewController, to present the authorization screen.
	
	- throws:         Can throw OAuth2Error if the method is unable to show the authorize screen
	- parameter with: The configuration to be used; usually uses the instance's `authConfig`
	- parameter at:   The authorize URL to open
	*/
	public func authorizeEmbedded(with config: OAuth2AuthConfig, at url: URL) throws {
		if #available(iOS 11, *), config.ui.useAuthenticationSession {
			guard let redirect = oauth2.redirect else {
				throw OAuth2Error.noRedirectURL
			}
			
			authenticationSessionEmbedded(at: url, withRedirect: redirect, prefersEphemeralWebBrowserSession: config.ui.prefersEphemeralWebBrowserSession)
		} else {
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
	}
	
	/**
	Called with the view- and (possibly) navigation-controller that is about to be presented. Useful for subclasses, default implementation
	does nothing.
	
	- parameter viewController: The Safari- or web view controller that will be presented
	- parameter naviController: The navigation controller embedding the view controller, if any
	*/
	open func willPresent(viewController: UIViewController, in naviController: UINavigationController?) {
	}
	
	// MARK: - SFAuthenticationSession / ASWebAuthenticationSession
	
	/**
	Use SFAuthenticationSession or ASWebAuthenticationSession to manage authorisation.
	
	On iOS 11, use SFAuthenticationSession. On iOS 12+, use ASWebAuthenticationSession.
	
	The mechanism works just like when you're using Safari itself to log the user in, hence you **need to implement**
	`application(application:openURL:sourceApplication:annotation:)` in your application delegate.
	
	This method dismisses the view controller automatically - this cannot be disabled.
	
	- parameter at:       The authorize URL to open
	- parameter redirect: The full redirect URL to use
	- parameter prefersEphemeralWebBrowserSession: may be passed through to [ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/3237231-prefersephemeralwebbrowsersessio).
	- returns:            A Boolean value indicating whether the web authentication session starts successfully.
	*/
	@available(iOS 11.0, *)
	@discardableResult
	public func authenticationSessionEmbedded(at url: URL, withRedirect redirect: String, prefersEphemeralWebBrowserSession: Bool = false) -> Bool {
		guard let redirectURL = URL(string: redirect) else {
			oauth2.logger?.warn("OAuth2", msg: "Unable to parse redirect URL ”(redirect)“")
			return false
		}
		let completionHandler: (URL?, Error?) -> Void = { url, error in
			if let url = url {
				do {
					try self.oauth2.handleRedirectURL(url as URL)
				}
				catch let err {
					self.oauth2.logger?.warn("OAuth2", msg: "Cannot intercept redirect URL: \(err)")
				}
			} else {
				if let authenticationSessionError = error as? ASWebAuthenticationSessionError {
					switch authenticationSessionError.code {
					case .canceledLogin:
						self.oauth2.didFail(with: .requestCancelled)
					default:
						self.oauth2.didFail(with: error?.asOAuth2Error)
					}
				}
				else {
					self.oauth2.didFail(with: error?.asOAuth2Error)
				}
			}
			self.authenticationSession = nil
			self.webAuthenticationPresentationContextProvider = nil
		}
		
		#if targetEnvironment(macCatalyst)
		authenticationSession = ASWebAuthenticationSession(url: url, callbackURLScheme: redirectURL.scheme, completionHandler: completionHandler)
		return (authenticationSession as! ASWebAuthenticationSession).start()
		#else
		authenticationSession = ASWebAuthenticationSession(url: url, callbackURLScheme: redirectURL.scheme, completionHandler: completionHandler)
		if #available(iOS 13.0, *) {
			webAuthenticationPresentationContextProvider = OAuth2ASWebAuthenticationPresentationContextProvider(authorizer: self)
			if let session = authenticationSession as? ASWebAuthenticationSession {
				session.presentationContextProvider = webAuthenticationPresentationContextProvider as! OAuth2ASWebAuthenticationPresentationContextProvider
				session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
			}
		}
		return (authenticationSession as! ASWebAuthenticationSession).start()
		#endif
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
	@discardableResult
	public func authorizeSafariEmbedded(from controller: UIViewController, at url: URL) throws -> SFSafariViewController {
		safariViewDelegate = OAuth2SFViewControllerDelegate(authorizer: self)
		let web = SFSafariViewController(url: url)
		web.title = oauth2.authConfig.ui.title
		web.delegate = safariViewDelegate
		if let barTint = oauth2.authConfig.ui.barTintColor {
			web.preferredBarTintColor = barTint
		}
		if let tint = oauth2.authConfig.ui.controlTintColor {
			web.preferredControlTintColor = tint
		}
		web.modalPresentationStyle = oauth2.authConfig.ui.modalPresentationStyle
		
		willPresent(viewController: web, in: nil)
		controller.present(web, animated: true, completion: nil)
		web.presentationController?.delegate = safariViewDelegate
		return web
	}
	
	
	/**
	Called from our delegate, which reacts to users pressing "Done". We can assume this is always a cancel as nomally the Safari view
	controller is dismissed automatically.
	*/
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
class OAuth2SFViewControllerDelegate: NSObject, SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
	
	weak var authorizer: OAuth2Authorizer?
	
	init(authorizer: OAuth2Authorizer) {
		self.authorizer = authorizer
	}
	
	@available(iOS 9.0, *)
	func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
		authorizer?.safariViewControllerDidCancel(controller)
	}

	// called in case ViewController is dismissed via pulling down the presented sheet.
	func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
		guard let safariViewController = presentationController.presentedViewController as? SFSafariViewController else { return }
		authorizer?.safariViewControllerDidCancel(safariViewController)
	}
}

@available(iOS 13.0, *)
class OAuth2ASWebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
	
	private let authorizer: OAuth2Authorizer
	
	init(authorizer: OAuth2Authorizer) {
		self.authorizer = authorizer
	}
	
	public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		if let context = authorizer.oauth2.authConfig.authorizeContext as? ASPresentationAnchor {
			return context
		}
		
		if let context = authorizer.oauth2.authConfig.authorizeContext as? UIViewController {
			return context.view.window!
		}
		
		fatalError("Invalid authConfig.authorizeContext, must be an ASPresentationAnchor but is \(String(describing: authorizer.oauth2.authConfig.authorizeContext))")
	}
}

#endif
