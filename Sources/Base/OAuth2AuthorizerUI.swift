//
//  OAuth2AuthorizerUI.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 21/07/16.
//  Copyright 2016 Pascal Pfiffner
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

import Foundation


/**
Platform-dependent authorizers must adopt this protocol.
*/
public protocol OAuth2AuthorizerUI {
	
	/// The OAuth2 instance this authorizer belongs to.
	unowned var oauth2: OAuth2Base { get }
	
	/**
	Open the authorize URL in the OS browser.
	
	- parameter url: The authorize URL to open
	- throws:        UnableToOpenAuthorizeURL on failure
	*/
	func openAuthorizeURLInBrowser(_ url: URL) throws
	
	/**
	Tries to use the given context to present the authorization screen. Context could be a UIViewController for iOS or an NSWindow on macOS.
	
	- parameter with: The configuration to be used; usually uses the instance's `authConfig`
	- parameter at:   The authorize URL to open
	- throws:         Can throw OAuth2Error if the method is unable to show the authorize screen
	*/
	func authorizeEmbedded(with config: OAuth2AuthConfig, at url: URL) throws
}
