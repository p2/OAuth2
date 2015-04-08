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
	Enhancing the code grant flow by allowing to specify an additional "Basic xx" authorization header.

	This class will send an additional "Authorization" header when exchanging a token. Sites like Reddit require this
	additional header. Instances will use your client_id and client_secret, which will be concatenated into
	"client_id:client_secret" and then base-64 encoded, or you can specify a string for the "basic" settings key, which
	will be used like so:
	
		Authorization: Basic {basic}
 */
public class OAuth2CodeGrantBasicAuth: OAuth2CodeGrant
{
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
		Calls super's implementation to obtain a token request, then adds a "Basic" authorization header.
	 */
	public override func tokenRequestWithCode(code: String) -> NSMutableURLRequest {
		let req = super.tokenRequestWithCode(code)
		if let basic = basicToken {
			logIfVerbose("Adding \"Basic\" authorization header from full token string")
			req.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
		}
		else if !clientId.isEmpty && nil != clientSecret {
			if let utf8 = NSString(string: "\(clientId):\(clientSecret!)").dataUsingEncoding(NSUTF8StringEncoding) {
				logIfVerbose("Adding \"Basic\" authorization header from base64-encoded client_id:client_secret string")
				let token = utf8.base64EncodedStringWithOptions(nil)
				req.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
			}
		}
		else {
			logIfVerbose("Using extended code grant, but neither client_id & client_secret nor \"basic\" is specified. Using standard code grant.")
		}
		
		return req
	}
}

