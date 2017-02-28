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

#if os(iOS)
import UIKit
#endif


/**
Simple struct to hold settings describing how authorization appears to the user.
*/
public struct OAuth2AuthConfig {
	
	/// Sub-stuct holding configuration relevant to UI presentation.
	public struct UI {
		
		/// Title to propagate to views handled by OAuth2, such as OAuth2WebViewController.
		public var title: String? = nil
		
		/// By assigning your own UIBarButtonItem (!) you can override the back button that is shown in the iOS embedded web view (does NOT apply to `SFSafariViewController`).
		public var backButton: AnyObject? = nil
		
		/// If true it makes the login cancellable, otherwise the cancel button is not shown in the embedded web view.
		public var showCancelButton = true
		
		/// Starting with iOS 9, `SFSafariViewController` will be used for embedded authorization instead of our custom class. You can turn this off here.
		public var useSafariView = true
		
		#if os(iOS)
		/// By assigning your own style you can configure how the embedded authorization is presented.
		public var modalPresentationStyle = UIModalPresentationStyle.fullScreen
		
		/// Assign a UIColor here, to be applied to the Safari view controller (in iOS 10.10+) or the navigation's bar tint color if using the legacy web view controller.
		public var barTintColor: UIColor? = nil
		
		/// You can assign a UIColor here, which will be applied to Safari's (in iOS 10.10+) or the legacy web view controller's item tint colors (also see: `barTintColor`).
		public var controlTintColor: UIColor? = nil
		#endif
	}
	
	/// Whether to use an embedded web view for authorization (true) or the OS browser (false, the default).
	public var authorizeEmbedded = false
	
	/// Whether to automatically dismiss the auto-presented authorization screen.
	public var authorizeEmbeddedAutoDismiss = true

	/// Context information for the authorization flow:
	/// - iOS:   The parent view controller to present from
	/// - macOS: An NSWindow from which to present a modal sheet _or_ `nil` to present in a new window
	public var authorizeContext: AnyObject? = nil
	
	/// UI-specific configuration.
	public var ui = UI()
}

