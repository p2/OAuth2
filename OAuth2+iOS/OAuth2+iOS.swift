//
//  OAuth2+iOS.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 4/19/15.
//  Copyright 2015 Pascal Pfiffner
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
	    Uses `UIApplication` to open the authorize URL in iOS's browser.
	
	    :param: params Additional parameters to pass to the authorize URL
	    :returs: A bool indicating success
	 */
	public final func openAuthorizeURLInBrowser(params: [String: String]? = nil) -> Bool {
		let url = authorizeURL(params: params)
		return UIApplication.sharedApplication().openURL(url)
	}
	
	
	// MARK: - Built-In Web View
	
	/**
	    Tries to use the given context, which on iOS should be a UIViewController, to present the authorization screen.
	
	    :returns: A bool indicating whether the method was able to show the authorize screen
	 */
	public func authorizeEmbeddedWith(context: AnyObject?, params: [String: String]? = nil, autoDismiss: Bool = true) -> Bool {
		if let controller = context as? UIViewController {
			let web = authorizeEmbeddedFrom(controller, params: params)
			if autoDismiss {
				internalAfterAuthorizeOrFailure = { wasFailure, error in
					web.dismissViewControllerAnimated(true, completion: nil)
				}
			}
			return true
		}
		return false
	}
	
	/**
	    Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads the authorize URL.
	
	    Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the web view controller
	    automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply call this method first, then assign
	    that closure in which you call `dismissViewController()` on the returned web view controller instance.
	
	    :raises: Will raise if the authorize URL cannot be constructed from the settings used during initialization.
	
	    :param: controller The view controller to use for presentation
	    :param: params     Optional additional URL parameters
	    :returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	*/
	public func authorizeEmbeddedFrom(controller: UIViewController, params: [String: String]? = nil) -> OAuth2WebViewController {
		let url = authorizeURL(params: params)
		return presentAuthorizeViewFor(url, intercept: redirect!, from: controller)
	}
	
	/**
	    Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads the authorize URL.
	
	    Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the web view controller
	    automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply call this method first, then assign
	    that closure in which you call `dismissViewController()` on the returned web view controller instance.
	    
	    :param: controller The view controller to use for presentation
	    :param: redirect   The redirect URL to use
	    :param: scope      The scope to use
	    :param: params     Optional additional URL parameters
	    :returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	 */
	public func authorizeEmbeddedFrom(controller: UIViewController,
	                                    redirect: String,
	                                       scope: String,
	                                      params: [String: String]? = nil) -> OAuth2WebViewController {
		let url = authorizeURLWithRedirect(redirect, scope: scope, params: params)
		return presentAuthorizeViewFor(url, intercept: redirect, from: controller)
	}
	
	/**
	    Presents and returns a web view controller loading the given URL and intercepting the given URL.
	
	    :returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
	 */
	final func presentAuthorizeViewFor(url: NSURL, intercept: String, from: UIViewController) -> OAuth2WebViewController {
		let web = OAuth2WebViewController()
		web.title = viewTitle
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

