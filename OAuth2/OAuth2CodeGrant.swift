//
//  OAuth2CodeGrant.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/16/14.
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
    A class to handle authorization for confidential clients via the authorization code grant method.

    This auth flow is designed for clients that are capable of protecting their client secret but can be used from installed apps. During
    code exchange and token refresh flows, **if** the client has a secret, a "Basic key:secret" Authorization header will be used. If not
    the client key will be embedded into the request body.
 */
public class OAuth2CodeGrant: OAuth2
{
	public override func authorizeURLWithRedirect(redirect: String?, scope: String?, params: [String: String]?) throws -> NSURL {
		return try authorizeURLWithBase(authURL, redirect: redirect, scope: scope, responseType: "code", params: params)
	}
	
	
	// MARK: - Token Request
	
	/**
	    Generate the URL to be used for the token request from known instance variables and supplied parameters.
	
	    This will set "grant_type" to "authorization_code", add the "code" provided and forward to `authorizeURLWithBase()` to fill the
	    remaining parameters.
	 */
	func tokenURLWithRedirect(redirect: String?, code: String, params: [String: String]? = nil) throws -> NSURL {
		var urlParams = params ?? [String: String]()
		urlParams["code"] = code
		urlParams["grant_type"] = "authorization_code"
		if let secret = clientSecret where secretInBody {
			urlParams["client_secret"] = secret
		}
		
		return try authorizeURLWithBase(tokenURL ?? authURL, redirect: redirect, scope: nil, responseType: nil, params: urlParams)
	}
	
	/**
	    Create a request for token exchange.
	 */
	func tokenRequestWithCode(code: String) throws -> NSMutableURLRequest {
		let url = try tokenURLWithRedirect(redirect, code: code)
		return try tokenRequestWithURL(url)
	}
	
	/**
	    Extracts the code from the redirect URL and exchanges it for a token.
	 */
	public override func handleRedirectURL(redirect: NSURL) {
		logIfVerbose("Handling redirect URL \(redirect.description)")
		
		let (code, error) = validateRedirectURL(redirect)
		if nil != error {
			didFail(error)
		}
		else {
			exchangeCodeForToken(code!)
		}
	}
	
	/**
	    Takes the received code and exchanges it for a token.
	 */
	func exchangeCodeForToken(code: String) {
		if (code.isEmpty) {
			didFail(genOAuth2Error("I don't have a code to exchange, let the user authorize first", .PrerequisiteFailed))
			return;
		}
		
		do {
			let post = try tokenRequestWithCode(code)
			logIfVerbose("Exchanging code \(code) with redirect \(redirect!) for access token at \(post.URL!)")
			
			performRequest(post) { data, status, error in
				if let data = data {
					do {
						let json = try self.parseAccessTokenResponse(data)
						if status < 400 && nil == json["error"] {
							self.logIfVerbose("Did exchange code for access [\(nil != self.accessToken)] and refresh [\(nil != self.refreshToken)] tokens")
							self.didAuthorize(json)
						}
						else {
							throw self.errorForErrorResponse(json)
						}
					}
					catch let err {
						self.didFail(err as NSError)
					}
				}
				else {
					self.didFail(error ?? genOAuth2Error("Error when requesting access token: no data received"))
				}
			}
		}
		catch let err {
			didFail(err as NSError)
		}
	}
	
	
	// MARK: - Utilities
	
	/**
	    Validates the redirect URI: returns a tuple with the code and nil on success, nil and an error on failure.
	 */
	func validateRedirectURL(redirect: NSURL) -> (code: String?, error: NSError?) {
		var code: String?
		var error: NSError?
		
		let comp = NSURLComponents(URL: redirect, resolvingAgainstBaseURL: true)
		if let compQuery = comp?.query where compQuery.characters.count > 0 {
			let query = OAuth2CodeGrant.paramsFromQuery(comp!.percentEncodedQuery!)
			if let cd = query["code"] {
				
				// we got a code, use it if state is correct (and reset state)
				if context.matchesState(query["state"]) {
					code = cd
					context.resetState()
				}
				else {
					error = genOAuth2Error("Invalid state, will not use the code", .InvalidState)
				}
			}
			else {
				error = errorForErrorResponse(query)
			}
		}
		else {
			error = genOAuth2Error("The redirect URL contains no query fragment", .PrerequisiteFailed)
		}
		
		return (code, error)
	}
}

