//
//  OAuth2CodeGrantBasicAuth.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 3/27/15.
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
    Enhancing the code grant flow by allowing to specify a specific "Basic xx" authorization header.

    This class allows you to manually set the "Authorization" header to a given string, as accepted in its `basicToken` property. It will
    override the superclasses automatic generation of an Authorization header if the client has a clientSecret, so you only need to use
    this subclass if you need a different header (this is different to version 1.2.3 and earlier of this framework).
 */
public class OAuth2CodeGrantBasicAuth: OAuth2CodeGrant {
	
	/// The full token string to be used in the authorization header.
	var basicToken: String?
	
	/**
	Adds support to override the basic Authorization header value by specifying:
	
	- basic: takes precedence over client_id and client_secret for the token request Authorization header
	*/
	public override init(settings: OAuth2JSON) {
		if let basic = settings["basic"] as? String {
			basicToken = basic
		}
		super.init(settings: settings)
	}
	
	/**
	Calls super's implementation to obtain a token request, then adds the custom "Basic" authorization header.
	*/
	override func tokenRequestWithCode(code: String, params: OAuth2StringDict? = nil) throws -> OAuth2AuthRequest {
		let req = try super.tokenRequestWithCode(code, params: params)
		if let basic = basicToken {
			logger?.debug("OAuth2", msg: "Overriding “Basic” authorization header, as specified during client initialization")
			req.headerAuthorize = "Basic \(basic)"
		}
		else {
			logger?.warn("OAuth2", msg: "Using extended code grant, but “basicToken” is not actually specified. Using standard code grant.")
		}
		return req
	}
}

