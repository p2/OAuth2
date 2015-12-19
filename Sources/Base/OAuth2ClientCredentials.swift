//
//  OAuth2ClientCredentials.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 5/27/15.
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

import Foundation


/**
    Class to handle two-legged OAuth2 requests of the "client_credentials" type.
 */
public class OAuth2ClientCredentials: OAuth2 {
	
	public override class var grantType: String {
		return "client_credentials"
	}
	
	override func doAuthorize(params params: OAuth2StringDict? = nil) {
		self.obtainAccessToken() { params, error in
			if let error = error {
				self.didFail(error)
			}
			else {
				self.didAuthorize(params ?? OAuth2JSON())
			}
		}
	}
	
	/**
	Use the client credentials to retrieve a fresh access token.
	
	- parameter callback: The callback to call after the process has finished
	*/
	func obtainAccessToken(callback: ((params: OAuth2JSON?, error: ErrorType?) -> Void)) {
		do {
			let post = try tokenRequest()
			logIfVerbose("Requesting new access token from \(post.URL?.description)")
			
			performRequest(post) { data, status, error in
				do {
					guard let data = data else {
						throw error ?? OAuth2Error.NoDataInResponse
					}
					
					let params = try self.parseAccessTokenResponse(data)
					self.logIfVerbose("Did get access token [\(nil != self.clientConfig.accessToken)]")
					callback(params: params, error: nil)
				}
				catch let error {
					callback(params: nil, error: error)
				}
			}
		}
		catch let error {
			callback(params: nil, error: error)
		}
	}
	
	/**
	Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	*/
	func tokenRequest() throws -> NSMutableURLRequest {
		guard let clientId = clientConfig.clientId where !clientId.isEmpty else {
			throw OAuth2Error.NoClientId
		}
		guard let secret = clientConfig.clientSecret else {
			throw OAuth2Error.NoClientSecret
		}
		
		let req = NSMutableURLRequest(URL: clientConfig.tokenURL ?? clientConfig.authorizeURL)
		req.HTTPMethod = "POST"
		req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
        
		// check if scope is set
		var body = "grant_type=client_credentials"
		if let scope = clientConfig.scope {
			body += "&scope=\(scope.wwwFormURLEncodedString)"
		}
		if authConfig.secretInBody {
			logIfVerbose("Adding “client_id” and “client_secret” to request body")
			body += "&client_id=\(clientId.wwwFormURLEncodedString)&client_secret=\(secret.wwwFormURLEncodedString)"
		}
		
		// add Authorization header (if not in body)
		else {
			logIfVerbose("Adding “Authorization” header as “Basic client-key:client-secret”")
			let pw = "\(clientId.wwwFormURLEncodedString):\(secret.wwwFormURLEncodedString)"
			if let utf8 = pw.dataUsingEncoding(NSUTF8StringEncoding) {
				req.setValue("Basic \(utf8.base64EncodedStringWithOptions([]))", forHTTPHeaderField: "Authorization")
			}
			else {
				throw OAuth2Error.UTF8EncodeError
			}
		}
		req.HTTPBody = body.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		
		return req
	}
}

