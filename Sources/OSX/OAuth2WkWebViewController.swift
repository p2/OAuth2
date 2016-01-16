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

	
}