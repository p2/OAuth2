//
//  OAuth2.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/4/14.
//  Copyright (c) 2014 Pascal Pfiffner. All rights reserved.
//

import Foundation

let OAuth2ErrorDomain = "OAuth2ErrorDomain"

enum OAuth2Error: Int {
	case Generic = 600
	case Unsupported
	case NetworkError
	case PrerequisiteFailed
	case InvalidState
	case AuthorizationError
}


/*!
 *  Base class for specific OAuth2 authentication flow implementations.
 */
class OAuth2 {
	
	/*! Settings, as set upon initialization. */
	let settings: NSDictionary
	
	/*! The client id. */
	let clientId: String
	
	/*! The client secret, usually only needed for code grant. */
	let clientSecret: String?
	
	/*! Base API URL, all paths will be relative to this one. */
	var apiURL: NSURL?
	
	/*! The URL to authorize against. */
	var authURL: NSURL?
	
	/*! The scope currently in use. */
	var scope: String?
	
	/*! The redirect URL string currently in use. */
	var redirect: String?
	
	/*! The state sent to the server when requesting a token; we internally generate a UUID unless it's set manually. */
	var state = ""
	
	/*! The receiver's access token. */
	var accessToken = ""
	
	/*! Closure called on successful authentication. */
	var onAuthorize: ((parameters: NSDictionary) -> Void)?
	
	/*! When authorization fails. */
	var onFailure: ((error: NSError?) -> Void)?
	
	/*! Closure called after onAuthorize OR onFailure, useful for cleanup operations. */
	var afterAuthorizeOrFailure: (wasFailure: Bool -> Void)?
	
	/*! Set to YES to log all the things. NO by default. */
	var verbose = false
	
	/*!
	 *  Designated initializer.
	 *
	 *  Key support is experimental and currently informed by MITREid's reference implementation, with these keys:
	 *    - client_id (string)
	 *    - client_secret (string), usually only needed for code grant
	 *    - api_uri (string)
	 *    - authorize_uri (string)
	 *    - token_uri (string), only for code grant
	 *    - redirect_uris (list of strings)
	 *    - scope (string)
	 *    - verbose (bool, applies to client logging, unrelated to the actual OAuth exchange)
	 *  MITREid: https://github.com/mitreid-connect/
	 */
	init(settings: NSDictionary) {
		self.settings = settings.copy() as NSDictionary
		
		if let cid = settings["client_id"] as? String {
			clientId = cid
		}
		else {
			fatalError("Must supply `client_id` upon initialization")
		}
		
		if let secret = settings["client_secret"] as? String {
			clientSecret = secret
		}
		
		if let api = settings["api_uri"] as? String {
			apiURL = NSURL(string: api)
		}
		if let auth = settings["authorize_uri"] as? String {
			authURL = NSURL(string: auth)
		}
		if let scp = settings["scope"] as? String {
			scope = scp
		}
		
		if let verb = settings["verbose"] as? Bool {
			verbose = verb
		}
		
		logIfVerbose("Initialized with client id \(clientId)")
	}
	
	
	// MARK: OAuth Actions
	
	/*!
	 *  Constructs an authorize URL with the given parameters.
	 *
	 *  It is possible to use the `params` dictionary to override internally generated URL parameters, use it wisely. Subclasses generally provide shortcut
	 *  methods to receive an appropriate authorize (or token) URL.
	 *
	 *  @param base The base URL (with path, if needed) to build the URL upon
	 *  @param redirect The redirect URI string to supply. If it is nil, the first value of the settings' `redirect_uris` entries is used. Must be present in the end!
	 *  @param scope The scope to request
	 *  @param responseType The response type to request; subclasses know which one to supply
	 *  @param params Any additional parameters as dictionary with string keys and values that will be added to the query part
	 */
	func authorizeURL(base: NSURL, var redirect: String?, scope: String?, responseType: String?, params: [String: String]?) -> NSURL {
		
		// verify that we have all parts
		if clientId.isEmpty {
			NSException(name: "OAuth2IncompleteSetup", reason: "I do not yet have a client id, cannot construct an authorize URL", userInfo: nil).raise()
		}
		
		if redirect {
			self.redirect = redirect!
		}
		else if !self.redirect {
			if let redirs = settings["redirect_uris"] as? NSArray {
				if redirs.count > 0 {
					self.redirect = redirs[0] as? String
				}
			}
		}
		if !self.redirect {
			NSException(name: "OAuth2IncompleteSetup", reason: "I need a redirect URI, cannot construct an authorize URL", userInfo: nil).raise()
		}
		
		if state.isEmpty {
			state = NSUUID().UUIDString
		}
		
		// compose the URL
		let comp = NSURLComponents(URL: base, resolvingAgainstBaseURL: true)
		assert("https" == comp.scheme, "You MUST use HTTPS")
		
		var urlParams = [
			"client_id": clientId,
			"redirect_uri": self.redirect!,
			"state": state
		]
		if scope {
			self.scope = scope!
		}
		if self.scope {
			urlParams["scope"] = self.scope!
		}
		if responseType {
			urlParams["response_type"] = responseType!
		}
		
		if params {
			urlParams.addEntries(params!)
		}
		
		comp.query = OAuth2.queryStringFor(urlParams)
		
		let final = comp.URL
		logIfVerbose("Authorizing against \(final.description)")
		return final;
	}
	
	/*!
	 *  Convenience method to be overridden by and used from subclasses.
	 */
	func authorizeURLWithRedirect(redirect: String?, scope: String?, params: [String: String]?) -> NSURL {
		NSException(name: "OAuth2AbstractClassUse", reason: "Abstract class use", userInfo: nil).raise()
		return NSURL()
	}
	
	func handleRedirectURL(redirect: NSURL) {
		NSException(name: "OAuth2AbstractClassUse", reason: "Abstract class use", userInfo: nil).raise()
	}
	
	func didAuthorize(parameters: NSDictionary) {
		onAuthorize?(parameters: parameters)
		afterAuthorizeOrFailure?(false)
	}
	
	func didFail(error: NSError?) {
		onFailure?(error: error)
		afterAuthorizeOrFailure?(true)
	}
	
	
	// MARK: Requests
	
	func request(forURL url: NSURL) -> OAuth2Request {
		return OAuth2Request(URL: url, oauth: self, cachePolicy: .ReturnCacheDataElseLoad, timeoutInterval: 20)
	}
	
	
	// MARK: Utilities
	
	/*!
	 *  Create a query string from a dictionary of string: string pairs.
	 */
	class func queryStringFor(params: [String: String]) -> String {
		var arr: [String] = []
		for (key, val) in params {
			arr.append("\(key)=\(val)")						// NSURLComponents will correctly encode the parameter string
		}
		return "&".join(arr)
	}
	
	/*!
	 *  Parse a query string into a dictionary of string: string pairs.
	 */
	class func paramsFromQuery(query: String) -> [String: String] {
		let parts = query.componentsSeparatedByString("&")
		var params: [String: String] = Dictionary(minimumCapacity: parts.count)
		for part in parts {
			let subparts = part.componentsSeparatedByString("=")
			if 2 == subparts.count {
				params[subparts[0]] = subparts[1]
			}
		}
		
		return params
	}
	
	/*!
	 *  Handles access token error response.
	 *  @param params The URL parameters passed into the redirect URL upon error
	 *  @return An NSError instance with the "best" localized error key and all parameters in the userInfo dictionary; domain "OAuth2ErrorDomain", code 600
	 */
	class func errorForAccessTokenErrorResponse(params: NSDictionary) -> NSError {
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
		
		var error: NSError
		if let prms = params.mutableCopy() as? NSMutableDictionary {
			prms[NSLocalizedDescriptionKey] = message
			error = NSError(domain: OAuth2ErrorDomain, code: OAuth2Error.AuthorizationError.toRaw(), userInfo: prms)
		}
		else {
			error = genOAuth2Error(message, .AuthorizationError)
		}
		
		return error
	}
	
	/*!
	 *  Debug logging, will only log if `verbose` is YES.
	 */
	func logIfVerbose(log: String) {
		if verbose {
			println("OAuth2: \(log)")
		}
	}
}


func genOAuth2Error(message: String) -> NSError {
	return genOAuth2Error(message, .Generic)
}

func genOAuth2Error(message: String, code: OAuth2Error) -> NSError {
	return NSError(domain: OAuth2ErrorDomain, code: code.toRaw(), userInfo: [NSLocalizedDescriptionKey: message])
}

