//
//  OAuth2Base.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/2/15.
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


/// Typealias to ease working with JSON dictionaries.
public typealias OAuth2JSON = [String: AnyObject]

/// Typealias to work with dictionaries full of strings.
public typealias OAuth2StringDict = [String: String]


/**
Abstract base class for OAuth2 authorization as well as client registration classes.
*/
public class OAuth2Base {
	
	/// Server-side settings, as set upon initialization.
	final let settings: OAuth2JSON
	
	/// Set to `true` to log all the things. `false` by default. Use `"verbose": bool` in settings or assign `logger` yourself.
	public var verbose = false {
		didSet {
			logger = verbose ? OAuth2DebugLogger() : nil
		}
	}
	
	/// The logger being used. Auto-assigned to a debug logger if you set `verbose` to true or false.
	public var logger: OAuth2Logger?
	
	/// If set to `true` (the default) will use system keychain to store tokens. Use `"keychain": bool` in settings.
	public var useKeychain = true {
		didSet {
			if useKeychain {
				updateFromKeychain()
			}
		}
	}
	
	/// Defaults to `kSecAttrAccessibleWhenUnlocked`
	public internal(set) var keychainAccessMode = kSecAttrAccessibleWhenUnlocked
	
	
	/**
	Base initializer.
	
	Looks at the `keychain`, `keychain_access_mode` and `verbose` keys in the _settings_ dict. Everything else is handled by subclasses.
	*/
	public init(settings: OAuth2JSON) {
		self.settings = settings
		
		// client settings
		if let keychain = settings["keychain"] as? Bool {
			useKeychain = keychain
		}
		if let accessMode = settings["keychain_access_mode"] as? String {
			keychainAccessMode = accessMode
		}
		if let verb = settings["verbose"] as? Bool {
			verbose = verb
			if verbose {
				logger = OAuth2DebugLogger()
			}
		}
		
		// init from keychain
		if useKeychain {
			updateFromKeychain()
		}
		logger?.debug("OAuth2", msg: "Initialization finished")
	}
	
	
	// MARK: - Keychain Integration
	
	/** The service key under which to store keychain items. Returns "http://localhost", subclasses override to return the authorize URL. */
	public func keychainServiceName() -> String {
		return "http://localhost"
	}
	
	/** Queries the keychain for tokens stored for the receiver's authorize URL, and updates the token properties accordingly. */
	private func updateFromKeychain() {
		logger?.debug("OAuth2", msg: "Looking for items in keychain")
		
		do {
			var creds = OAuth2KeychainAccount(oauth2: self, account: OAuth2KeychainTokenKey)
			let creds_data = try creds.fetchedFromKeychain()
			updateFromKeychainItems(creds_data)
		}
		catch {
			logger?.warn("OAuth2", msg: "Failed to load client credentials from keychain: \(error)")
		}
		
		do {
			var toks = OAuth2KeychainAccount(oauth2: self, account: OAuth2KeychainCredentialsKey)
			let toks_data = try toks.fetchedFromKeychain()
			updateFromKeychainItems(toks_data)
		}
		catch {
			logger?.warn("OAuth2", msg: "Failed to load tokens from keychain: \(error)")
		}
	}
	
	/** Updates instance properties according to the items found in the given dictionary, which was found in the keychain. */
	func updateFromKeychainItems(items: [String: NSCoding]) {
	}
	
	/** Items that should be stored when storing client credentials. */
	func storableCredentialItems() -> [String: NSCoding]? {
		return nil
	}
	
	/** Stores our client credentials in the keychain. */
	internal func storeClientToKeychain() {
		if let items = storableCredentialItems() {
			logger?.debug("OAuth2", msg: "Storing client credentials to keychain")
			let keychain = OAuth2KeychainAccount(oauth2: self, account: OAuth2KeychainTokenKey, data: items)
			do {
				try keychain.saveInKeychain()
			}
			catch {
				logger?.warn("OAuth2", msg: "Failed to store client credentials to keychain: \(error)")
			}
		}
	}
	
	/** Items that should be stored when tokens are stored to the keychain. */
	func storableTokenItems() -> [String: NSCoding]? {
		return nil
	}
	
	/** Stores our current token(s) in the keychain. */
	internal func storeTokensToKeychain() {
		if let items = storableTokenItems() {
			logger?.debug("OAuth2", msg: "Storing tokens to keychain")
			let keychain = OAuth2KeychainAccount(oauth2: self, account: OAuth2KeychainCredentialsKey, data: items)
			do {
				try keychain.saveInKeychain()
			}
			catch {
				logger?.warn("OAuth2", msg: "Failed to store tokens to keychain: \(error)")
			}
		}
	}
	
	/** Unsets the client credentials and deletes them from the keychain. */
	public func forgetClient() {
		logger?.debug("OAuth2", msg: "Forgetting client credentials and removing them from keychain")
		let keychain = OAuth2KeychainAccount(oauth2: self, account: OAuth2KeychainTokenKey)
		do {
			try keychain.removeFromKeychain()
		}
		catch {
			logger?.warn("OAuth2", msg: "Failed to delete credentials from keychain: \(error)")
		}
	}
	
	/** Unsets the tokens and deletes them from the keychain. */
	public func forgetTokens() {
		logger?.debug("OAuth2", msg: "Forgetting tokens and removing them from keychain")

		let keychain = OAuth2KeychainAccount(oauth2: self, account: OAuth2KeychainCredentialsKey)
		do {
			try keychain.removeFromKeychain()
		}
		catch {
			logger?.warn("OAuth2", msg: "Failed to delete tokens from keychain: \(error)")
		}
	}
	
	
	// MARK: - Requests
	
	/// The instance's current session, creating one by the book if necessary. Defaults to using an ephemeral session, you can use
	/// `sessionConfiguration` and/or `sessionDelegate` to affect how the session is configured.
	public var session: NSURLSession {
		if nil == _session {
			let config = sessionConfiguration ?? NSURLSessionConfiguration.ephemeralSessionConfiguration()
			_session = NSURLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
		}
		return _session!
	}
	
	/// The backing store for `session`.
	private var _session: NSURLSession?
	
	/// The configuration to use when creating `session`. Uses an `+ephemeralSessionConfiguration()` if nil.
	public var sessionConfiguration: NSURLSessionConfiguration? {
		didSet {
			_session = nil
		}
	}
	
	/// URL session delegate that should be used for the `NSURLSession` the instance uses for requests.
	public var sessionDelegate: NSURLSessionDelegate? {
		didSet {
			_session = nil
		}
	}
	
	/**
	Perform the supplied request and call the callback with the response JSON dict or an error. This method is intended for authorization
	calls, not for data calls outside of the OAuth2 dance.
	
	This implementation uses the shared `NSURLSession` and executes a data task. If the server responds with an error, this will be
	converted into an error according to information supplied in the response JSON (if availale).
	
	- parameter request: The request to execute
	- parameter callback: The callback to call when the request completes/fails; data and error are mutually exclusive
	*/
	public func performRequest(request: NSURLRequest, callback: ((data: NSData?, status: Int?, error: ErrorType?) -> Void)) {
		self.logger?.trace("OAuth2", msg: "REQUEST\n\(request.debugDescription)\n---")
		let task = session.dataTaskWithRequest(request) { sessData, sessResponse, error in
			self.abortableTask = nil
			self.logger?.trace("OAuth2", msg: "RESPONSE\n\(sessResponse?.debugDescription ?? "no response")\n\n\(NSString(data: sessData ?? NSData(), encoding: NSUTF8StringEncoding) ?? "no data")\n---")
			if let error = error {
				if NSURLErrorDomain == error.domain && -999 == error.code {		// request was cancelled
					callback(data: nil, status: nil, error: OAuth2Error.RequestCancelled)
				}
				else {
					callback(data: nil, status: nil, error: error)
				}
			}
			else if let data = sessData, let http = sessResponse as? NSHTTPURLResponse {
				callback(data: data, status: http.statusCode, error: nil)
			}
			else {
				let error = OAuth2Error.Generic("Unknown response \(sessResponse) with data “\(NSString(data: sessData!, encoding: NSUTF8StringEncoding))”")
				callback(data: nil, status: nil, error: error)
			}
		}
		abortableTask = task
		task.resume()
	}
	
	/// Currently running abortable session task.
	private var abortableTask: NSURLSessionTask?
	
	/**
	Can be called to immediately abort the currently running authorization request, if it was started by `performRequest()`.
	
	- returns: A bool indicating whether a task was aborted or not
	*/
	func abortTask() -> Bool {
		guard let task = abortableTask else {
			return false
		}
		logger?.debug("OAuth2", msg: "Aborting request")
		task.cancel()
		return true
	}
	
	
	// MARK: - Response Verification
	
	/**
	Handles access token error response.
	
	- parameter params: The URL parameters returned from the server
	- parameter fallback: The message string to use in case no error description is found in the parameters
	- returns: An OAuth2Error
	*/
	public func assureNoErrorInResponse(params: OAuth2JSON, fallback: String? = nil) throws {
		
		// "error_description" is optional, we prefer it if it's present
		if let err_msg = params["error_description"] as? String {
			throw OAuth2Error.ResponseError(err_msg)
		}
		
		// the "error" response is required for error responses, so it should be present
		if let err_code = params["error"] as? String {
			throw OAuth2Error.fromResponseError(err_code, fallback: fallback)
		}
	}
	
	
	// MARK: - Utilities
	
	/**
	Parse string-only JSON from NSData.
	
	- parameter data: NSData returned from the call, assumed to be JSON with string-values only.
	- returns: An OAuth2JSON instance
	*/
	func parseJSON(data: NSData) throws -> OAuth2JSON {
		if let json = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? OAuth2JSON {
			return json
		}
		if let str = NSString(data: data, encoding: NSUTF8StringEncoding) {
			logger?.warn("OAuth2", msg: "Unparsable JSON was: \(str)")
		}
		throw OAuth2Error.JSONParserError
	}
	
	/**
	Parse a query string into a dictionary of String: String pairs.
	
	If you're retrieving a query or fragment from NSURLComponents, use the `percentEncoded##` variant as the others
	automatically perform percent decoding, potentially messing with your query string.
	
	- parameter query: The query string you want to have parsed
	- returns: A dictionary full of strings with the key-value pairs found in the query
	*/
	public final class func paramsFromQuery(query: String) -> OAuth2StringDict {
		let parts = query.characters.split() { $0 == "&" }.map() { String($0) }
		var params = OAuth2StringDict(minimumCapacity: parts.count)
		for part in parts {
			let subparts = part.characters.split() { $0 == "=" }.map() { String($0) }
			if 2 == subparts.count {
				params[subparts[0]] = subparts[1].wwwFormURLDecodedString
			}
		}
		return params
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

