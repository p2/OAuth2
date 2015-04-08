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

/**
 *  Errors supplanting NSError codes if no HTTP status code is available (hence >= 600).
 */
public enum OAuth2Error: Int {
	case Generic = 600
	case Unsupported
	case NetworkError
	case PrerequisiteFailed
	case InvalidState
	case AuthorizationError
}

public typealias OAuth2JSON = [String: AnyObject]


/**
 *  Base class for specific OAuth2 authentication flow implementations.
 */
public class OAuth2
{
	/** Settings, as set upon initialization. */
	let settings: OAuth2JSON
	
	/** The client id. */
	public let clientId: String
	
	/** The client secret, usually only needed for code grant. */
	public let clientSecret: String?
	
	/** The URL to authorize against. */
	public var authURL: NSURL?
	
	/** The scope currently in use. */
	public var scope: String?
	
	/** The redirect URL string currently in use. */
	public var redirect: String?
	
	/** The state sent to the server when requesting a token.
		We internally generate a UUID and use the first 8 chars.
	 */
	internal(set) public var state = ""
	
	/** The receiver's access token. */
	public var accessToken = ""
	
	/** The access token's expiry date. */
	public var accessTokenExpiry: NSDate?
	
	/** Closure called on successful authentication on the main thread. */
	public var onAuthorize: ((parameters: OAuth2JSON) -> Void)?
	
	/** When authorization fails (if error is not nil) or is cancelled, this block is executed on the main thread. */
	public var onFailure: ((error: NSError?) -> Void)?
	
	/**
		Closure called after onAuthorize OR onFailure, on the main thread; useful for cleanup operations.
	
		:param: wasFailure Bool indicating success or failure
		:param: error NSError describing the reason for failure, as supplied to the `onFailure` callback. If it is nil
		        and wasFailure is true, the process was aborted.
	 */
	public var afterAuthorizeOrFailure: ((wasFailure: Bool, error: NSError?) -> Void)?
	
	/** An optional title that will propagate to views handled by OAuth2, such as OAuth2WebViewController. */
	public var viewTitle: String?
	
	/** Set to YES to log all the things. NO by default. */
	public var verbose = false
	
	/**
		Designated initializer.
	
		Key support is experimental and currently informed by MITREid's reference implementation, with these keys:
	
		- client_id (string)
		- client_secret (string), usually only needed for code grant
		- authorize_uri (string)
		- token_uri (string), only for code grant
		- redirect_uris (list of strings)
		- scope (string)
		- verbose (bool, applies to client logging, unrelated to the actual OAuth exchange)
	
		MITREid: https://github.com/mitreid-connect/
	 */
	public init(settings: OAuth2JSON) {
		self.settings = settings
		
		if let cid = settings["client_id"] as? String {
			clientId = cid
		}
		else {
			fatalError("Must supply `client_id` upon initialization")
		}
		
		if let secret = settings["client_secret"] as? String {
			clientSecret = secret
		}
		
		if let auth = settings["authorize_uri"] as? String {
			authURL = NSURL(string: auth)
		}
		if let scp = settings["scope"] as? String {
			scope = scp
		}
		
		if let st = settings["scope_for_testing"] as? String {
			state = st
		}
		if let verb = settings["verbose"] as? Bool {
			verbose = verb
		}
		
		logIfVerbose("Initialized with client id \(clientId)")
	}
	
	
	// MARK: - OAuth Actions
	
	/** If the instance has an accessToken, checks if its expiry time has not yet passed. If we don't have an expiry
		date we assume the token is still valid.
	 */
	public func hasUnexpiredAccessToken() -> Bool {
		if !accessToken.isEmpty {
			if let expiry = accessTokenExpiry {
				return expiry == expiry.laterDate(NSDate())
			}
			return true
		}
		return false
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
	public func authorizeURL(base: NSURL, var redirect: String?, scope: String?, responseType: String?, params: [String: String]?) -> NSURL {
		
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
	
		:returns: NSURL to be used to start the OAuth dance
	 */
	public func authorizeURL() -> NSURL {
		return authorizeURLWithRedirect(nil, scope: nil, params: nil)
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
		callOnMainThread() {
			self.onAuthorize?(parameters: parameters)
			self.afterAuthorizeOrFailure?(wasFailure: false, error: nil)
		}
	}
	
	/**
		Internally used on error. Calls the `onFailure` and `afterAuthorizeOrFailure` callbacks on the main thread.
	 */
	func didFail(error: NSError?) {
		callOnMainThread() {
			self.onFailure?(error: error)
			self.afterAuthorizeOrFailure?(wasFailure: true, error: error)
		}
	}
	
	
	// MARK: - Requests
	
	/**
		Return an OAuth2Request, a NSMutableURLRequest subclass, that has already been signed and can be used against
		your OAuth2 endpoint.
		
		This method prefers cached data and specifies a timeout interval of 20 seconds.
	 */
	public func request(forURL url: NSURL) -> OAuth2Request {
		return OAuth2Request(URL: url, oauth: self, cachePolicy: .ReturnCacheDataElseLoad, timeoutInterval: 20)
	}
	
	
	// MARK: - Utilities
	
	/**
		Create a query string from a dictionary of string: string pairs.
	
		This method does **form encode** the value part. If you're using NSURLComponents you want to assign the return
		value to `percentEncodedQuery`, NOT `query` as this would double-encode the value.
	 */
	public class func queryStringFor(params: [String: String]) -> String {
		var arr: [String] = []
		for (key, val) in params {
			arr.append("\(key)=\(val.wwwFormURLEncodedString)")
		}
		return "&".join(arr)
	}
	
	/**
		Parse a query string into a dictionary of string: string pairs.
	
		If you're retrieving a query or fragment from NSURLComponents, use the `percentEncoded##` variant as the others
		automatically perform percent decoding, potentially messing with your query string.
	 */
	public class func paramsFromQuery(query: String) -> [String: String] {
		let parts = split(query) { $0 == "&" }
		var params: [String: String] = Dictionary(minimumCapacity: parts.count)
		for part in parts {
			let subparts = split(part) { $0 == "=" }
			if 2 == subparts.count {
				params[subparts[0]] = subparts[1].wwwFormURLDecodedString
			}
		}
		
		return params
	}
	
	/**
		Handles access token error response.
	
		:param: params The URL parameters passed into the redirect URL upon error
		:returns: An NSError instance with the "best" localized error key and all parameters in the userInfo dictionary;
		          domain "OAuth2ErrorDomain", code 600
	 */
	class func errorForAccessTokenErrorResponse(params: OAuth2JSON) -> NSError {
		var message = ""
		
		// "error_description" is optional, we prefer it if it's present
		if let err_msg = params["error_description"] as? String {
			message = err_msg.stringByReplacingOccurrencesOfString("+", withString: " ")
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
			message = "Unknown error."
		}
		
		var prms = params
		prms[NSLocalizedDescriptionKey] = message
		return NSError(domain: OAuth2ErrorDomain, code: OAuth2Error.AuthorizationError.rawValue, userInfo: prms)
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
		dispatch_sync(dispatch_get_main_queue(), {
			callback()
		})
	}
}

/**
	Convenience function to create an error in the "OAuth2ErrorDomain" error domain.
 */
public func genOAuth2Error(message: String, _ code: OAuth2Error = .Generic) -> NSError {
	return NSError(domain: OAuth2ErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
}

