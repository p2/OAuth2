//
//  OAuth2+OSX.swift
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

import Cocoa


extension OAuth2
{
	/**
	    Uses `NSWorkspace` to open the authorize URL in the OS browser.
	
	    :param: params Additional parameters to pass to the authorize URL
	    :returs: A bool indicating success
	 */
	public final func openAuthorizeURLInBrowser(params: [String: String]? = nil) -> Bool {
		let url = authorizeURL(params: params)
		return NSWorkspace.sharedWorkspace().openURL(url)
	}
	
	
	// MARK: - Embedded View (NOT IMPLEMENTED)
	
	/**
	    Tries to use the given context, which on OS X should be a NSViewController, to present the authorization screen.
	
	    :returns: A bool indicating whether the method was able to show the authorize screen
	 */
	public func authorizeEmbeddedWith(context: AnyObject?, params: [String: String]? = nil, autoDismiss: Bool = true) -> Bool {
		if let controller = context as? NSViewController {
			let web: AnyObject = authorizeEmbeddedFrom(controller, params: params)
			if autoDismiss {
				internalAfterAuthorizeOrFailure = { wasFailure, error in
					self.logIfVerbose("Should now dismiss \(web)")
				}
			}
			return true
		}
		return false
	}
	
	public func authorizeEmbeddedFrom(controller: NSViewController, params: [String: String]?) -> AnyObject {
		fatalError("Not yet implemented")
	}
}

