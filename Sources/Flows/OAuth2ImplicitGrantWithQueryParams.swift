//
//  OAuth2ImplicitGrantWithQueryParams.swift
//  OAuth2
//
//  Created by Tim Schmitz on 5/3/18.
//  Copyright 2018 Tim Schmitz
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
 Class to handle OAuth2 implicit grant requests that return params in the query
 instead of the fragment.
 */
open class OAuth2ImplicitGrantWithQueryParams: OAuth2ImplicitGrant {

	override open func handleRedirectURL(_ redirect: URL) {
		logger?.debug("OAuth2", msg: "Handling redirect URL \(redirect.description)")
		do {
			// token should be in the URL query
			let comp = URLComponents(url: redirect, resolvingAgainstBaseURL: true)
			guard let query = comp?.query, query.count > 0 else {
				throw OAuth2Error.invalidRedirectURL(redirect.description)
			}

			let params = type(of: self).params(fromQuery: query)
			let dict = try parseAccessTokenResponse(params: params)
			logger?.debug("OAuth2", msg: "Successfully extracted access token")
			didAuthorize(withParameters: dict)
		}
		catch let error {
			didFail(with: error.asOAuth2Error)
		}
	}
}
