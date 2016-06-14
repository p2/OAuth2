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
	
	override func doAuthorize(params inParams: OAuth2StringDict? = nil) {
		self.obtainAccessToken(inParams) { params, error in
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
	func obtainAccessToken(params: OAuth2StringDict? = nil, callback: ((params: OAuth2JSON?, error: ErrorType?) -> Void)) {
		do {
			let post = try tokenRequest(params).asURLRequestFor(self)
			logger?.debug("OAuth2", msg: "Requesting new access token from \(post.URL?.description ?? "nil")")
			
			performRequest(post) { data, status, error in
				do {
					guard let data = data else {
						throw error ?? OAuth2Error.NoDataInResponse
					}
					
					let params = try self.parseAccessTokenResponseData(data)
					self.logger?.debug("OAuth2", msg: "Did get access token [\(nil != self.clientConfig.accessToken)]")
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
	func tokenRequest(params: OAuth2StringDict? = nil) throws -> OAuth2AuthRequest {
		guard let clientId = clientConfig.clientId where !clientId.isEmpty else {
			throw OAuth2Error.NoClientId
		}
		guard nil != clientConfig.clientSecret else {
			throw OAuth2Error.NoClientSecret
		}
		
		let req = OAuth2AuthRequest(url: (clientConfig.tokenURL ?? clientConfig.authorizeURL))
		req.params["grant_type"] = self.dynamicType.grantType
		if let scope = clientConfig.scope {
			req.params["scope"] = scope
		}
		req.addParams(params: params)
		
		return req
	}
}

