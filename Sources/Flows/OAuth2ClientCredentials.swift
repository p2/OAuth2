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
#if !NO_MODULE_IMPORT
import Base
#endif


/**
Class to handle two-legged OAuth2 requests of the "client_credentials" type.
*/
public class OAuth2ClientCredentials: OAuth2 {
	
	public override class var grantType: String {
		return "client_credentials"
	}
	
	public override func doAuthorize(params inParams: OAuth2StringDict? = nil) {
		self.obtainAccessToken(params: inParams) { params, error in
			if let error = error {
				self.didFail(withError: error)
			}
			else {
				self.didAuthorize(withParameters: params ?? OAuth2JSON())
			}
		}
	}
	
	/**
	Use the client credentials to retrieve a fresh access token.
	
	- parameter callback: The callback to call after the process has finished
	*/
	func obtainAccessToken(params: OAuth2StringDict? = nil, callback: ((params: OAuth2JSON?, error: Error?) -> Void)) {
		do {
			let post = try tokenRequest(params: params).asURLRequestFor(self)
			logger?.debug("OAuth2", msg: "Requesting new access token from \(post.url?.description ?? "nil")")
			
			performRequest(post) { data, status, error in
				do {
					guard let data = data else {
						throw error ?? OAuth2Error.noDataInResponse
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
		guard let clientId = clientConfig.clientId, !clientId.isEmpty else {
			throw OAuth2Error.noClientId
		}
		guard nil != clientConfig.clientSecret else {
			throw OAuth2Error.noClientSecret
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

