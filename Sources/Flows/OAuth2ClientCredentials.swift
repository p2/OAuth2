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
open class OAuth2ClientCredentials: OAuth2 {
	
	override open class var grantType: String {
		return "client_credentials"
	}
	
	override open func doAuthorize(params inParams: OAuth2StringDict? = nil) {
		self.obtainAccessToken(params: inParams) { params, error in
			if let error = error {
				self.didFail(with: error.asOAuth2Error)
			}
			else {
				self.didAuthorize(withParameters: params ?? OAuth2JSON())
			}
		}
	}
	
	/**
	Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	*/
	open func accessTokenRequest(params: OAuth2StringDict? = nil) throws -> OAuth2AuthRequest {
		guard let clientId = clientConfig.clientId, !clientId.isEmpty else {
			throw OAuth2Error.noClientId
		}
		guard nil != clientConfig.clientSecret else {
			throw OAuth2Error.noClientSecret
		}
		
		let req = OAuth2AuthRequest(url: (clientConfig.tokenURL ?? clientConfig.authorizeURL))
		req.params["grant_type"] = type(of: self).grantType
		if let scope = clientConfig.scope {
			req.params["scope"] = scope
		}
		req.add(params: params)
		
		return req
	}
	
	/**
	Use the client credentials to retrieve a fresh access token.
	
	Uses `accessTokenRequest(params:)` to create the request, which you can subclass to change implementation specifics.
	
	- parameter callback: The callback to call after the process has finished
	*/
	public func obtainAccessToken(params: OAuth2StringDict? = nil, callback: @escaping ((_ params: OAuth2JSON?, _ error: OAuth2Error?) -> Void)) {
		do {
			let post = try accessTokenRequest(params: params).asURLRequest(for: self)
			logger?.debug("OAuth2", msg: "Requesting new access token from \(post.url?.description ?? "nil")")
			
			perform(request: post) { response in
				do {
					let data = try response.responseData()
					let params = try self.parseAccessTokenResponse(data: data)
					self.logger?.debug("OAuth2", msg: "Did get access token [\(nil != self.clientConfig.accessToken)]")
					callback(params, nil)
				}
				catch let error {
					callback(nil, error.asOAuth2Error)
				}
			}
		}
		catch let error {
			callback(nil, error.asOAuth2Error)
		}
	}
}

