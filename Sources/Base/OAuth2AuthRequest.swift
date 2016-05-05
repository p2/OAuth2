//
//  OAuth2AuthRequest.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 18/03/16.
//  Copyright © 2016 Pascal Pfiffner. All rights reserved.
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
HTTP methods for auth requests.
*/
public enum OAuth2HTTPMethod: String {
	case GET = "GET"
	case POST = "POST"
}


/**
Content types that will be specified in the request header under "Content-type".
*/
public enum OAuth2HTTPContentType: String {
	
	/// JSON content: `application/json`
	case JSON = "application/json"
	
	/// Form encoded content, using UTF-8: `application/x-www-form-urlencoded; charset=utf-8`
	case WWWForm = "application/x-www-form-urlencoded; charset=utf-8"
}


/**
Class representing an OAuth2 authorization request that can be used to create NSURLRequest instances.
*/
public class OAuth2AuthRequest {
	
	/// The url of the receiver. Queries may by added by parameters specified on `params`.
	public let url: NSURL
	
	/// The HTTP method.
	public let method: OAuth2HTTPMethod
	
	/// The content type that will be specified. Defaults to `WWWForm`.
	public var contentType = OAuth2HTTPContentType.WWWForm
	
	/// If set will take preference over any "Authorize" header that would otherwise be set.
	public var headerAuthorize: String?
	
	public var params = OAuth2AuthRequestParams()
	
	
	/**
	Designated initializer. Neither URL nor method can later be changed.
	*/
	public init(url: NSURL, method: OAuth2HTTPMethod = .POST) {
		self.url = url
		self.method = method
	}
	
	
	// MARK: - Parameter
	
	/**
	Add the given parameter to the receiver's parameter list, overwriting existing parameters. This method can take nil for convenience.
	
	- parameter params: The parameters to add to the receiver
	*/
	public func addParams(params inParams: OAuth2StringDict?) {
		if let prms = inParams {
			for (key, val) in prms {
				params[key] = val
			}
		}
	}
	
	
	// MARK: - Request Creation
	
	/**
	Returns URL components created from the receiver. Only if its method is GET will it add the parameters as percent encoded query.
	
	- returns: NSURLComponents representing the receiver
	*/
	func asURLComponents() throws -> NSURLComponents {
		let comp = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
		guard let components = comp where "https" == components.scheme else {
			throw OAuth2Error.NotUsingTLS
		}
		if .GET == method && params.count > 0 {
			components.percentEncodedQuery = params.percentEncodedQueryString()
		}
		return components
	}
	
	/**
	Creates an NSURL from the receiver's components; calls `asURLComponents()`, so its caveats apply.
	
	- returns: An NSURL representing the receiver
	*/
	public func asURL() throws -> NSURL {
		let comp = try asURLComponents()
		if let finalURL = comp.URL {
			return finalURL
		}
		throw OAuth2Error.InvalidURLComponents(comp)
	}
	
	/**
	Creates a mutable URL request from the receiver, taking into account settings from the provided OAuth2 instance.
	
	- parameter oauth2: The OAuth2 instance from which to take client and auth settings
	- returns: A mutable NSURLRequest
	*/
	public func asURLRequestFor(oauth2: OAuth2) throws -> NSMutableURLRequest {
		guard let clientId = oauth2.clientId where !clientId.isEmpty else {
			throw OAuth2Error.NoClientId
		}
		
		var finalParams = params
		var finalAuthHeader = headerAuthorize
		
		// base request
		let finalURL = try asURL()
		let req = NSMutableURLRequest(URL: finalURL)
		req.HTTPMethod = method.rawValue
		req.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
		
		// handle client secret if there is one
		if let secret = oauth2.clientConfig.clientSecret {
			
			// add to request body
			if oauth2.authConfig.secretInBody {
				oauth2.logger?.debug("OAuth2", msg: "Adding “client_id” and “client_secret” to request body")
				finalParams["client_id"] = clientId
				finalParams["client_secret"] = secret
			}
			
			// add Authorization header (if not in body)
			else if nil == finalAuthHeader {
				oauth2.logger?.debug("OAuth2", msg: "Adding “Authorization” header as “Basic client-key:client-secret”")
				let pw = "\(clientId.wwwFormURLEncodedString):\(secret.wwwFormURLEncodedString)"
				if let utf8 = pw.dataUsingEncoding(NSUTF8StringEncoding) {
					finalAuthHeader = "Basic \(utf8.base64EncodedStringWithOptions([]))"
				}
				else {
					throw OAuth2Error.UTF8EncodeError
				}
				finalParams.removeValueForKey("client_id")
				finalParams.removeValueForKey("client_secret")
			}
		}
		
		// add custom Authorize header
		if let authHeader = finalAuthHeader {
			req.setValue(authHeader, forHTTPHeaderField: "Authorization")
		}
		
		// add a body to POST requests
		if .POST == method && finalParams.count > 0 {
			req.HTTPBody = try finalParams.utf8EncodedData()
		}
		return req
	}
}


/**
Struct to hold on to request parameters. Provides utility functions so the parameters can be correctly encoded for use in URLs and request
bodies.
*/
public struct OAuth2AuthRequestParams {
	
	/// The parameters to be used.
	private var params: OAuth2StringDict? = nil
	
	public init() {  }
	
	public subscript(key: String) -> String? {
		get {
			return params?[key]
		}
		set(newValue) {
			params = params ?? OAuth2StringDict()
			params![key] = newValue
		}
	}
	
	/**
	Removes the given value from the receiver, if it is defined.
	
	- parameter key: The key for the value to be removed
	- returns: The value that was removed, if any
	*/
	public mutating func removeValueForKey(key: String) -> String? {
		return params?.removeValueForKey(key)
	}
	
	/// The number of items in the receiver.
	public var count: Int {
		return params?.count ?? 0
	}
	
	
	// MARK: - Conversion
	
	/**
	Creates a form encoded query string, then encodes it using UTF-8 to NSData.
	
	- returns: NSData representing the receiver form-encoded
	*/
	public func utf8EncodedData() throws -> NSData? {
		guard nil != params else {
			return nil
		}
		let body = percentEncodedQueryString()
		if let encoded = body.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true) {
			return encoded
		}
		else {
			throw OAuth2Error.UTF8EncodeError
		}
	}
	
	/**
	Creates a parameter string in the form of `key1=value1&key2=value2`, using form URL encoding.
	
	- returns: A form encoded string
	*/
	public func percentEncodedQueryString() -> String {
		guard let params = params else {
			return ""
		}
		return self.dynamicType.formEncodedQueryStringFor(params)
	}
	
	/**
	Create a query string from a dictionary of string: string pairs.
	
	This method does **form encode** the value part. If you're using NSURLComponents you want to assign the return value to
	`percentEncodedQuery`, NOT `query` as this would double-encode the value.
	
	- parameter params: The parameters you want to have encoded
	- returns: An URL-ready query string
	*/
	public static func formEncodedQueryStringFor(params: OAuth2StringDict) -> String {
		var arr: [String] = []
		for (key, val) in params {
			arr.append("\(key)=\(val.wwwFormURLEncodedString)")
		}
		return arr.joinWithSeparator("&")
	}
}

