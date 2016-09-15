//
//  OAuth2WebViewController.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 7/15/14.
//  Copyright 2014 Pascal Pfiffner
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
#if !NO_MODULE_IMPORT
import Base
#endif


/**
A simple iOS web view controller that allows you to display the login/authorization screen.
*/
open class OAuth2WebViewController: UIViewController, UIWebViewDelegate {
	
	/// Handle to the OAuth2 instance in play, only used for debug lugging at this time.
	var oauth: OAuth2?
	
	/// The URL to load on first show.
	open var startURL: URL? {
		didSet(oldURL) {
			if nil != startURL && nil == oldURL && isViewLoaded {
				load(url: startURL!)
			}
		}
	}
	
	/// The URL string to intercept and respond to.
	var interceptURLString: String? {
		didSet(oldURL) {
			if nil != interceptURLString {
				if let url = URL(string: interceptURLString!) {
					interceptComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
				}
				else {
					oauth?.logger?.debug("OAuth2", msg: "Failed to parse URL \(interceptURLString), discarding")
					interceptURLString = nil
				}
			}
			else {
				interceptComponents = nil
			}
		}
	}
	var interceptComponents: URLComponents?
	
	/// Closure called when the web view gets asked to load the redirect URL, specified in `interceptURLString`. Return a Bool indicating
	/// that you've intercepted the URL.
	var onIntercept: ((URL) -> Bool)?
	
	/// Called when the web view is about to be dismissed. The Bool indicates whether the request was (user-)cancelled.
	var onWillDismiss: ((_ didCancel: Bool) -> Void)?
	
	/// Assign to override the back button, shown when it's possible to go back in history. Will adjust target/action accordingly.
	open var backButton: UIBarButtonItem? {
		didSet {
			if let backButton = backButton {
				backButton.target = self
				backButton.action = #selector(OAuth2WebViewController.goBack(_:))
			}
		}
	}
	
	var cancelButton: UIBarButtonItem?
	
	/// Our web view.
	var webView: UIWebView?
	
	/// An overlay view containing a spinner.
	var loadingView: UIView?
	
	init() {
		super.init(nibName: nil, bundle: nil)
	}
	
	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	
	// MARK: - View Handling
	
	override open func loadView() {
		edgesForExtendedLayout = .all
		extendedLayoutIncludesOpaqueBars = true
		automaticallyAdjustsScrollViewInsets = true
		
		super.loadView()
		view.backgroundColor = UIColor.white
		
		cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(OAuth2WebViewController.cancel(_:)))
		navigationItem.rightBarButtonItem = cancelButton
		
		// create a web view
		let web = UIWebView()
		web.translatesAutoresizingMaskIntoConstraints = false
		web.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
		web.delegate = self
		
		view.addSubview(web)
		let views = ["web": web]
		view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[web]|", options: [], metrics: nil, views: views))
		view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[web]|", options: [], metrics: nil, views: views))
		webView = web
	}
	
	override open func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if let web = webView, !web.canGoBack {
			if nil != startURL {
				load(url: startURL!)
			}
			else {
				web.loadHTMLString("There is no `startURL`", baseURL: nil)
			}
		}
	}
	
	func showHideBackButton(_ show: Bool) {
		if show {
			let bb = backButton ?? UIBarButtonItem(barButtonSystemItem: .rewind, target: self, action: #selector(OAuth2WebViewController.goBack(_:)))
			navigationItem.leftBarButtonItem = bb
		}
		else {
			navigationItem.leftBarButtonItem = nil
		}
	}
	
	func showLoadingIndicator() {
		// TODO: implement
	}
	
	func hideLoadingIndicator() {
		// TODO: implement
	}
	
	func showErrorMessage(_ message: String, animated: Bool) {
		NSLog("Error: \(message)")
	}
	
	
	// MARK: - Actions
	
	open func load(url: URL) {
		webView?.loadRequest(URLRequest(url: url))
	}
	
	func goBack(_ sender: AnyObject?) {
		webView?.goBack()
	}
	
	func cancel(_ sender: AnyObject?) {
		dismiss(asCancel: true, animated: (nil != sender) ? true : false)
	}
	
	override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
		dismiss(asCancel: false, animated: flag, completion: completion)
	}
	
	func dismiss(asCancel: Bool, animated: Bool, completion: (() -> Void)? = nil) {
		webView?.stopLoading()
		
		if nil != self.onWillDismiss {
			self.onWillDismiss!(asCancel)
		}
		super.dismiss(animated: animated, completion: completion)
	}
	
	
	// MARK: - Web View Delegate
	
	open func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
		guard let onIntercept = onIntercept else {
			return true
		}
		
		// we compare the scheme and host first, then check the path (if there is any). Not sure if a simple string comparison
		// would work as there may be URL parameters attached
		if let url = request.url, url.scheme == interceptComponents?.scheme && url.host == interceptComponents?.host {
			let haveComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
			if let hp = haveComponents?.path, let ip = interceptComponents?.path, hp == ip || ("/" == hp + ip) {
				return !onIntercept(url)
			}
		}
		
		return true
	}
	
	open func webViewDidStartLoad(_ webView: UIWebView) {
		if "file" != webView.request?.url?.scheme {
			showLoadingIndicator()
		}
	}
	
	/* Special handling for Google's `urn:ietf:wg:oauth:2.0:oob` callback */
	open func webViewDidFinishLoad(_ webView: UIWebView) {
		if let scheme = interceptComponents?.scheme, "urn" == scheme {
			if let path = interceptComponents?.path, path.hasPrefix("ietf:wg:oauth:2.0:oob") {
				if let title = webView.stringByEvaluatingJavaScript(from: "document.title"), title.hasPrefix("Success ") {
					oauth?.logger?.debug("OAuth2", msg: "Creating redirect URL from document.title")
					let qry = title.replacingOccurrences(of: "Success ", with: "")
					if let url = URL(string: "http://localhost/?\(qry)") {
						_ = onIntercept?(url)
						return
					}
					else {
						oauth?.logger?.warn("OAuth2", msg: "Failed to create a URL with query parts \"\(qry)\"")
					}
				}
			}
		}
		
		hideLoadingIndicator()
		showHideBackButton(webView.canGoBack)
	}
	
	open func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
		if NSURLErrorDomain == error._domain && NSURLErrorCancelled == error._code {
			return
		}
		// do we still need to intercept "WebKitErrorDomain" error 102?
		
		if nil != loadingView {
			showErrorMessage(error.localizedDescription, animated: true)
		}
	}
}

#endif
