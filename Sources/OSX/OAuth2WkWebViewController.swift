//
//  OAuth2WKWebViewController.swift
//  OAuth2
//
//  Created by Renaud Boisjoly on 2016-01-15.
//  Copyright © 2016 Pascal Pfiffner. All rights reserved.
//

import Foundation
import WebKit

public class OAuth2WkWebViewController: NSViewController, WKNavigationDelegate, WKUIDelegate
{
	var oauth: OAuth2?
	var startURL: NSURL?
	var wkWebView: WKWebView!
	
	/// The URL string to intercept and respond to.
	var interceptURLString: String? {
		didSet(oldURL) {
			if nil != interceptURLString {
				if let url = NSURL(string: interceptURLString!) {
					interceptComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
				}
				else {
					oauth?.logIfVerbose("Failed to parse URL \(interceptURLString), discarding")
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

	
	public override func loadView() {
		super.loadView()
	}
	
	public override func viewDidLoad() {
		self.wkWebView = WKWebView(frame: self.view.bounds)
		self.view.addSubview(self.wkWebView)
		
		self.wkWebView.UIDelegate = self
		self.wkWebView.navigationDelegate = self
		
		self.wkWebView.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
		
		if let theURL = self.startURL {
			let requesturl = theURL
			let request = NSURLRequest(URL:requesturl, cachePolicy: .ReturnCacheDataElseLoad, timeoutInterval: 10)
			self.wkWebView.loadRequest(request)
		}

	}
	
	init(startURL: NSURL?) {
		self.startURL = startURL
		let bundle = NSBundle(identifier: "org.chip.OAuth2")!
		super.init(nibName: "OAuth2WkWebViewController", bundle: bundle)!
	}
	
	required public init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)!
	}

	//WKWebDelegate

	
	public func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {

		if let scheme = interceptComponents?.scheme where "urn" == scheme {
			if let path = interceptComponents?.path where path.hasPrefix("ietf:wg:oauth:2.0:oob") {
				if let title = webView.title where title.hasPrefix("Success ") {
					oauth?.logIfVerbose("Creating redirect URL from document.title")
					let qry = title.stringByReplacingOccurrencesOfString("Success ", withString: "")
					if let url = NSURL(string: "http://localhost/?\(qry)") {
						onIntercept?(url: url)
						return
					}
					else {
						oauth?.logIfVerbose("Failed to create a URL with query parts \"\(qry)\"")
					}
				}
			}
		}
	}

	func dismiss(animated animated: Bool) {
		dismiss(asCancel: false)
	}
	
	func dismiss(asCancel asCancel: Bool) {
		self.wkWebView.stopLoading()
		
		presentingViewController?.dismissController(self)
	}
	
}