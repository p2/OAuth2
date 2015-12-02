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


/**
    Class to handle OAuth2 requests for public clients, such as distributed Mac/iOS Apps.
 */
public class OAuth2ImplicitGrant: OAuth2 {
	
	public override class var grantType: String {
		return "implicit"
	}
	
	public override class var responseType: String? {
		return "token"
	}
	
	public override func handleRedirectURL(redirect: NSURL) {
		logIfVerbose("Handling redirect URL \(redirect.description)")
		
		// token should be in the URL fragment
		let comp = NSURLComponents(URL: redirect, resolvingAgainstBaseURL: true)
		if let fragment = comp?.percentEncodedFragment where fragment.characters.count > 0 {
			let params = OAuth2ImplicitGrant.paramsFromQuery(fragment)
			do {
				let dict = try parseAccessTokenResponse(params)
				logIfVerbose("Successfully extracted access token")
				didAuthorize(dict)
			}
			catch let err {
				didFail(err)
			}
		}
		else {
			didFail(OAuth2Error.InvalidRedirectURL(redirect.absoluteString))
		}
	}
	
	override func assureMatchesState(params: OAuth2JSON) throws {
		try super.assureMatchesState(params)
		if !context.matchesState(params["state"] as? String) {
			throw OAuth2Error.InvalidState
		}
		context.resetState()
	}
}

