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

/// The error domain used for errors during the OAuth2 flow.
let OAuth2ErrorDomain = "OAuth2ErrorDomain"

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
	case JSONParserError
}

/// Typealias to ease working with JSON dictionaries.
public typealias OAuth2JSON = [String: AnyObject]


/**
    Abstract base class for OAuth2 authorization as well as client registration classes.
 */
public class OAuth2Base
{
	/// Server-side settings, as set upon initialization.
	final let settings: OAuth2JSON
	
	/// Set to `true` to log all the things. `false` by default. Use `"verbose": bool` in settings.
	public var verbose = false
	
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
				let error = genOAuth2Error("Unknown response \(sessResponse) with data “\(NSString(data: sessData!, encoding: NSUTF8StringEncoding))”", .NetworkError)
				callback(data: nil, status: nil, error: error)
			}
		}
		task!.resume()
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
		let parts = split(query.characters) { $0 == "&" }.map() { String($0) }
		var params = [String: String](minimumCapacity: parts.count)
		for part in parts {
			let subparts = split(part.characters) { $0 == "=" }.map() { String($0) }
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
	public func errorForErrorResponse(params: OAuth2JSON, fallback: String? = nil) -> NSError {
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

/**
    Convenience function to create an error in the "OAuth2ErrorDomain" error domain.
 */
public func genOAuth2Error(message: String, _ code: OAuth2Error = .Generic) -> NSError {
	return NSError(domain: OAuth2ErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
}

