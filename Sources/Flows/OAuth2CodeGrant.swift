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
#if !NO_MODULE_IMPORT
import Base
#endif


/**
A class to handle authorization for confidential clients via the authorization code grant method.

This auth flow is designed for clients that are capable of protecting their client secret but can be used from installed apps. During code
exchange and token refresh flows, **if** the client has a secret, a "Basic key:secret" Authorization header will be used. If not the client
key will be embedded into the request body.
*/
public class OAuth2CodeGrant: OAuth2 {
	
	public override class var grantType: String {
		return "authorization_code"
	}
	
	override public class var responseType: String? {
		return "code"
	}
	
	
	// MARK: - Token Request
	
	/**
	Generate the request to be used for the token request from known instance variables and supplied parameters.
	
	This will set "grant_type" to "authorization_code", add the "code" provided and fill the remaining parameters. The "client_id" is only
	added if there is no secret (public client) or if the request body is used for id and secret.
	
	- parameter code: The code you want to exchange for an access token
	- parameter params: Optional additional params to add as URL parameters
	- returns: A request you can use to create a URL request to exchange the code for an access token
	*/
	func tokenRequestWithCode(_ code: String, params: OAuth2StringDict? = nil) throws -> OAuth2AuthRequest {
		guard let clientId = clientConfig.clientId where !clientId.isEmpty else {
			throw OAuth2Error.noClientId
		}
		guard let redirect = context.redirectURL else {
			throw OAuth2Error.noRedirectURL
		}
		
		let req = OAuth2AuthRequest(url: (clientConfig.tokenURL ?? clientConfig.authorizeURL))
		req.params["code"] = code
		req.params["grant_type"] = self.dynamicType.grantType
		req.params["redirect_uri"] = redirect
		req.params["client_id"] = clientId
		
		return req
	}
	
	/**
	Extracts the code from the redirect URL and exchanges it for a token.
	*/
	override public func handleRedirectURL(_ redirect: URL) {
		logger?.debug("OAuth2", msg: "Handling redirect URL \(redirect.description)")
		do {
			let code = try validateRedirectURL(redirect)
			exchangeCodeForToken(code)
		}
		catch let error {
			didFail(withError: error)
		}
	}
	
	/**
	Takes the received code and exchanges it for a token.
	*/
	public func exchangeCodeForToken(_ code: String) {
		do {
			guard !code.isEmpty else {
				throw OAuth2Error.prerequisiteFailed("I don't have a code to exchange, let the user authorize first")
			}
			
			let post = try tokenRequestWithCode(code).asURLRequestFor(self)
			logger?.debug("OAuth2", msg: "Exchanging code \(code) for access token at \(post.url!)")
			
			performRequest(post) { data, status, error in
				do {
					guard let data = data else {
						throw error ?? OAuth2Error.noDataInResponse
					}
					
					let params = try self.parseAccessTokenResponseData(data)
					if status < 400 {
						self.logger?.debug("OAuth2", msg: "Did exchange code for access [\(nil != self.clientConfig.accessToken)] and refresh [\(nil != self.clientConfig.refreshToken)] tokens")
						self.didAuthorize(withParameters: params)
					}
					else {
						throw OAuth2Error.generic("\(status)")
					}
				}
				catch let error {
					self.didFail(withError: error)
				}
			}
		}
		catch let error {
			didFail(withError: error)
		}
	}
	
	
	// MARK: - Utilities
	
	/**
	Validates the redirect URI: returns a tuple with the code and nil on success, nil and an error on failure.
	*/
	func validateRedirectURL(_ redirect: URL) throws -> String {
		guard let expectRedirect = context.redirectURL else {
			throw OAuth2Error.noRedirectURL
		}
		let comp = URLComponents(url: redirect, resolvingAgainstBaseURL: true)
		if !(redirect.absoluteString?.hasPrefix(expectRedirect))! && (!(redirect.absoluteString?.hasPrefix("urn:ietf:wg:oauth:2.0:oob"))! && "localhost" != comp?.host) {
			throw OAuth2Error.invalidRedirectURL("Expecting «\(expectRedirect)» but received «\(redirect)»")
		}
		if let compQuery = comp?.query where compQuery.characters.count > 0 {
			let query = OAuth2CodeGrant.params(fromQuery: comp!.percentEncodedQuery!)
			try assureNoErrorInResponse(query)
			if let cd = query["code"] {
				
				// we got a code, use it if state is correct (and reset state)
				try assureMatchesState(query)
				return cd
			}
			throw OAuth2Error.responseError("No “code” received")
		}
		throw OAuth2Error.prerequisiteFailed("The redirect URL contains no query fragment")
	}
}

