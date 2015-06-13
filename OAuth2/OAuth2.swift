//
//  OAuth2.swift
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

/// The error domain used for errors during the OAuth2 flow.
let OAuth2ErrorDomain = "OAuth2ErrorDomain"

/// We store the current tokens under this keychain key name.
let OAuth2KeychainTokenKey = "currentTokens"


/**
    Errors supplanting NSError codes if no HTTP status code is available (hence >= 600).
 */
public enum OAuth2Error: Int {
	case Generic = 600
	case Unsupported
	case NetworkError
	case PrerequisiteFailed
	case InvalidState
	case AuthorizationError
}

/// Typealias to ease working with JSON dictionaries.
public typealias OAuth2JSON = [String: AnyObject]

/**
    Simple struct to hold client-side authorization configuration variables.
 */
public struct OAuth2AuthConfig
{
	/// Whether to use an embedded web view for authorization (true), the OS browser (false, the default) or don't do anything (nil).
	public var authorizeEmbedded: Bool? = false
	
	/// Context information for the authorization flow; e.g. the parent view controller to use on iOS.
	public var authorizeContext: AnyObject? = nil
}


/**
    Base class for specific OAuth2 authentication flow implementations.
 */
public class OAuth2
{
	/// Server-side settings, as set upon initialization.
	final let settings: OAuth2JSON
	
	/// Client-side configurations.
	public var authConfig: OAuth2AuthConfig
	
	/// The client id.
	public final let clientId: String
	
	/// The client secret, usually only needed for code grant.
	public final let clientSecret: String?
	
	/// The URL to authorize against.
	public final let authURL: NSURL
	
	/// The scope currently in use.
	public var scope: String?
	
	/// The redirect URL string currently in use.
	public var redirect: String?
	
	/** The state sent to the server when requesting a token.
		We internally generate a UUID and use the first 8 chars.
	 */
	internal(set) public var state = ""
	
	/// The receiver's access token.
	public var accessToken: String?
	
	/// The access token's expiry date.
	public var accessTokenExpiry: NSDate?
	
	/// Closure called on successful authentication on the main thread.
	public final var onAuthorize: ((parameters: OAuth2JSON) -> Void)?
	
	/// When authorization fails (if error is not nil) or is cancelled, this block is executed on the main thread.
	public final var onFailure: ((error: NSError?) -> Void)?
	
	/**
		Closure called after onAuthorize OR onFailure, on the main thread; useful for cleanup operations.
	
		:param: wasFailure Bool indicating success or failure
		:param: error NSError describing the reason for failure, as supplied to the `onFailure` callback. If it is nil
		        and wasFailure is true, the process was aborted.
	 */
	public final var afterAuthorizeOrFailure: ((wasFailure: Bool, error: NSError?) -> Void)?
	
	/// Same as `afterAuthorizeOrFailure`, but only for internal use and called right BEFORE the public variant.
	final var internalAfterAuthorizeOrFailure: ((wasFailure: Bool, error: NSError?) -> Void)?
	
	/// An optional title that will propagate to views handled by OAuth2, such as OAuth2WebViewController.
	public var viewTitle: String?
	
	/// If set to `true` (the default) will use system keychain to store tokens. Use `"keychain": bool` in settings.
	public var useKeychain = true {
		didSet {
			if useKeychain {
				updateFromKeychain()
			}
		}
	}
	
	/// Set to `true` to log all the things. `false` by default. Use `"verbose": bool` in settings.
	public var verbose = false
	
	
	/**
	    Designated initializer.
	
	    The following settings keys are currently supported:
	
	    - client_id (string)
	    - client_secret (string), usually only needed for code grant
	    - authorize_uri (string)
	    - token_uri (string), only for code grant
	    - redirect_uris (list of strings)
	    - scope (string)
	
	    - keychain (bool, true by default, applies to using the system keychain)
	    - verbose (bool, false by default, applies to client logging)
	    - secret_in_body (bool, false by default, forces code grant flow to use the request body for the client secret)
	
	    NOTE that you **must** supply at least `client_id` and `authorize_uri` upon authorization. If you forget the
	    former a _fatalError_ will be raised, if you forget the latter `http://localhost` will be used.
	 */
	public init(settings: OAuth2JSON) {
		self.settings = settings
		
		if let cid = settings["client_id"] as? String {
			clientId = cid
		}
		else {
			fatalError("Must supply `client_id` upon initialization")
		}
		
		clientSecret = settings["client_secret"] as? String
		
		// authorize URL
		var aURL: NSURL?
		if let auth = settings["authorize_uri"] as? String {
			aURL = NSURL(string: auth)
		}
		authURL = aURL ?? NSURL(string: "http://localhost")!
		
		// scope and state (state should only be manually set for testing purposes!)
		scope = settings["scope"] as? String
		if let st = settings["state_for_testing"] as? String {
			state = st
		}
		
		// client settings
		if let keychain = settings["keychain"] as? Bool {
			useKeychain = keychain
		}
		if let verb = settings["verbose"] as? Bool {
			verbose = verb
		}
		authConfig = OAuth2AuthConfig()
		
		// init from keychain
		if useKeychain {
			updateFromKeychain()
		}
		
		logIfVerbose("Initialized with client id \(clientId)")
	}
	
	
	// MARK: - Keychain Integration
	
	/** Queries the keychain for tokens stored for the receiver's authorize URL, and updates the token properties accordingly. */
	private func updateFromKeychain() {
		logIfVerbose("Looking for tokens in keychain")
		
		let keychain = Keychain(serviceName: authURL.description)
		let key = ArchiveKey(keyName: OAuth2KeychainTokenKey)
		if let items = keychain.get(key).item?.object as? [String: NSCoding] {
			updateFromKeychainItems(items)
		}
	}
	
	/** Updates the token properties according to the items found in the passed dictionary. */
	func updateFromKeychainItems(items: [String: NSCoding]) {
		if let token = items["accessToken"] as? String where !token.isEmpty {
			if let date = items["accessTokenDate"] as? NSDate {
				if date == date.laterDate(NSDate()) {
					logIfVerbose("Found access token, valid until \(date)")
					accessTokenExpiry = date
					accessToken = token
				}
				else {
					logIfVerbose("Found access token but it seems to have expired")
				}
			}
			else {
				logIfVerbose("Found access token but no expiration date, discarding")
			}
		}
	}
	
	/** Stores our current token(s) in the keychain. */
	private func storeToKeychain() {
		if let items = storableKeychainItems() {
			logIfVerbose("Storing tokens to keychain")
			
			let keychain = Keychain(serviceName: authURL.description)
			let key = ArchiveKey(keyName: OAuth2KeychainTokenKey, object: items)
			if let error = keychain.update(key) {
				NSLog("Failed to store tokens to keychain: \(error.localizedDescription)")
			}
		}
	}
	
	/** Returns a dictionary of our tokens and expiration date, ready to be stored to the keychain. */
	func storableKeychainItems() -> [String: NSCoding]? {
		if let access = accessToken where !access.isEmpty {
			var items: [String: NSCoding] = ["accessToken": access]
			
			if let date = accessTokenExpiry where date == date.laterDate(NSDate()) {
				items["accessTokenDate"] = date
			}
			return items
		}
		return nil
	}
	
	/** Unsets the tokens and deletes them from the keychain. */
	public func forgetTokens() {
		logIfVerbose("Deleting tokens and removing them from keychain")
		let keychain = Keychain(serviceName: authURL.description)
		let key = ArchiveKey(keyName: OAuth2KeychainTokenKey)
		if let error = keychain.remove(key) {
			NSLog("Failed to delete tokens from keychain: \(error.localizedDescription)")
		}
		
		accessToken = nil
		accessTokenExpiry = nil
	}
	
	
	// MARK: - Authorization
	
	/**
	    Use this method, together with `authConfig`, to obtain an access token.
 
	    This method will first check if the client already has an unexpired access token (possibly from the keychain), if not and it's able
	    to use a refresh token (code grant flow) it will try to use the refresh token, then if this fails it will show the authorize screen
	    IF you have `authConfig` set up sufficiently. If `authConfig` is not set up sufficiently this method will end up calling the
	    `onFailure` callback.
	 */
	public func authorize(params: [String: String]? = nil, autoDismiss: Bool = true) {
		tryToObtainAccessToken() { success in
			if success {
				self.didAuthorize(OAuth2JSON())
			}
			else {
				if let embed = self.authConfig.authorizeEmbedded {
					if embed {
						if !self.authorizeEmbeddedWith(self.authConfig.authorizeContext, params: params, autoDismiss: autoDismiss) {
							self.didFail(genOAuth2Error("Client settings insufficient to show an authorization screen (no or invalid context given)", .PrerequisiteFailed))
						}
					}
					else {
						if !self.openAuthorizeURLInBrowser(params: params) {
							fatalError("Cannot open authorize URL")
						}
					}
				}
				else {
					self.didFail(genOAuth2Error("Client settings insufficient to show an authorization screen (`authorizeEmbedded` is not set)", .PrerequisiteFailed))
				}
			}
		}
	}
	
	/**
	    If the instance has an accessToken, checks if its expiry time has not yet passed. If we don't have an expiry
	    date we assume the token is still valid.
	 */
	public func hasUnexpiredAccessToken() -> Bool {
		if let access = accessToken where !access.isEmpty {
			if let expiry = accessTokenExpiry {
				return expiry == expiry.laterDate(NSDate())
			}
			return true
		}
		return false
	}
	
	/**
	    Indicates, in the callback, whether the client has been able to obtain an access token that is likely to still
	    work (but there is no guarantee).
	    
	    This method calls the callback immediately with the result of `hasUnexpiredAccessToken()`. Subclasses such as
	    the code grant however might perform a refresh token call and only call the callback after this succeeds or
	    fails.
	    
	    :param: callback The callback to call once the client knows whether it has an access token or not
	 */
	func tryToObtainAccessToken(callback: ((success: Bool) -> Void)) {
		callback(success: hasUnexpiredAccessToken())
	}
	
	/**
	    Constructs an authorize URL with the given parameters.
	
	    It is possible to use the `params` dictionary to override internally generated URL parameters, use it wisely.
	    Subclasses generally provide shortcut methods to receive an appropriate authorize (or token) URL.
	
	    :param: base         The base URL (with path, if needed) to build the URL upon
	    :param: redirect     The redirect URI string to supply. If it is nil, the first value of the settings'
	                         `redirect_uris` entries is used. Must be present in the end!
	    :param: scope        The scope to request
	    :param: responseType The response type to request; subclasses know which one to supply
	    :param: params       Any additional parameters as dictionary with string keys and values that will be added to
	                         the query part
	    :returns: NSURL to be used to start the OAuth dance
	 */
	public func authorizeURLWithBase(base: NSURL, redirect: String?, scope: String?, responseType: String?, params: [String: String]?) -> NSURL {
		
		// verify that we have all parts
		if clientId.isEmpty {
			NSException(name: "OAuth2IncompleteSetup", reason: "I do not yet have a client id, cannot construct an authorize URL", userInfo: nil).raise()
		}
		
		if nil != redirect {
			self.redirect = redirect!
		}
		else if nil == self.redirect {
			if let redirs = settings["redirect_uris"] as? [String] {
				self.redirect = redirs.first
			}
		}
		if nil == self.redirect {
			NSException(name: "OAuth2IncompleteSetup", reason: "I need a redirect URI, cannot construct an authorize URL", userInfo: nil).raise()
		}
		
		if state.isEmpty {
			state = NSUUID().UUIDString
			state = state[state.startIndex..<advance(state.startIndex, 8)]		// only use the first 8 chars, should be enough
		}
		
		// compose the URL query component
		let comp = NSURLComponents(URL: base, resolvingAgainstBaseURL: true)
		assert(nil != comp && "https" == comp!.scheme, "You MUST use HTTPS")
		
		var urlParams = params ?? [String: String]()
		urlParams["client_id"] = clientId
		urlParams["redirect_uri"] = self.redirect!
		urlParams["state"] = state
		
		if nil != scope {
			self.scope = scope!
		}
		if nil != self.scope {
			urlParams["scope"] = self.scope!
		}
		if nil != responseType {
			urlParams["response_type"] = responseType!
		}
		
		comp!.percentEncodedQuery = OAuth2.queryStringFor(urlParams)
		
		let final = comp!.URL
		if nil == final {
			NSException(name: "OAuth2InvalidURL", reason: "Failed to create authorize URL", userInfo: urlParams).raise()
		}
		
		logIfVerbose("Authorizing against \(final!.description)")
		return final!;
	}
	
	/**
	    Most convenient method if you want the authorize URL to be created as defined in your settings dictionary.
	
	    :param: params Optional, additional URL params to supply to the request
	    :returns: NSURL to be used to start the OAuth dance
	 */
	public func authorizeURL(params: [String: String]? = nil) -> NSURL {
		return authorizeURLWithRedirect(nil, scope: nil, params: params)
	}
	
	/**
	    Convenience method to be overridden by and used from subclasses.
	
	    :param: redirect  The redirect URI string to supply. If it is nil, the first value of the settings'
	                      `redirect_uris` entries is used. Must be present in the end!
	    :param: scope     The scope to request
	    :param: params    Any additional parameters as dictionary with string keys and values that will be added to the
	                      query part
	    :returns: NSURL to be used to start the OAuth dance
	 */
	public func authorizeURLWithRedirect(redirect: String?, scope: String?, params: [String: String]?) -> NSURL {
		NSException(name: "OAuth2AbstractClassUse", reason: "Abstract class use", userInfo: nil).raise()
		return NSURL()
	}
	
	/**
	    Subclasses override this method to extract information from the supplied redirect URL.
	 */
	public func handleRedirectURL(redirect: NSURL) {
		NSException(name: "OAuth2AbstractClassUse", reason: "Abstract class use", userInfo: nil).raise()
	}
	
	/**
	    Internally used on success. Calls the `onAuthorize` and `afterAuthorizeOrFailure` callbacks on the main thread.
	 */
	func didAuthorize(parameters: OAuth2JSON) {
		if useKeychain {
			storeToKeychain()
		}
		
		callOnMainThread() {
			self.onAuthorize?(parameters: parameters)
			self.internalAfterAuthorizeOrFailure?(wasFailure: false, error: nil)
			self.afterAuthorizeOrFailure?(wasFailure: false, error: nil)
		}
	}
	
	/**
	    Internally used on error. Calls the `onFailure` and `afterAuthorizeOrFailure` callbacks on the main thread.
	 */
	func didFail(error: NSError?) {
		if let err = error {
			logIfVerbose("\(err.localizedDescription)")
		}
		callOnMainThread() {
			self.onFailure?(error: error)
			self.internalAfterAuthorizeOrFailure?(wasFailure: true, error: error)
			self.afterAuthorizeOrFailure?(wasFailure: true, error: error)
		}
	}
	
	
	// MARK: - Requests
	
	var session: NSURLSession?
	
	public var sessionDelegate: NSURLSessionDelegate?
	
	/**
	    Return an OAuth2Request, a NSMutableURLRequest subclass, that has already been signed and can be used against
	    your OAuth2 endpoint.
	
	    This method prefers cached data and specifies a timeout interval of 20 seconds.
	 */
	public func request(forURL url: NSURL) -> OAuth2Request {
		return OAuth2Request(URL: url, oauth: self, cachePolicy: .ReturnCacheDataElseLoad, timeoutInterval: 20)
	}
	
	/**
	    Perform the supplied request and call the callback with the response JSON dict or an error.
	
	    This implementation uses the shared `NSURLSession` and executes a data task. If the server responds with an error, this will be
	    converted into an NSError instance with information supplied in the response JSON (if availale), using `errorForErrorResponse`.
	
	    :param: request The request to execute
	    :param: callback The callback to call when the request completes/fails; data and error are mutually exclusive
	 */
	public func performRequest(request: NSURLRequest, callback: ((data: NSData?, status: Int?, error: NSError?) -> Void)) {
		let task = URLSession().dataTaskWithRequest(request) { sessData, sessResponse, error in
			if let error = error {
				callback(data: nil, status: nil, error: error)
			}
			else if let data = sessData, let http = sessResponse as? NSHTTPURLResponse {
				callback(data: data, status: http.statusCode, error: nil)
			}
			else {
				let error = genOAuth2Error("Unknown response \(sessResponse) with data “\(NSString(data: sessData, encoding: NSUTF8StringEncoding))”", .NetworkError)
				callback(data: nil, status: nil, error: error)
			}
		}
		task.resume()
	}
	
	func URLSession() -> NSURLSession {
		if nil == session {
			if let delegate = sessionDelegate {
				let config = NSURLSessionConfiguration.defaultSessionConfiguration()
				session = NSURLSession(configuration: config, delegate: delegate, delegateQueue: nil)
			}
			else {
				session = NSURLSession.sharedSession()
			}
		}
		return session!
	}
	
	
	// MARK: - Utilities
	
	/**
	    Parse the NSData object returned while exchanging the code for a token in `exchangeCodeForToken`, usually JSON data.
	
	    This method extracts token data and fills the receiver's properties accordingly.
	
	    :returns: An OAuth2JSON instance with token data; may contain additional information
	*/
	func parseAccessTokenResponse(data: NSData, error: NSErrorPointer) -> OAuth2JSON? {
		if let json = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: error) as? OAuth2JSON {
			if let access = json["access_token"] as? String {
				accessToken = access
			}
			accessTokenExpiry = nil
			if let expires = json["expires_in"] as? NSTimeInterval {
				accessTokenExpiry = NSDate(timeIntervalSinceNow: expires)
			}
			else {
				self.logIfVerbose("Did not get access token expiration interval")
			}
			return json
		}
		if let str = NSString(data: data, encoding: NSUTF8StringEncoding) {
			logIfVerbose("Unparsable JSON was: \(str)")
		}
		return nil
	}
	
	/**
	    Create a query string from a dictionary of string: string pairs.
	
	    This method does **form encode** the value part. If you're using NSURLComponents you want to assign the return
	    value to `percentEncodedQuery`, NOT `query` as this would double-encode the value.
	 */
	public final class func queryStringFor(params: [String: String]) -> String {
		var arr: [String] = []
		for (key, val) in params {
			arr.append("\(key)=\(val.wwwFormURLEncodedString)")
		}
		return "&".join(arr)
	}
	
	/**
	    Parse a query string into a dictionary of String: String pairs.
	
	    If you're retrieving a query or fragment from NSURLComponents, use the `percentEncoded##` variant as the others
	    automatically perform percent decoding, potentially messing with your query string.
	 */
	public final class func paramsFromQuery(query: String) -> [String: String] {
		let parts = split(query, maxSplit: .max, allowEmptySlices: false) { $0 == "&" }
		var params = [String: String](minimumCapacity: parts.count)
		for part in parts {
			let subparts = split(part, maxSplit: .max, allowEmptySlices: false) { $0 == "=" }
			if 2 == subparts.count {
				params[subparts[0]] = subparts[1].wwwFormURLDecodedString
			}
		}
		
		return params
	}
	
	/**
	    Handles access token error response.
	
	    :param: params The URL parameters passed into the redirect URL upon error
	    :param: fallback The message string to use in case no error description is found in the parameters
	    :returns: An NSError instance with the "best" localized error key and all parameters in the userInfo dictionary;
	              domain "OAuth2ErrorDomain", code 600
	 */
	func errorForErrorResponse(params: OAuth2JSON, fallback: String? = nil) -> NSError {
		var message = ""
		
		// "error_description" is optional, we prefer it if it's present
		if let err_msg = params["error_description"] as? String {
			message = err_msg
		}
		
		// the "error" response is required for error responses
		if message.isEmpty {
			if let err_code = params["error"] as? String {
				switch err_code {
				case "invalid_request":
					message = "The request is missing a required parameter, includes an invalid parameter value, includes a parameter more than once, or is otherwise malformed."
				case "unauthorized_client":
					message = "The client is not authorized to request an access token using this method."
				case "access_denied":
					message = "The resource owner or authorization server denied the request."
				case "unsupported_response_type":
					message = "The authorization server does not support obtaining an access token using this method."
				case "invalid_scope":
					message = "The requested scope is invalid, unknown, or malformed."
				case "server_error":
					message = "The authorization server encountered an unexpected condition that prevented it from fulfilling the request."
				case "temporarily_unavailable":
					message = "The authorization server is currently unable to handle the request due to a temporary overloading or maintenance of the server."
				default:
					message = "Authorization error: \(err_code)."
				}
			}
		}
		
		// still unknown, oh well
		if message.isEmpty {
			message = fallback ?? "Unknown error."
		}
		
		return genOAuth2Error(message, .AuthorizationError)
	}
	
	/**
	    Debug logging, will only log if `verbose` is YES.
	 */
	func logIfVerbose(log: String) {
		if verbose {
			println("OAuth2: \(log)")
		}
	}
}


/**
    Helper function to ensure that the callback is executed on the main thread.
 */
func callOnMainThread(callback: (Void -> Void)) {
	if NSThread.isMainThread() {
		callback()
	}
	else {
		dispatch_sync(dispatch_get_main_queue(), callback)
	}
}

/**
    Convenience function to create an error in the "OAuth2ErrorDomain" error domain.
 */
public func genOAuth2Error(message: String, _ code: OAuth2Error = .Generic) -> NSError {
	return NSError(domain: OAuth2ErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
}

