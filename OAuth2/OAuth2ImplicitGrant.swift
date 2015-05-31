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
public class OAuth2ImplicitGrant: OAuth2
{
	public override func authorizeURLWithRedirect(redirect: String?, scope: String?, params: [String: String]?) -> NSURL {
		return authorizeURLWithBase(authURL, redirect: redirect, scope: scope, responseType: "token", params: params)
	}
	
	public override func handleRedirectURL(redirect: NSURL) {
		logIfVerbose("Handling redirect URL \(redirect.description)")
		
		var error: NSError?
		var comp = NSURLComponents(URL: redirect, resolvingAgainstBaseURL: true)
		
		// token should be in the URL fragment
		if let fragment = comp?.percentEncodedFragment where count(fragment) > 0 {
			let params = OAuth2ImplicitGrant.paramsFromQuery(fragment)
			if let token = params["access_token"] where !token.isEmpty {
				if let tokType = params["token_type"] {
					if "bearer" == tokType.lowercaseString {
						
						// got a "bearer" token, use it if state checks out
						if let tokState = params["state"] {
							if tokState == state {
								accessToken = token
								accessTokenExpiry = nil
								if let expires = params["expires_in"]?.toInt() {
									accessTokenExpiry = NSDate(timeIntervalSinceNow: NSTimeInterval(expires))
								}
								logIfVerbose("Successfully extracted access token")
								didAuthorize(params)
								return
							}
							
							error = genOAuth2Error("Invalid state \(tokState), will not use the token", .InvalidState)
						}
						else {
							error = genOAuth2Error("No state returned, will not use the token", .InvalidState)
						}
					}
					else {
						error = genOAuth2Error("Only \"bearer\" token is supported, but received \"\(tokType)\"", .Unsupported)
					}
				}
				else {
					error = genOAuth2Error("No token type received, will not use the token", .PrerequisiteFailed)
				}
			}
			else {
				error = errorForErrorResponse(params)
			}
		}
		else {
			error = genOAuth2Error("Invalid redirect URL: \(redirect)", .PrerequisiteFailed)
		}
		
		didFail(error)
	}
}

