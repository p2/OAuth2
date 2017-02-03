//
//  OAuth2DebugURLSessionDelegate.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/24/14.
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

import Foundation


/**
An URLSession delegate that allows you to use self-signed SSL certificates.

Doing so is a REALLY BAD IDEA, even in development environments where you can use real, free certificates that are valid a few months.
Still, sometimes you'll have to do this so this class is provided, but DO NOT SUBMIT your app using self-signed SSL certs to the App
Store. You have been warned!
*/
open class OAuth2DebugURLSessionDelegate: NSObject, URLSessionDelegate {
	
	/// The host to allow a self-signed SSL certificate for.
	let host: String
	
	
	/** Designated initializer.
	
	- parameter host: The host to which the exception should apply
	*/
	public init(host: String) {
		self.host = host
	}
	
	open func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
	                     completionHandler: @escaping (Foundation.URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
			if challenge.protectionSpace.host == host, let trust = challenge.protectionSpace.serverTrust {
				let credential = URLCredential(trust: trust)
				completionHandler(.useCredential, credential)
				return
			}
		}
		completionHandler(.performDefaultHandling, nil)
	}
}

