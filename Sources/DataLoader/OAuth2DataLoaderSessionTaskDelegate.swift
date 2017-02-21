//
//  OAuth2DataLoaderSessionTaskDelegate.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 03.02.17.
//  Copyright © 2017 Pascal Pfiffner. All rights reserved.
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
#if !NO_MODULE_IMPORT
import Base
#endif


/**
Simple implementation of a session task delegate, which looks at HTTP redirecting, approving redirects in the same domain and re-signing the
redirected request.
*/
open class OAuth2DataLoaderSessionTaskDelegate: NSObject, URLSessionTaskDelegate {
	
	/// The loader to which the delegate belongs, needed for request signing.
	public internal(set) weak var loader: OAuth2DataLoader?
	
	/// Only redirects against this host will be approved.
	public let host: String
	
	/**
	Designated initializer.
	
	- parameter loader: The data loader for which the receiver is delegating
	- parameter host:   The host on which HTTP redirecting will be approved; will be run through `URLComponents` to satisfy formatting
	*/
	public init(loader: OAuth2DataLoader, host: String) {
		self.loader = loader
		self.host = URLComponents(string: host)?.host ?? host
	}
	
	
	// MARK: - URLSessionTaskDelegate
	
	open func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
		guard request.url?.host == host else {
			loader?.logger?.warn("OAuth2", msg: "Redirected to «\(request.url?.host ?? "nil")» but only approving HTTP redirection on «\(host)», not following redirect: \(request)")
			completionHandler(nil)
			return
		}
		do {
			guard let loader = loader else {
				throw OAuth2Error.generic("no loader instance, cannot re-sign")
			}
			let newRequest = try request.signed(with: loader.oauth2)
			loader.logger?.debug("OAuth2", msg: "Following HTTP redirection to «\(request.url?.description ?? "nil")»")
			completionHandler(newRequest)
		}
		catch {
			loader?.logger?.warn("OAuth2", msg: "Failed to re-sign request after HTTP redirection: \(error)")
			completionHandler(request)
		}
	}
}

