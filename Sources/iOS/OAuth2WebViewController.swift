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

import UIKit


/**
    A simple iOS web view controller that allows you to display the login/authorization screen.
 */
public class OAuth2WebViewController: UIViewController, UIWebViewDelegate
{
	/// Handle to the OAuth2 instance in play, only used for debug lugging at this time.
	var oauth: OAuth2?
	
	/// The URL to load on first show.
	public var startURL: NSURL? {
		didSet(oldURL) {
			if nil != startURL && nil == oldURL && isViewLoaded() {
				loadURL(startURL!)
			}
		}
	}
	
	/// The URL string to intercept and respond to.
	var interceptURLString: String? {
		didSet(oldURL) {
			if nil != interceptURLString {
				if let url = NSURL(string: interceptURLString!) {
					interceptComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
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
	var interceptComponents: NSURLComponents?
	
	/// Closure called when the web view gets asked to load the redirect URL, specified in `interceptURLString`. Return a Bool indicating
	/// that you've intercepted the URL.
	var onIntercept: ((url: NSURL) -> Bool)?
	
	/// Called when the web view is about to be dismissed.
	var onWillDismiss: ((didCancel: Bool) -> Void)?
	
	/// Assign to override the back button, shown when it's possible to go back in history. Will adjust target/action accordingly.
	public var backButton: UIBarButtonItem? {
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
	
	override public func loadView() {
		edgesForExtendedLayout = .All
		extendedLayoutIncludesOpaqueBars = true
		automaticallyAdjustsScrollViewInsets = true
		
		super.loadView()
		view.backgroundColor = UIColor.whiteColor()
		
		cancelButton = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(OAuth2WebViewController.cancel(_:)))
		navigationItem.rightBarButtonItem = cancelButton
		
		// create a web view
		let web = UIWebView()
		web.translatesAutoresizingMaskIntoConstraints = false
		web.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
		web.delegate = self
		
		view.addSubview(web)
		let views = ["web": web]
		view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[web]|", options: [], metrics: nil, views: views))
		view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[web]|", options: [], metrics: nil, views: views))
		webView = web
	}
	
	override public func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		if let web = webView where !web.canGoBack {
			if nil != startURL {
				loadURL(startURL!)
			}
			else {
				web.loadHTMLString("There is no `startURL`", baseURL: nil)
			}
		}
	}
	
	func showHideBackButton(show: Bool) {
		if show {
			let bb = backButton ?? UIBarButtonItem(barButtonSystemItem: .Rewind, target: self, action: #selector(OAuth2WebViewController.goBack(_:)))
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
	
	func showErrorMessage(message: String, animated: Bool) {
		NSLog("Error: \(message)")
	}
	
	
	// MARK: - Actions
	
	public func loadURL(url: NSURL) {
		webView?.loadRequest(NSURLRequest(URL: url))
	}
	
	func goBack(sender: AnyObject?) {
		webView?.goBack()
	}
	
	func cancel(sender: AnyObject?) {
		dismiss(asCancel: true, animated: nil != sender ? true : false)
	}
	
	func dismiss(animated animated: Bool) {
		dismiss(asCancel: false, animated: animated)
	}
	
	func dismiss(asCancel asCancel: Bool, animated: Bool) {
		webView?.stopLoading()
		
		if nil != self.onWillDismiss {
			self.onWillDismiss!(didCancel: asCancel)
		}
		dismissViewControllerAnimated(animated, completion: nil)
	}
	
	
	// MARK: - Web View Delegate
	
	public func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
		if nil == onIntercept {
			return true
		}
		
		// we compare the scheme and host first, then check the path (if there is any). Not sure if a simple string comparison
		// would work as there may be URL parameters attached
		if let url = request.URL where url.scheme == interceptComponents?.scheme && url.host == interceptComponents?.host {
			let haveComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
			if let hp = haveComponents?.path, ip = interceptComponents?.path where hp == ip || ("/" == hp + ip) {
				return !onIntercept!(url: url)
			}
		}
		
		return true
	}
	
	public func webViewDidStartLoad(webView: UIWebView) {
		if "file" != webView.request?.URL?.scheme {
			showLoadingIndicator()
		}
	}
	
	/* Special handling for Google's `urn:ietf:wg:oauth:2.0:oob` callback */
	public func webViewDidFinishLoad(webView: UIWebView) {
		if let scheme = interceptComponents?.scheme where "urn" == scheme {
			if let path = interceptComponents?.path where path.hasPrefix("ietf:wg:oauth:2.0:oob") {
				if let title = webView.stringByEvaluatingJavaScriptFromString("document.title") where title.hasPrefix("Success ") {
					oauth?.logger?.debug("OAuth2", msg: "Creating redirect URL from document.title")
					let qry = title.stringByReplacingOccurrencesOfString("Success ", withString: "")
					if let url = NSURL(string: "http://localhost/?\(qry)") {
						onIntercept?(url: url)
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
	
	public func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
		if NSURLErrorDomain == error?.domain && NSURLErrorCancelled == error?.code {
			return
		}
		// do we still need to intercept "WebKitErrorDomain" error 102?
		
		if nil != loadingView {
			showErrorMessage(error?.localizedDescription ?? "Unknown web view load error", animated: true)
		}
	}
}

