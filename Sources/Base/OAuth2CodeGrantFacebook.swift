//
//  OAuth2CodeGrantFacebook.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 2/1/15.
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
    Facebook only returns an "access_token=xyz&..." string, no true JSON, hence we override `parseTokenExchangeResponse`
    and deal with the situation in a subclass.
 */
public class OAuth2CodeGrantFacebook: OAuth2CodeGrant {
	
	/**
	Facebook doesn't return JSON but a plain URL-query-like string. This override takes care of the situation and extracts the token from
	the response.
	*/
	override public func parseAccessTokenResponseData(data: NSData) throws -> OAuth2JSON {
		guard let str = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else {
			throw OAuth2Error.UTF8DecodeError
		}
		let query = self.dynamicType.paramsFromQuery(str)
		return try parseAccessTokenResponse(query)
	}
}

