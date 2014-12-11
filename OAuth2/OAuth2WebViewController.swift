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


extension OAuth2
{
	/**
		Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads
		the authorize URL.
	
		Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the
		web view controller automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply
		call this method first, then assign that closure in which you call `dismissViewController()` on the returned web
		view controller instance.
	
		:raises: Will raise if the authorize URL cannot be constructed from the settings used during initialization.
	
		:param: controller The view controller to use for presentation
		:param: params     Optional additional URL parameters
		:returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	*/
	public func authorizeEmbeddedFrom(controller: UIViewController, params: [String: String]?) -> OAuth2WebViewController {
		let url = authorizeURL()
		return presentAuthorizeViewFor(url, intercept: redirect!, from: controller)
	}
	
	/**
		Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads
		the authorize URL.
	
		Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the
		web view controller automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply
		call this method first, then assign that closure in which you call `dismissViewController()` on the returned web
		view controller instance.
		
		:param: controller The view controller to use for presentation
		:param: redirect   The redirect URL to use
		:param: scope      The scope to use
		:param: params     Optional additional URL parameters
		:returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	 */
	public func authorizeEmbeddedFrom(controller: UIViewController,
	                                    redirect: String,
	                                       scope: String,
	                                      params: [String: String]?) -> OAuth2WebViewController {
		let url = authorizeURLWithRedirect(redirect, scope: scope, params: params)
		return presentAuthorizeViewFor(url, intercept: redirect, from: controller)
	}
	
	/**
		Presents and returns a web view controller loading the given URL and intercepting the given URL.
		
		:returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	 */
	func presentAuthorizeViewFor(url: NSURL, intercept: String, from: UIViewController) -> OAuth2WebViewController {
		let web = OAuth2WebViewController()
		web.startURL = url
		web.interceptURLString = intercept
		web.onIntercept = { url in
			self.handleRedirectURL(url)
			return true
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


/**
 *  A simple iOS web view controller that allows you to display the login/authorization screen.
 */
public class OAuth2WebViewController: UIViewController, UIWebViewDelegate
{
	/** The URL to load on first show. */
	public var startURL: NSURL? {
		didSet(oldURL) {
			if nil != startURL && nil == oldURL && isViewLoaded() {
				loadURL(startURL!)
			}
		}
	}
	
	/** The URL string to intercept and respond to. */
	var interceptURLString: String? {
		didSet(oldURL) {
			if nil != interceptURLString {
				if let url = NSURL(string: interceptURLString!) {
					interceptComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
				}
				else {
					println("Failed to parse URL \(interceptURLString), discarding")
					interceptURLString = nil
				}
			}
			else {
				interceptComponents = nil
			}
		}
	}
	var interceptComponents: NSURLComponents?
	
	/** Closure called when the web view gets asked to load the redirect URL, specified in `interceptURLString`. */
	var onIntercept: ((url: NSURL) -> Bool)?
	
	/** Called when the web view is about to be dismissed. */
	var onWillDismiss: ((didCancel: Bool) -> Void)?
	
	var cancelButton: UIBarButtonItem?
	var webView: UIWebView!
	var loadingView: UIView?
	
	override init() {
		super.init(nibName: nil, bundle: nil)
	}
	
	required public init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	
	// MARK: - View Handling
	
	override public func loadView() {
		title = "SMART"
		edgesForExtendedLayout = .All
		extendedLayoutIncludesOpaqueBars = true
		automaticallyAdjustsScrollViewInsets = true
		
		super.loadView()
		view.backgroundColor = UIColor.whiteColor()
		
		cancelButton = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancel:")
		navigationItem.rightBarButtonItem = cancelButton
		
		// create a web view
		webView = UIWebView()
		webView.setTranslatesAutoresizingMaskIntoConstraints(false)
		webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
		webView.delegate = self
		
		view.addSubview(webView!)
		let views = NSDictionary(object: webView, forKey: "web")		// doesn't like ["web": webView!]
		view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[web]|", options: nil, metrics: nil, views: views))
		view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[web]|", options: nil, metrics: nil, views: views))
	}
	
	override public func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		if !webView.canGoBack {
			if nil != startURL {
				loadURL(startURL!)
			}
			else {
				webView.loadHTMLString("There is no `startURL`", baseURL: nil)
			}
		}
	}
	
	func showHideBackButton(show: Bool) {
		if show {
			let bb = UIBarButtonItem(barButtonSystemItem: .Rewind, target: self, action: "goBack:")
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
		println("Error: \(message)")
	}
	
	
	// MARK: - Actions
	
	public func loadURL(url: NSURL) {
		webView.loadRequest(NSURLRequest(URL: url))
	}
	
	func goBack(sender: AnyObject?) {
		webView.goBack()
	}
	
	func cancel(sender: AnyObject?) {
		dismiss(asCancel: true, animated: nil != sender ? true : false)
	}
	
	func dismiss(# animated: Bool) {
		dismiss(asCancel: false, animated: animated)
	}
	
	func dismiss(# asCancel: Bool, animated: Bool) {
		webView.stopLoading()
		
		if nil != self.onWillDismiss {
			self.onWillDismiss!(didCancel: asCancel)
		}
		presentingViewController?.dismissViewControllerAnimated(animated, nil)
	}
	
	
	// MARK: - Web View Delegate
	
	public func webView(webView: UIWebView!, shouldStartLoadWithRequest request: NSURLRequest!, navigationType: UIWebViewNavigationType) -> Bool {
		
		// we compare the scheme and host first, then check the path (if there is any). Not sure if a simple string comparison
		// would work as there may be URL parameters attached
		if nil != onIntercept && request.URL.scheme == interceptComponents?.scheme && request.URL.host == interceptComponents?.host {
			let haveComponents = NSURLComponents(URL: request.URL, resolvingAgainstBaseURL: true)
			if haveComponents?.path == interceptComponents?.path {
				return onIntercept!(url: request.URL)
			}
		}
		
		return true
	}
	
	public func webViewDidStartLoad(webView: UIWebView!) {
		if "file" != webView.request?.URL.scheme {
			showLoadingIndicator()
		}
	}
	
	public func webViewDidFinishLoad(webView: UIWebView!) {
		hideLoadingIndicator()
		showHideBackButton(webView.canGoBack)
	}
	
	public func webView(webView: UIWebView!, didFailLoadWithError error: NSError!) {
		if NSURLErrorDomain == error.domain && NSURLErrorCancelled == error.code {
			return
		}
		// do we still need to intercept "WebKitErrorDomain" error 102?
		
		if nil != loadingView {
			showErrorMessage(error.localizedDescription, animated: true)
		}
	}
}

