//
//  OAuth2Base.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/4/14.
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
Class extending on OAuth2Requestable, exposing configuration and maintaining context, serving as base class for `OAuth2`.
*/
open class OAuth2Base: OAuth2Securable {
	
	/// The grant type represented by the class, e.g. "authorization_code" for code grants.
	open class var grantType: String {
		return "__undefined"
	}
	
	/// The response type expected from an authorize call, e.g. "code" for code grants.
	open class var responseType: String? {
		return nil
	}
	
	/// Settings related to the client-server relationship.
	open let clientConfig: OAuth2ClientConfig
	
	/// Client-side authorization options.
	open var authConfig = OAuth2AuthConfig()
	
	/// The client id.
	public final var clientId: String? {
		get { return clientConfig.clientId }
		set { clientConfig.clientId = newValue }
	}
	
	/// The client secret, usually only needed for code grant.
	public final var clientSecret: String? {
		get { return clientConfig.clientSecret }
		set { clientConfig.clientSecret = newValue }
	}
	
	/// The name of the client, as used during dynamic client registration. Use "client_name" during initalization to set.
	open var clientName: String? {
		get { return clientConfig.clientName }
	}
	
	/// The URL to authorize against.
	public final var authURL: URL {
		get { return clientConfig.authorizeURL }
	}

	/// The URL string where we can exchange a code for a token; if nil `authURL` will be used.
	public final var tokenURL: URL? {
		get { return clientConfig.tokenURL }
	}
	
	/// The scope currently in use.
	public final var scope: String? {
		get { return clientConfig.scope }
		set { clientConfig.scope = newValue }
	}
	
	/// The redirect URL string to use.
	public final var redirect: String? {
		get { return clientConfig.redirect }
		set { clientConfig.redirect = newValue }
	}
	
	/// Context for the current auth dance.
	open var context = OAuth2ContextStore()
	
	/// The receiver's access token.
	open var accessToken: String? {
		get { return clientConfig.accessToken }
		set { clientConfig.accessToken = newValue }
	}
	
	/// The receiver's id token.
	open var idToken: String? {
		get { return clientConfig.idToken }	
		set { clientConfig.idToken = newValue }
	}

	/// The access token's expiry date.
	open var accessTokenExpiry: Date? {
		get { return clientConfig.accessTokenExpiry }
		set { clientConfig.accessTokenExpiry = newValue }
	}
	
	/// The receiver's long-time refresh token.
	open var refreshToken: String? {
		get { return clientConfig.refreshToken }
		set { clientConfig.refreshToken = newValue }
	}
	
	/// Custom or overridden HTML headers to be used during authorization.
	public var authHeaders: OAuth2Headers? {
		get { return clientConfig.authHeaders }
		set { clientConfig.authHeaders = newValue }
	}
	
	/// Custom authorization parameters.
	public var authParameters: OAuth2StringDict? {
		get { return clientConfig.customParameters }
		set { clientConfig.customParameters = newValue }
	}
	
	
	/// This closure is internally used with `authorize(params:callback:)` and only exposed for subclassing reason, do not mess with it!
	public final var didAuthorizeOrFail: ((_ parameters: OAuth2JSON?, _ error: OAuth2Error?) -> Void)?
	
	/// Returns true if the receiver is currently authorizing.
	public final var isAuthorizing: Bool {
		return nil != didAuthorizeOrFail
	}
	
	/**
	Closure called after the regular authorization callback, on the main thread. You can use this callback when you're performing
	authorization manually and/or for cleanup operations.
	
	- parameter authParameters: All authorization parameters; non-nil (but possibly empty) on success, nil on error
	- parameter error:          OAuth2Error giving the failure reason; if nil and `authParameters` is also nil, the process was aborted.
	*/
	public final var afterAuthorizeOrFail: ((_ authParameters: OAuth2JSON?, _ error: OAuth2Error?) -> Void)?
	
	/**
	For internal use, don't mess with it, it's public only for subclassing and compilation reasons. Executed right before
	`afterAuthorizeOrFail`.
	*/
	public final var internalAfterAuthorizeOrFail: ((_ wasFailure: Bool, _ error: OAuth2Error?) -> Void)?
	
	
	/**
	Designated initializer.
	
	The following settings keys are currently supported:
	
	- client_id (String)
	- client_secret (String), usually only needed for code grant
	- authorize_uri (URL-String)
	- token_uri (URL-String), if omitted the authorize_uri will be used to obtain tokens
	- redirect_uris (Array of URL-Strings)
	- scope (String)
	
	- client_name (String)
	- registration_uri (URL-String)
	- logo_uri (URL-String)
	
	- keychain (Bool, true by default, applies to using the system keychain)
	- keychain_access_mode (String, value for keychain kSecAttrAccessible attribute, kSecAttrAccessibleWhenUnlocked by default)
	- keychain_access_group (String, value for keychain kSecAttrAccessGroup attribute, nil by default)
	- keychain_account_for_client_credentials(String, "clientCredentials" by default)
	- keychain_account_for_tokens(String, "currentTokens" by default)
	- secret_in_body (Bool, false by default, forces the flow to use the request body for the client secret)
	- parameters ([String: String], custom request parameters to be added during authorization)
	- token_assume_unexpired (Bool, true by default, whether to use access tokens that do not come with an "expires_in" parameter)
	
	- verbose (Bool, false by default, applies to client logging)
	*/
	override public init(settings: OAuth2JSON) {
		clientConfig = OAuth2ClientConfig(settings: settings)
		
		// auth configuration options
		if let ttl = settings["title"] as? String {
			authConfig.ui.title = ttl
		}
		super.init(settings: settings)
	}
	
	
	// MARK: - Keychain Integration
	
	/** Overrides base implementation to return the authorize URL. */
	override open func keychainServiceName() -> String {
		return authURL.description
	}
	
	override func updateFromKeychainItems(_ items: [String: Any]) {
		for message in clientConfig.updateFromStorableItems(items) {
			logger?.debug("OAuth2", msg: message)
		}
		clientConfig.secretInBody = (clientConfig.endpointAuthMethod == OAuth2EndpointAuthMethod.clientSecretPost)
	}
	
	override open func storableCredentialItems() -> [String: Any]? {
		return clientConfig.storableCredentialItems()
	}
	
	override open func storableTokenItems() -> [String: Any]? {
		return clientConfig.storableTokenItems()
	}
	
	override open func forgetClient() {
		super.forgetClient()
		clientConfig.forgetCredentials()
	}
	
	override open func forgetTokens() {
		super.forgetTokens()
		clientConfig.forgetTokens()
	}
	
	
	// MARK: - Request Signing
	
	/**
	Return an OAuth2Request, a NSMutableURLRequest subclass, that has already been signed and can be used against your OAuth2 endpoint.
	
	This method by default ignores locally cached data and specifies a timeout interval of 20 seconds. This should be ideal for small JSON
	data requests, but you probably don't want to disable cache for binary data like avatars.
	
	- parameter forURL: The URL to create a request for
	- parameter cachePolicy: The cache policy to use, defaults to `NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData`
	- returns: OAuth2Request for the given URL
	*/
	open func request(forURL url: URL, cachePolicy: NSURLRequest.CachePolicy = .reloadIgnoringLocalCacheData) -> URLRequest {
		var req = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: 20)
		try? req.sign(with: self)
		return req
	}
	
	
	// MARK: - Callbacks
	
	/**
	Subclasses override this method to extract information from the supplied redirect URL.
	
	- parameter redirect: The redirect URL returned by the server that you want to handle
	*/
	open func handleRedirectURL(_ redirect: URL) throws {
		throw OAuth2Error.generic("Abstract class use")
	}
	
	/**
	Internally used on success, calls the callbacks on the main thread.
	
	This method is only made public in case you want to create a subclass and call `didAuthorize(parameters:)` at an override point. If you
	call this method yourself on your OAuth2 instance you might screw things up badly.
	
	- parameter withParameters: The parameters received during authorization
	*/
	public final func didAuthorize(withParameters parameters: OAuth2JSON) {
		if useKeychain {
			storeTokensToKeychain()
		}
		callOnMainThread() {
			self.didAuthorizeOrFail?(parameters, nil)
			self.didAuthorizeOrFail = nil
			self.internalAfterAuthorizeOrFail?(false, nil)
			self.afterAuthorizeOrFail?(parameters, nil)
		}
	}
	
	/**
	Internally used on error, calls the callbacks on the main thread with the appropriate error message.
	
	This method is only made public in case you want to create a subclass and need to call `didFail(error:)` at an override point. If you
	call this method yourself on your OAuth2 instance you might screw things up royally.
	
	- parameter error: The error that led to authorization failure; will use `.requestCancelled` on the callbacks if nil is passed
	*/
	public final func didFail(with error: OAuth2Error?) {
		var finalError = error
		if let error = finalError {
			logger?.debug("OAuth2", msg: "\(error)")
		}
		else {
			finalError = OAuth2Error.requestCancelled
		}
		callOnMainThread() {
			self.didAuthorizeOrFail?(nil, finalError)
			self.didAuthorizeOrFail = nil
			self.internalAfterAuthorizeOrFail?(true, finalError)
			self.afterAuthorizeOrFail?(nil, finalError)
		}
	}
	
	/**
	Allows to abort authorization currently in progress.
	*/
	open func abortAuthorization() {
		if !abortTask() {
			logger?.debug("OAuth2", msg: "Aborting authorization")
			didFail(with: nil)
		}
	}
	
	
	// MARK: - Response Parsing
	
	/**
	Handles access token error response.
	
	- parameter params: The URL parameters returned from the server
	- parameter fallback: The message string to use in case no error description is found in the parameters
	- returns: An OAuth2Error
	*/
	open func assureNoErrorInResponse(_ params: OAuth2JSON, fallback: String? = nil) throws {
		
		// "error_description" is optional, we prefer it if it's present
		if let err_msg = params["error_description"] as? String {
			throw OAuth2Error.responseError(err_msg)
		}
		
		// the "error" response is required for error responses, so it should be present
		if let err_code = params["error"] as? String {
			throw OAuth2Error.fromResponseError(err_code, fallback: fallback)
		}
	}
	
	/**
	Parse response data returned while exchanging the code for a token.
	
	This method expects token data to be JSON, decodes JSON and fills the receiver's properties accordingly. If the response contains an
	"error" key, will parse the error and throw it.
	
	- parameter data: NSData returned from the call
	- returns:        An OAuth2JSON instance with token data; may contain additional information
	*/
	open func parseAccessTokenResponse(data: Data) throws -> OAuth2JSON {
		let dict = try parseJSON(data)
		return try parseAccessTokenResponse(params: dict)
	}
	
	/**
	Parse response data returned while exchanging the code for a token.
	
	This method extracts token data and fills the receiver's properties accordingly. If the response contains an "error" key, will parse the
	error and throw it. The method is final to ensure correct order of error parsing and not parsing the response if an error happens. This
	is not possible in overrides. Instead, override the various `assureXy(dict:)` methods, especially `assureAccessTokenParamsAreValid()`.
	
	- parameter params: Dictionary data parsed from the response
	- returns: An OAuth2JSON instance with token data; may contain additional information
	*/
	public final func parseAccessTokenResponse(params: OAuth2JSON) throws -> OAuth2JSON {
		try assureNoErrorInResponse(params)
		try assureCorrectBearerType(params)
		try assureAccessTokenParamsAreValid(params)
		
		clientConfig.updateFromResponse(normalizeAccessTokenResponseKeys(params))
		return params
	}
	
	/**
	This method does nothing, but allows subclasses to fix parameter names before passing the access token response to `OAuth2ClientConfig`s
	`updateFromResponse()`.
	
	- parameter dict: The dictionary that was returned from an access token response
	- returns: The dictionary with fixed key names
	*/
	open func normalizeAccessTokenResponseKeys(_ dict: OAuth2JSON) -> OAuth2JSON {
		return dict
	}
	
	/**
	Parse response data returned while using a refresh token.
	
	This method extracts token data, expected to be JSON, and fills the receiver's properties accordingly. If the response contains an
	"error" key, will parse the error and throw it.
	
	- parameter data: NSData returned from the call
	- returns: An OAuth2JSON instance with token data; may contain additional information
	*/
	open func parseRefreshTokenResponseData(_ data: Data) throws -> OAuth2JSON {
		let dict = try parseJSON(data)
		return try parseRefreshTokenResponse(dict)
	}
	
	/**
	Parse response data returned while using a refresh token.
	
	This method extracts token data and fills the receiver's properties accordingly. If the response contains an "error" key, will parse the
	error and throw it. The method is final to ensure correct order of error parsing and not parsing the response if an error happens. This
	is not possible in overrides. Instead, override the various `assureXy(dict:)` methods, especially `assureRefreshTokenParamsAreValid()`.
	
	- parameter json: Dictionary data parsed from the response
	- returns: An OAuth2JSON instance with token data; may contain additional information
	*/
	final func parseRefreshTokenResponse(_ dict: OAuth2JSON) throws -> OAuth2JSON {
		try assureNoErrorInResponse(dict)
		try assureCorrectBearerType(dict)
		try assureRefreshTokenParamsAreValid(dict)
		
		clientConfig.updateFromResponse(normalizeRefreshTokenResponseKeys(dict))
		return dict
	}
	
	/**
	This method does nothing, but allows subclasses to fix parameter names before passing the refresh token response to
	`OAuth2ClientConfig`s `updateFromResponse()`.
	
	- parameter dict: The dictionary that was returned from a refresh token response
	- returns: The dictionary with fixed key names
	*/
	open func normalizeRefreshTokenResponseKeys(_ dict: OAuth2JSON) -> OAuth2JSON {
		return dict
	}
	
	/**
	This method checks `state`, throws `OAuth2Error.missingState` or `OAuth2Error.invalidState`. Resets state if it matches.
	*/
	public final func assureMatchesState(_ params: OAuth2JSON) throws {
		guard let state = params["state"] as? String, !state.isEmpty else {
			throw OAuth2Error.missingState
		}
		logger?.trace("OAuth2", msg: "Checking state, got “\(state)”, expecting “\(context.state)”")
		if !context.matchesState(state) {
			throw OAuth2Error.invalidState
		}
		context.resetState()
	}
	
	/**
	Throws unless "token_type" is "bearer" (case-insensitive).
	*/
	open func assureCorrectBearerType(_ params: OAuth2JSON) throws {
		if let tokType = params["token_type"] as? String {
			if "bearer" == tokType.lowercased() {
				return
			}
			throw OAuth2Error.unsupportedTokenType("Only “bearer” token is supported, but received “\(tokType)”")
		}
		throw OAuth2Error.noTokenType
	}
	
	/**
	Called when parsing the access token response. Does nothing by default, implicit grant flows check state.
	*/
	open func assureAccessTokenParamsAreValid(_ params: OAuth2JSON) throws {
	}
	
	/**
	Called when parsing the refresh token response. Does nothing by default.
	*/
	open func assureRefreshTokenParamsAreValid(_ params: OAuth2JSON) throws {
	}
}


/**
Class, internally used, to store current authorization context, such as state and redirect-url.
*/
open class OAuth2ContextStore {
	
	/// Currently used redirect_url.
	open var redirectURL: String?
	
	/// The current state.
	internal var _state = ""
	
	/**
	The state sent to the server when requesting a token.
	
	We internally generate a UUID and use the first 8 chars if `_state` is empty.
	*/
	open var state: String {
		if _state.isEmpty {
			_state = UUID().uuidString
			_state = _state[_state.startIndex..<_state.index(_state.startIndex, offsetBy: 8)]		// only use the first 8 chars, should be enough
		}
		return _state
	}
	
	/**
	Checks that given state matches the internal state.
	
	- parameter state: The state to check (may be nil)
	- returns: true if state matches, false otherwise or if given state is nil.
	*/
	func matchesState(_ state: String?) -> Bool {
		if let st = state {
			return st == _state
		}
		return false
	}
	
	/**
	Resets current state so it gets regenerated next time it's needed.
	*/
	func resetState() {
		_state = ""
	}
}

