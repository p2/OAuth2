//
//  OAuth2WebViewController.swift
//  OAuth2
//
//  Created by Guilherme Rambo on 18/01/16.
//  Copyright 2016 Pascal Pfiffner
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
#if os(macOS)

import Cocoa
import WebKit
#if !NO_MODULE_IMPORT
import Base
#endif


/**
A view controller that allows you to display the login/authorization screen.
*/
@available(macOS 10.10, *)
public class OAuth2WebViewController: NSViewController, WKNavigationDelegate, NSWindowDelegate {
	
	/** Designated initializer. */
	public init() {
		super.init(nibName: nil, bundle: nil)
	}
	
	/// Handle to the OAuth2 instance in play, only used for debug logging at this time.
	var oauth: OAuth2Base?
	
	/// Configure the view to be shown as sheet, false by default; must be present before the view gets loaded.
	var willBecomeSheet = false
	
	/// The URL to load on first show.
	public var startURL: URL? {
		didSet(oldURL) {
			if nil != startURL && nil == oldURL && isViewLoaded {
				loadURL(startURL!)
			}
		}
	}
	
	/// The URL string to intercept and respond to.
	public var interceptURLString: String? {
		didSet(oldURL) {
			if nil != interceptURLString {
				if let url = URL(string: interceptURLString!) {
					interceptComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
				}
				else {
					oauth?.logger?.warn("OAuth2", msg: "Failed to parse URL \(interceptURLString!), discarding")
					interceptURLString = nil
				}
			}
			else {
				interceptComponents = nil
			}
		}
	}
	
	/// Internally used; the URL components, derived from `interceptURLString`, comprising the URL to be intercepted.
	var interceptComponents: URLComponents?
	
	/// Closure called when the web view gets asked to load the redirect URL, specified in `interceptURLString`. Return a Bool indicating
	/// that you've intercepted the URL.
	public var onIntercept: ((URL) -> Bool)?
	
	/// Called when the web view is about to be dismissed manually.
	public var onWillCancel: (() -> Void)?
	
	/// Our web view; implicitly unwrapped so do not attempt to use it unless isViewLoaded() returns true.
	var webView: WKWebView!
	
	private var progressIndicator: NSProgressIndicator!
	private var loadingView: NSView {
		let view = NSView(frame: self.view.bounds)
		view.translatesAutoresizingMaskIntoConstraints = false
		
		progressIndicator = NSProgressIndicator(frame: NSZeroRect)
		progressIndicator.style = .spinning
		progressIndicator.isDisplayedWhenStopped = false
		progressIndicator.sizeToFit()
		progressIndicator.translatesAutoresizingMaskIntoConstraints = false
		
		view.addSubview(progressIndicator)
		view.addConstraint(NSLayoutConstraint(item: progressIndicator, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0.0))
		view.addConstraint(NSLayoutConstraint(item: progressIndicator, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0.0))
		
		return view
	}
	
	/** Initializer from an NSCoder. */
	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	
	// MARK: - View Handling
	
	/// Default web view window width; defaults to 600.
	internal static let webViewWindowWidth = CGFloat(600.0)
	
	/// Default web view window height; defaults to 500.
	internal static let webViewWindowHeight = CGFloat(500.0)
	
	/** Override to fully load the view; adds a `WKWebView`, optionally a dismiss button, and shows the loading indicator. */
	override public func loadView() {
		view = NSView(frame: NSMakeRect(0, 0, OAuth2WebViewController.webViewWindowWidth, OAuth2WebViewController.webViewWindowHeight))
		view.translatesAutoresizingMaskIntoConstraints = false
		
		webView = WKWebView(frame: view.bounds, configuration: WKWebViewConfiguration())
		webView.translatesAutoresizingMaskIntoConstraints = false
		webView.navigationDelegate = self
		webView.alphaValue = 0.0
		
		view.addSubview(webView)
		view.addConstraint(NSLayoutConstraint(item: webView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 0.0))
		view.addConstraint(NSLayoutConstraint(item: webView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: (willBecomeSheet ? -40.0 : 0.0)))
		view.addConstraint(NSLayoutConstraint(item: webView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 0.0))
		view.addConstraint(NSLayoutConstraint(item: webView, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1.0, constant: 0.0))
		
		// add a dismiss button
		if willBecomeSheet {
			let button = NSButton(frame: NSRect(x: 0, y: 0, width: 120, height: 20))
			button.translatesAutoresizingMaskIntoConstraints = false
			button.title = "Cancel"
			button.bezelStyle = .rounded
			button.target = self
			button.action = #selector(OAuth2WebViewController.cancel(_:))
			view.addSubview(button)
			view.addConstraint(NSLayoutConstraint(item: button, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: -10.0))
			view.addConstraint(NSLayoutConstraint(item: button, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: -10.0))
		}
		
		showLoadingIndicator()
	}
	
	/** This override starts loading `startURL` if nothing has been loaded yet, e.g. on first show. */
	override public func viewWillAppear() {
		super.viewWillAppear()
		
		if !webView.canGoBack {
			if nil != startURL {
				loadURL(startURL!)
			}
			else {
				webView.loadHTMLString("There is no `startURL`", baseURL: nil)
			}
		}
	}
	
	/** Override to set the window delegate to self. */
	override public func viewDidAppear() {
		super.viewDidAppear()
		view.window?.delegate = self
	}
	
	/** Adds a loading indicator view to the center of the view. */
	func showLoadingIndicator() {
		let loadingContainerView = loadingView
		
		view.addSubview(loadingContainerView)
		view.addConstraint(NSLayoutConstraint(item: loadingContainerView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 0.0))
		view.addConstraint(NSLayoutConstraint(item: loadingContainerView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: 0.0))
		view.addConstraint(NSLayoutConstraint(item: loadingContainerView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 0.0))
		view.addConstraint(NSLayoutConstraint(item: loadingContainerView, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1.0, constant: 0.0))
		
		progressIndicator.startAnimation(nil)
	}
	
	/** Hides the loading indicator, if it is currently being shown. */
	func hideLoadingIndicator() {
		guard progressIndicator != nil else { return }
		
		progressIndicator.stopAnimation(nil)
		progressIndicator.superview?.removeFromSuperview()
	}
	
	/** Convenience method to show an error message; will add the error to a <p> element shown centered in the web view. */
	func showErrorMessage(_ message: String, animated: Bool) {
		hideLoadingIndicator()
		webView.animator().alphaValue = 1.0
		webView.loadHTMLString("<p style=\"text-align:center;font:'helvetica neue', sans-serif;color:red\">\(message)</p>", baseURL: nil)
	}
	
	
	// MARK: - Actions
	
	/**
	Loads the given URL in the web view.
	
	- parameter url: The URL to load
	*/
	public func loadURL(_ url: URL) {
		webView.load(URLRequest(url: url))
	}
	
	/**
	Tells the web view to go back in history.
	*/
	func goBack(_ sender: AnyObject?) {
		webView.goBack()
	}
	
	/**
	Tells the web view to stop loading the current page, then calls the `onWillCancel` block if it has a value.
	*/
	@objc func cancel(_ sender: AnyObject?) {
		webView.stopLoading()
		onWillCancel?()
	}
	
	
	// MARK: - Web View Delegate
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		let request = navigationAction.request
		
		guard let onIntercept = onIntercept else {
			decisionHandler(.allow)
			return
		}
		
		// we compare the scheme and host first, then check the path (if there is any). Not sure if a simple string comparison
		// would work as there may be URL parameters attached
		if let url = request.url, url.scheme == interceptComponents?.scheme && url.host == interceptComponents?.host {
			let haveComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
			if let hp = haveComponents?.path, let ip = interceptComponents?.path, hp == ip || ("/" == hp + ip) {
				if onIntercept(url) {
					decisionHandler(.cancel)
				}
				else {
					decisionHandler(.allow)
				}
				
				return
			}
		}
		
		decisionHandler(.allow)
	}
	
	public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		if let scheme = interceptComponents?.scheme, "urn" == scheme {
			if let path = interceptComponents?.path, path.hasPrefix("ietf:wg:oauth:2.0:oob") {
				if let title = webView.title, title.hasPrefix("Success ") {
					oauth?.logger?.debug("OAuth2", msg: "Creating redirect URL from document.title")
					let qry = title.replacingOccurrences(of: "Success ", with: "")
					if let url = URL(string: "http://localhost/?\(qry)") {
						_ = onIntercept?(url)
						return
					}
					
					oauth?.logger?.warn("OAuth2", msg: "Failed to create a URL with query parts \"\(qry)\"")
				}
			}
		}
		
		webView.animator().alphaValue = 1.0
		hideLoadingIndicator()
	}
	
	public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		if NSURLErrorDomain == error._domain && NSURLErrorCancelled == error._code {
			return
		}
		// do we still need to intercept "WebKitErrorDomain" error 102?
		
		showErrorMessage(error.localizedDescription, animated: true)
	}
	
	
	// MARK: - Window Delegate
	
	public func windowShouldClose(_ sender: NSWindow) -> Bool {
		onWillCancel?()
		return false
	}
}

#endif
