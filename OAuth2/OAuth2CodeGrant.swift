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
	/// The URL string where we can exchange a code for a token; if nil `authURL` will be used.
	public let tokenURL: NSURL?
	
	/// The receiver's long-time refresh token.
	public var refreshToken: String?
	
	/// Whether the receiver should use the request body instead of the Authorization header for the client secret.
	public var secretInBody: Bool = false
	
	
	/**
	    Adds support for the "token_uri" setting.
	 */
	public override init(settings: OAuth2JSON) {
		if let token = settings["token_uri"] as? String {
			tokenURL = NSURL(string: token)
		}
		else {
			tokenURL = nil
		}
		if let inBody = settings["secret_in_body"] as? Bool {
			secretInBody = inBody
		}
		
		super.init(settings: settings)
	}
	
	public override func authorizeURLWithRedirect(redirect: String?, scope: String?, params: [String: String]?) throws -> NSURL {
		return try authorizeURLWithBase(authURL, redirect: redirect, scope: scope, responseType: "code", params: params)
	}
	
	/**
	    Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	 */
	func tokenRequestWithURL(url: NSURL) throws -> NSMutableURLRequest {
		if clientId.isEmpty {
			throw OAuth2IncompleteSetup.NoClientId
		}
		
		let comp = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
		assert(comp != nil, "It seems NSURLComponents cannot parse \(url)");
		let body = comp!.percentEncodedQuery
		comp!.query = nil
		
		let req = NSMutableURLRequest(URL: comp!.URL!)
		req.HTTPMethod = "POST"
		req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
		req.HTTPBody = body?.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		
		// add Authorization header if we have a client secret (even if it's empty)
		if let secret = clientSecret where !secretInBody {
			logIfVerbose("Adding “Authorization” header as “Basic client-key:client-secret”")
			let pw = "\(clientId.wwwFormURLEncodedString):\(secret.wwwFormURLEncodedString)"
			if let utf8 = pw.dataUsingEncoding(NSUTF8StringEncoding) {
				req.setValue("Basic \(utf8.base64EncodedStringWithOptions([]))", forHTTPHeaderField: "Authorization")
			}
			else {
				logIfVerbose("ERROR: for some reason failed to base-64 encode the client-key:client-secret combo")
			}
		}
		
		return req
	}
	
	
	// MARK: - Keychain
	
	override func updateFromKeychainItems(items: [String: NSCoding]) {
		super.updateFromKeychainItems(items)
		
		if let token = items["refreshToken"] as? String where !token.isEmpty {
			logIfVerbose("Found refresh token")
			refreshToken = token
		}
	}
	
	override func storableKeychainItems() -> [String: NSCoding]? {
		if var items = super.storableKeychainItems() {
			if let refresh = refreshToken where !refresh.isEmpty {
				items["refreshToken"] = refresh
			}
			return items
		}
		return nil
	}
	
	override public func forgetTokens() {
		super.forgetTokens()
		refreshToken = nil
	}
	
	
	// MARK: - Authorization
	
	override public func tryToObtainAccessTokenIfNeeded(callback: (Bool -> Void)) {
		if hasUnexpiredAccessToken() {
			callback(true)
		}
		else {
			logIfVerbose("No access token, maybe I can refresh")
			doRefreshToken({ successParams, error in
				if nil != successParams {
					callback(true)
				}
				else {
					if let err = error {
						self.logIfVerbose("\(err.localizedDescription)")
					}
					callback(false)
				}
			})
		}
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
		
		return try authorizeURLWithBase(tokenURL ?? authURL, redirect: redirect, scope: nil, responseType: nil, params: urlParams, isTokenRequest: true)
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
	
	/**
	    Parse the NSData object returned while exchanging the code for a token in `exchangeCodeForToken`.
	
	    - returns: A OAuth2JSON, which is usually returned upon token exchange and may contain additional information
	 */
	override func parseAccessTokenResponse(data: NSData) throws -> OAuth2JSON {
		let json = try super.parseAccessTokenResponse(data)
		if let refresh = json["refresh_token"] as? String {
			refreshToken = refresh
		}
		return json
	}
	
	
	// MARK: - Refresh Token
	
	/**
	    Generate the URL to be used for the token request when we have a refresh token.
	
	    This will set "grant_type" to "refresh_token", add the refresh token, then forward to `authorizeURLWithBase()` to fill the remaining
	    parameters.
	 */
	func tokenURLWithRefreshToken(redirect: String?, refreshToken: String, params: [String: String]? = nil) throws -> NSURL {
		var urlParams = params ?? [String: String]()
		urlParams["grant_type"] = "refresh_token"
		urlParams["refresh_token"] = refreshToken
		if let secret = clientSecret where secretInBody {
			urlParams["client_secret"] = secret
		}
		
		return try authorizeURLWithBase(tokenURL ?? authURL, redirect: redirect, scope: nil, responseType: nil, params: urlParams, isTokenRequest: true)
	}
	
	/**
	    Create a request for token refresh.
	 */
	func tokenRequestWithRefreshToken(refreshToken: String) throws -> NSMutableURLRequest {
		let url = try tokenURLWithRefreshToken(redirect, refreshToken: refreshToken)
		return try tokenRequestWithURL(url)
	}
	
	/**
	    If there is a refresh token, use it to receive a fresh access token.
	
	    - parameter callback: The callback to call after the refresh token exchange has finished
	 */
	public func doRefreshToken(callback: ((successParams: OAuth2JSON?, error: NSError?) -> Void)) {
		guard let refresh = refreshToken where !refresh.isEmpty else {
			callback(successParams: nil, error: genOAuth2Error("I don't have a refresh token, not trying to refresh", .PrerequisiteFailed))
			return
		}
		
		do {
			let post = try tokenRequestWithRefreshToken(refresh)
			logIfVerbose("Using refresh token to receive access token from \(post.URL?.description)")
			
			performRequest(post) { data, status, error in
				if let data = data {
					do {
						let json = try self.parseAccessTokenResponse(data)
						if status < 400 && nil == json["error"] {			// we might get a 200 with an error message from some servers
							self.logIfVerbose("Did use refresh token for access token [\(nil != self.accessToken)]")
							callback(successParams: json, error: nil)
						}
						else {
							throw self.errorForErrorResponse(json)
						}
					}
					catch let err {
						self.logIfVerbose("Error parsing refreshed access token: \((err as NSError).localizedDescription)")
						callback(successParams: nil, error: err as NSError)
					}
				}
				else {
					callback(successParams: nil, error: error ?? genOAuth2Error("Unknown error during token refresh"))
				}
			}
		}
		catch let err {
			callback(successParams: nil, error: err as NSError)
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

