//
//  OAuth2Request.swift
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
    A request that can be signed by an OAuth2 instance.
 */
public class OAuth2Request: NSMutableURLRequest
{
	/**
	    Convenience initalizer to instantiate and sign a mutable URL request in one go.
	 */
	convenience init(URL: NSURL!, oauth: OAuth2, cachePolicy: NSURLRequestCachePolicy, timeoutInterval: NSTimeInterval) {
		self.init(URL: URL, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
		self.sign(oauth)
	}
	
	/**
	    Signs the receiver by setting its "Authorization" header to "Bearer {token}".
	
	    Will log an error if the OAuth2 instance does not have an access token!
	 */
	func sign(oauth: OAuth2) {
		if let access = oauth.clientConfig.accessToken where !access.isEmpty {
			self.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
		}
		else {
			NSLog("Cannot sign request, access token is empty")
		}
	}
}


/**
    An NSURLSession delegate that allows you to use self-signed SSL certificates.

    Doing so is a REALLY BAD IDEA, even in development environments where you can use real, free certificates that are valid a few months.
    Still, sometimes you'll have to do this so this class is provided, but DO NOT SUBMIT your app using self-signed SSL certs to the App
    Store. You have been warned!
 */
public class OAuth2DebugURLSessionDelegate: NSObject, NSURLSessionDelegate
{
	/// The host to allow a self-signed SSL certificate for.
	let host: String
	
	public init(host: String) {
		self.host = host
	}
	
	public func URLSession(session: NSURLSession, didReceiveChallenge challenge: NSURLAuthenticationChallenge,
		completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
		if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
			if challenge.protectionSpace.host == host {
				let credential = NSURLCredential(forTrust: challenge.protectionSpace.serverTrust!)
				completionHandler(.UseCredential, credential)
				return
			}
		}
		completionHandler(.CancelAuthenticationChallenge, nil)
	}
}

