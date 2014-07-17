//
//  OAuth2WebViewController.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 7/15/14.
//  Copyright (c) 2014 Pascal Pfiffner. All rights reserved.
//

import UIKit


extension OAuth2 {
	
	/*!
	 *  Displays an embedded web view controller on the root view controller and loads the authorize URL.
	 *
	 *  Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the
	 *  web view controller automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply
	 *  call this method first, then assign that closure in which you call `dismissViewController()` on the returned web
	 *  view controller instance.
	 */
	func authorizeEmbedded(redirect: String, scope: String, params: [String: String]?) -> OAuth2WebViewController {
		let url = authorizeURLWithRedirect(redirect, scope: scope, params: params)
		let web = OAuth2WebViewController()
		web.startURL = url
		web.interceptURLString = redirect
		web.onIntercept = { url in
			self.handleRedirectURL(url)
			return true
		}
		web.onDismiss = { didCancel in
			if didCancel {
				self.didFail(nil)
			}
		}
		
		let navi = UINavigationController(rootViewController: web)
		let from = UIApplication.sharedApplication().keyWindow.rootViewController
		from.presentViewController(navi, animated: true, completion: nil)
		
		return web
	}
}


/*!
 *  A simple iOS web view controller that allows you to display the login/authorization screen.
 */
class OAuth2WebViewController: UIViewController, UIWebViewDelegate
{
	/*! The URL to load on first show. */
	var startURL: NSURL? {
		didSet(oldURL) {
			if startURL && !oldURL && isViewLoaded() {
				loadURL(startURL!)
			}
		}
	}
	
	/*! The URL string to intercept and respond to. */
	var interceptURLString: String? {
		didSet(oldURL) {
			if interceptURLString {
				interceptComponents = NSURLComponents(URL: NSURL(string: interceptURLString!), resolvingAgainstBaseURL: true)
			}
		}
	}
	var interceptComponents: NSURLComponents?
	
	/*! Closure called when the web view gets asked to load the redirect URL, specified in `interceptURLString`. */
	var onIntercept: ((url: NSURL) -> Bool)?
	
	/*! Called when the web view gets dismissed. */
	var onDismiss: ((didCancel: Bool) -> Void)?
	
	var cancelButton: UIBarButtonItem?
	var webView: UIWebView!
	var loadingView: UIView?
	
	init() {
		super.init(nibName: nil, bundle: nil)
	}
	
	
	// MARK: View Handling
	
	override func loadView() {
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
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		if !webView.canGoBack {
			if startURL {
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
	
	
	// MARK: Actions
	
	func loadURL(url: NSURL) {
		webView.loadRequest(NSURLRequest(URL: url))
	}
	
	func goBack(sender: AnyObject?) {
		webView.goBack()
	}
	
	func cancel(sender: AnyObject?) {
		dismiss(asCancel: true, animated: sender ? true : false)
	}
	
	func dismiss(# animated: Bool) {
		dismiss(asCancel: false, animated: animated)
	}
	
	func dismiss(# asCancel: Bool, animated: Bool) {
		webView.stopLoading()
		
		presentingViewController.dismissViewControllerAnimated(animated) {
			if self.onDismiss {
				self.onDismiss!(didCancel: asCancel)
			}
		}
	}
	
	
	// MARK: Web View Delegate
	
	func webView(webView: UIWebView!, shouldStartLoadWithRequest request: NSURLRequest!, navigationType: UIWebViewNavigationType) -> Bool {
		
		// we compare the scheme and host first, then check the path (if there is any). Not sure if a simple string comparison
		// would work as there may be URL parameters attached
		if onIntercept && request.URL.scheme == interceptComponents?.scheme && request.URL.host == interceptComponents?.host {
			if (request.URL.pathComponents as NSArray).componentsJoinedByString("/") == interceptComponents?.path {
				return onIntercept!(url: request.URL)
			}
		}
		
		return true
	}
	
	func webViewDidStartLoad(webView: UIWebView!) {
		if "file" != webView.request.URL.scheme {
			showLoadingIndicator()
		}
	}
	
	func webViewDidFinishLoad(webView: UIWebView!) {
		hideLoadingIndicator()
		showHideBackButton(webView.canGoBack)
	}
	
	func webView(webView: UIWebView!, didFailLoadWithError error: NSError!) {
		if NSURLErrorDomain == error.domain && NSURLErrorCancelled == error.code {
			return
		}
		// do we still need to intercept "WebKitErrorDomain" error 102?
		
		if loadingView {
			showErrorMessage(error.localizedDescription, animated: true)
		}
	}
}

