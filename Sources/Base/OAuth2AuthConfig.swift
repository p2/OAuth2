//
//  OAuth2AuthConfig.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 16/11/15.
//  Copyright © 2015 Pascal Pfiffner. All rights reserved.
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


/**
    Simple struct to hold client-side authorization configuration variables.
*/
public struct OAuth2AuthConfig
{
	public struct UI {
		
		/// Title to propagate to views handled by OAuth2, such as OAuth2WebViewController.
		public var title: String? = nil
		
		// TODO: figure out a neat way to make this a UIBarButtonItem if compiled for iOS
		/// By assigning your own UIBarButtonItem (!) you can override the back button that is shown in the iOS embedded web view (does NOT apply to `SFSafariViewController`).
		public var backButton: AnyObject? = nil
		
		/// Starting with iOS 9, `SFSafariViewController` will be used for embedded authorization instead of our custom class. You can turn this off here.
		public var useSafariView = true
		
		/// Internally used to store the `SFSafariViewControllerDelegate`.
		var safariViewDelegate: AnyObject?
	}
	
	/// Whether the receiver should use the request body instead of the Authorization header for the client secret.
	public var secretInBody = false
	
	/// Whether to use an embedded web view for authorization (true) or the OS browser (false, the default).
	public var authorizeEmbedded = false
	
	/// Whether to automatically dismiss the auto-presented authorization screen.
	public var authorizeEmbeddedAutoDismiss = true
	
	/// Context information for the authorization flow; e.g. the parent view controller to use on iOS.
	public var authorizeContext: AnyObject? = nil
	
	/// UI-specific configuration.
	public var ui = UI()
}

