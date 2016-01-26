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
#if IMPORT_SWIFT_KEYCHAIN
import SwiftKeychain
#endif


/// Typealias to ease working with JSON dictionaries.
public typealias OAuth2JSON = [String: AnyObject]

/// Typealias to work with dictionaries full of strings.
public typealias OAuth2StringDict = [String: String]


/**
    Abstract base class for OAuth2 authorization as well as client registration classes.
 */
public class OAuth2Base
{
	/// Server-side settings, as set upon initialization.
	final let settings: OAuth2JSON
	
	/// Set to `true` to log all the things. `false` by default. Use `"verbose": bool` in settings.
	public var verbose = false
	
	/// If set to `true` (the default) will use system keychain to store tokens. Use `"keychain": bool` in settings.
	public var useKeychain = true {
		didSet {
			if useKeychain {
				updateFromKeychain()
			}
		}
	}
	
	/** The service key under which to store keychain items. Returns nil, to be overridden by subclasses. */
	public func keychainServiceName() -> String {
		return "http://localhost"
	}
	
	public func keychainKeyName() -> String {
		return "currentTokens"
	}
	
	
	public init(settings: OAuth2JSON) {
		self.settings = settings
		
		// client settings
		if let keychain = settings["keychain"] as? Bool {
			useKeychain = keychain
		}
		if let verb = settings["verbose"] as? Bool {
			verbose = verb
		}
		
		// init from keychain
		if useKeychain {
			updateFromKeychain()
		}
		
		logIfVerbose("Initialization finished")
	}
	
	
	// MARK: - Keychain Integration
	
	/** Queries the keychain for tokens stored for the receiver's authorize URL, and updates the token properties accordingly. */
	private func updateFromKeychain() {
		logIfVerbose("Looking for items in keychain")
		
		let keychain = Keychain(serviceName: keychainServiceName())
		let key = ArchiveKey(keyName: keychainKeyName())
		if let items = keychain.get(key).item?.object as? [String: NSCoding] {
			updateFromKeychainItems(items)
		}
	}
	
	/** Updates instance properties according to the items found in the passed dictionary found in the keychain. */
	func updateFromKeychainItems(items: [String: NSCoding]) {
	}
	
	/** Stores our current token(s) in the keychain. */
	internal func storeToKeychain() {
		guard let items = storableKeychainItems() else { return }
		logIfVerbose("Storing tokens to keychain")
		
		let keychain = Keychain(serviceName: keychainServiceName())
		let key = ArchiveKey(keyName: keychainKeyName(), object: items)
		if let error = keychain.update(key) {
			NSLog("Failed to store to keychain: \(error.localizedDescription)")
		}
	}
	
	/** Returns a dictionary of whatever you want to store to the keychain. */
	func storableKeychainItems() -> [String: NSCoding]? {
		return nil
	}
	
	
	// MARK: - Requests
	
	var session: NSURLSession?
	
	public var sessionDelegate: NSURLSessionDelegate? {
		didSet {
			session = nil
		}
	}
	
	/**
	Perform the supplied request and call the callback with the response JSON dict or an error.
	
	This implementation uses the shared `NSURLSession` and executes a data task. If the server responds with an error, this will be
	converted into an error according to information supplied in the response JSON (if availale).
	
	- parameter request: The request to execute
	- parameter callback: The callback to call when the request completes/fails; data and error are mutually exclusive
	*/
	public func performRequest(request: NSURLRequest, callback: ((data: NSData?, status: Int?, error: ErrorType?) -> Void)) {
		let task = URLSession().dataTaskWithRequest(request) { sessData, sessResponse, error in
			if let error = error {
				callback(data: nil, status: nil, error: error)
			}
			else if let data = sessData, let http = sessResponse as? NSHTTPURLResponse {
				callback(data: data, status: http.statusCode, error: nil)
			}
			else {
				let error = OAuth2Error.Generic("Unknown response \(sessResponse) with data “\(NSString(data: sessData!, encoding: NSUTF8StringEncoding))”")
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
			logIfVerbose("Unparsable JSON was: \(str)")
		}
		throw OAuth2Error.JSONParserError
	}
	
	/**
	Create a query string from a dictionary of string: string pairs.
	
	This method does **form encode** the value part. If you're using NSURLComponents you want to assign the return value to
	`percentEncodedQuery`, NOT `query` as this would double-encode the value.
	
	- parameter params: The parameters you want to have encoded
	- returns: An URL-ready query string
	*/
	public final class func queryStringFor(params: OAuth2StringDict) -> String {
		var arr: [String] = []
		for (key, val) in params {
			arr.append("\(key)=\(val.wwwFormURLEncodedString)")
		}
		return arr.joinWithSeparator("&")
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
	
	/**
	Debug logging, will only log if `verbose` is YES.
	*/
	public func logIfVerbose(log: String) {
		if verbose {
			print("OAuth2: \(log)")
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

