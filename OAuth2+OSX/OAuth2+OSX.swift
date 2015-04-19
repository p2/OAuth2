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
	public func openAuthorizeURLInBrowser(params: [String: String]? = nil) -> Bool {
		let url = authorizeURL(params: params)
		return NSWorkspace.sharedWorkspace().openURL(url)
	}
}

