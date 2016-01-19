//
//  OAuth2WebViewController.swift
//  OAuth2
//
//  Created by Guilherme Rambo on 18/01/16.
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

import Cocoa
import WebKit


/**
    A view controller that allows you to display the login/authorization screen.
 */
@available(OSX 10.11, *)
public class OAuth2WebViewController: NSViewController, WKNavigationDelegate, NSWindowDelegate
{
    init() {
        super.init(nibName: nil, bundle: nil)!
    }
    
	/// Handle to the OAuth2 instance in play, only used for debug lugging at this time.
	var oauth: OAuth2?
	
	/// The URL to load on first show.
	public var startURL: NSURL? {
		didSet(oldURL) {
			if nil != startURL && nil == oldURL && viewLoaded {
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
	
	/// Our web view; implicitly unwrapped so do not attempt to use it unless isViewLoaded() returns true.
	var webView: WKWebView!
	
    private var progressIndicator: NSProgressIndicator!
    private var loadingView: NSView {
        let view = NSView(frame: self.view.bounds)
        view.translatesAutoresizingMaskIntoConstraints = false

        progressIndicator = NSProgressIndicator(frame: NSZeroRect)
        progressIndicator.style = .SpinningStyle
        progressIndicator.displayedWhenStopped = false
        progressIndicator.sizeToFit()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(progressIndicator)
        progressIndicator.centerXAnchor.constraintEqualToAnchor(view.centerXAnchor).active = true
        progressIndicator.centerYAnchor.constraintEqualToAnchor(view.centerYAnchor).active = true
        
        return view
    }
	
	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	
	// MARK: - View Handling
	
    internal static let WebViewWindowWidth = CGFloat(600.0)
    internal static let WebViewWindowHeight = CGFloat(400.0)
    
	override public func loadView() {
        view = NSView(frame: NSMakeRect(0, 0, OAuth2WebViewController.WebViewWindowWidth, OAuth2WebViewController.WebViewWindowHeight))
        view.translatesAutoresizingMaskIntoConstraints = false

        webView = WKWebView(frame: view.bounds, configuration: WKWebViewConfiguration())
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.alphaValue = 0.0
        
        view.addSubview(webView)
        
        webView.topAnchor.constraintEqualToAnchor(view.topAnchor).active = true
        webView.bottomAnchor.constraintEqualToAnchor(view.bottomAnchor).active = true
        webView.leadingAnchor.constraintEqualToAnchor(view.leadingAnchor).active = true
        webView.trailingAnchor.constraintEqualToAnchor(view.trailingAnchor).active = true
        
        showLoadingIndicator()
	}
	
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
	
    public override func viewDidAppear() {
        super.viewDidAppear()
        
        view.window?.delegate = self
    }
    
	func showLoadingIndicator() {
        let loadingContainerView = loadingView
        
		view.addSubview(loadingContainerView)
        loadingContainerView.topAnchor.constraintEqualToAnchor(view.topAnchor).active = true
        loadingContainerView.bottomAnchor.constraintEqualToAnchor(view.bottomAnchor).active = true
        loadingContainerView.leadingAnchor.constraintEqualToAnchor(view.leadingAnchor).active = true
        loadingContainerView.trailingAnchor.constraintEqualToAnchor(view.trailingAnchor).active = true

        progressIndicator.startAnimation(nil)
	}
	
	func hideLoadingIndicator() {
        guard progressIndicator != nil else { return }
        
        progressIndicator.stopAnimation(nil)
        progressIndicator.superview?.removeFromSuperview()
	}

	func showErrorMessage(message: String, animated: Bool) {
        hideLoadingIndicator()
        webView.animator().alphaValue = 1.0
        webView.loadHTMLString("<p style=\"text-align:center;font:'helvetica neue', sans-serif;color:red\">\(message)</p>", baseURL: nil)
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
	
	func dismiss(animated animated: Bool) {
		dismiss(asCancel: false, animated: animated)
	}
	
	func dismiss(asCancel asCancel: Bool, animated: Bool) {
		webView.stopLoading()
		
        onWillDismiss?(didCancel: asCancel)
        
        dismissViewController(self)
	}
	
	
	// MARK: - Web View Delegate
	
    public func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        
		if nil == onIntercept {
            decisionHandler(.Allow)
			return
		}

		// we compare the scheme and host first, then check the path (if there is any). Not sure if a simple string comparison
		// would work as there may be URL parameters attached
		if let url = request.URL where url.scheme == interceptComponents?.scheme && url.host == interceptComponents?.host {
			let haveComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
			if let hp = haveComponents?.path, ip = interceptComponents?.path where hp == ip || ("/" == hp + ip) {
                if onIntercept!(url: url) {
                    decisionHandler(.Cancel)
                } else {
                    decisionHandler(.Allow)
                }
			}
		}
		
        decisionHandler(.Allow)
    }

    private var gotIntercepted = false
    
    public func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
		if let scheme = interceptComponents?.scheme where "urn" == scheme {
			if let path = interceptComponents?.path where path.hasPrefix("ietf:wg:oauth:2.0:oob") {
				if let title = webView.title where title.hasPrefix("Success ") {
					oauth?.logIfVerbose("Creating redirect URL from document.title")
					let qry = title.stringByReplacingOccurrencesOfString("Success ", withString: "")
					if let url = NSURL(string: "http://localhost/?\(qry)") {
                        gotIntercepted = true
						onIntercept?(url: url)
						return
					}
					else {
						oauth?.logIfVerbose("Failed to create a URL with query parts \"\(qry)\"")
					}
				}
			}
		}
		
        webView.animator().alphaValue = 1.0
		hideLoadingIndicator()
    }
    
    public func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
		if NSURLErrorDomain == error.domain && NSURLErrorCancelled == error.code {
			return
		}
		// do we still need to intercept "WebKitErrorDomain" error 102?
        
        showErrorMessage(error.localizedDescription, animated: true)
    }
    
    // MARK: - Window Delegate
    
    public func windowWillClose(notification: NSNotification) {
        onWillDismiss?(didCancel: !gotIntercepted)
    }

}

