//
//  OAuth2PasswordGrant.swift
//  OAuth2
//
//  Created by Tim Sneed on 6/5/15.
//  Copyright (c) 2015 Pascal Pfiffner. All rights reserved.
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
    A class to handle authorization for clients via password grant.
 */
public class OAuth2PasswordGrant: OAuth2 {
	
	public override class var grantType: String {
		return "password"
	}
	
	/// Username to use during authentication.
	public var username: String
	
	/// The user's password.
	public var password: String
	
	/**
	Adds support for the "password" & "username" setting.
	*/
	public override init(settings: OAuth2JSON) {
		username = settings["username"] as? String ?? ""
		password = settings["password"] as? String ?? ""
		super.init(settings: settings)
	}
	
	override func doAuthorize(params params: [String : String]? = nil) {
		self.obtainAccessToken(params: params) { params, error in
			if let error = error {
				self.didFail(error)
			}
			else {
				self.didAuthorize(params ?? OAuth2JSON())
			}
		}
	}
	
	/**
	Create a token request and execute it to receive an access token.
	
	- parameter callback: The callback to call after the request has returned
	*/
	func obtainAccessToken(params params: OAuth2StringDict? = nil, callback: ((params: OAuth2JSON?, error: ErrorType?) -> Void)) {
		do {
			let post = try tokenRequest(params: params).asURLRequestFor(self)
			logger?.debug("OAuth2", msg: "Requesting new access token from \(post.URL?.description)")
			
			performRequest(post) { data, status, error in
				do {
					guard let data = data else {
						throw error ?? OAuth2Error.NoDataInResponse
					}
					
					let dict = try self.parseAccessTokenResponseData(data)
					if status < 400 {
						self.logger?.debug("OAuth2", msg: "Did get access token [\(nil != self.clientConfig.accessToken)]")
						callback(params: dict, error: nil)
					}
					else {
						callback(params: dict, error: OAuth2Error.ResponseError("The username or password is incorrect"))
					}
				}
				catch let error {
					self.logger?.debug("OAuth2", msg: "Error parsing response: \(error)")
					callback(params: nil, error: error)
				}
			}
		}
		catch let err {
			callback(params: nil, error: err)
		}
	}
	
	/**
	Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	*/
	func tokenRequest(params params: OAuth2StringDict? = nil) throws -> OAuth2AuthRequest {
		if username.isEmpty{
			throw OAuth2Error.NoUsername
		}
		if password.isEmpty{
			throw OAuth2Error.NoPassword
		}
		guard let clientId = clientConfig.clientId where !clientId.isEmpty else {
			throw OAuth2Error.NoClientId
		}
		
		let req = OAuth2AuthRequest(url: (clientConfig.tokenURL ?? clientConfig.authorizeURL))
		req.params["grant_type"] = self.dynamicType.grantType
		req.params["username"] = username
		req.params["password"] = password
		if let scope = clientConfig.scope {
			req.params["scope"] = scope
		}
		req.addParams(params: params)
		
		return req
	}
}

