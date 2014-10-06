//
//  OAuth2WebViewController.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 7/15/14.
//  Copyright (c) 2014 Pascal Pfiffner. All rights reserved.
//

import UIKit


extension OAuth2 {
	
	/**
	 *  Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads
	 *  the authorize URL.
	 *
	 *  Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the
	 *  web view controller automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply
	 *  call this method first, then assign that closure in which you call `dismissViewController()` on the returned web
	 *  view controller instance.
	 *  @param redirect The redirect URL to use
	 *  @param scope The scope to use
	 *  @param params Optional additional URL parameters
	 *  @param from The view controller to use for presentation
	 */
	public func authorizeEmbedded(redirect: String, scope: String, params: [String: String]?, from: UIViewController) -> OAuth2WebViewController {
		let url = authorizeURLWithRedirect(redirect, scope: scope, params: params)
		let web = OAuth2WebViewController()
		web.startURL = url
		web.interceptURLString = redirect
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
		from.presentViewController(navi!, animated: true, completion: nil)
		
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
		print(webView)
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
			if (request.URL.pathComponents as NSArray).componentsJoinedByString("/") == interceptComponents?.path {
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

