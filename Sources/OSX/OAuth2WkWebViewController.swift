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
	
	public override func loadView() {
		super.loadView()
	}
	
//	override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
//		
//	}
	
	init(startURL: NSURL?) {
		self.startURL = startURL
		let bundle = NSBundle(identifier: "org.chip.OAuth2")!
		super.init(nibName: "OAuth2WkWebViewController", bundle: bundle)!
	}
	
	required public init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)!
	}

	
}