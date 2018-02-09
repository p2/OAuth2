//
//  OAuth2ImplicitGrant.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/9/14.
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
#if !NO_MODULE_IMPORT
import Base
#endif


/**
Class to handle OAuth2 requests for public clients, such as distributed Mac/iOS Apps.
*/
open class OAuth2ImplicitGrant: OAuth2 {
	
	override open class var grantType: String {
		return "implicit"
	}
	
	override open class var responseType: String? {
		return "token"
	}
	
	override open func handleRedirectURL(_ redirect: URL) {
		logger?.debug("OAuth2", msg: "Handling redirect URL \(redirect.description)")
		do {
			// token should be in the URL fragment
			let comp = URLComponents(url: redirect, resolvingAgainstBaseURL: true)
			guard let fragment = comp?.percentEncodedFragment, fragment.count > 0 else {
				throw OAuth2Error.invalidRedirectURL(redirect.description)
			}
			
			let params = type(of: self).params(fromQuery: fragment)
			let dict = try parseAccessTokenResponse(params: params)
			logger?.debug("OAuth2", msg: "Successfully extracted access token")
			didAuthorize(withParameters: dict)
		}
		catch let error {
			didFail(with: error.asOAuth2Error)
		}
	}
	
	override open func assureAccessTokenParamsAreValid(_ params: OAuth2JSON) throws {
		try assureMatchesState(params)
	}
}

