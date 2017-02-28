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
	
	/// "GET" is the HTTP method of choice.
	case GET = "GET"
	
	/// This is a "POST" method.
	case POST = "POST"
}


/**
Content types that will be specified in the request header under "Content-type".
*/
public enum OAuth2HTTPContentType: String {
	
	/// JSON content: `application/json`
	case json = "application/json"
	
	/// Form encoded content, using UTF-8: `application/x-www-form-urlencoded; charset=utf-8`
	case wwwForm = "application/x-www-form-urlencoded; charset=utf-8"
}


/**
The auth method supported by the endpoint.
*/
public enum OAuth2EndpointAuthMethod: String {
	
	/// No auth method is to be used. Good luck with that.
	case none = "none"
	
	/// The `client_secret_post` method should be used.
	case clientSecretPost = "client_secret_post"
	
	/// The `client_secret_basic` method should be used.
	case clientSecretBasic = "client_secret_basic"
}


/**
Class representing an OAuth2 authorization request that can be used to create NSURLRequest instances.
*/
open class OAuth2AuthRequest {
	
	/// The url of the receiver. Queries may by added by parameters specified on `params`.
	open let url: URL
	
	/// The HTTP method.
	open let method: OAuth2HTTPMethod
	
	/// The content type that will be specified. Defaults to `wwwForm`.
	open var contentType = OAuth2HTTPContentType.wwwForm
	
	/// Custom headers can be set here, they will take precedence over any built-in headers.
	open private(set) var headers: [String: String]?
	
	/// Query parameters to use with the request.
	open var params = OAuth2RequestParams()
	
	
	/**
	Designated initializer. Neither URL nor method can later be changed.
	*/
	public init(url: URL, method: OAuth2HTTPMethod = .POST) {
		self.url = url
		self.method = method
	}
	
	
	// MARK: - Headers
	
	/**
	Set the given custom header.
	
	- parameter header: The header's name
	- parameter value:  The value to use
	*/
	public func set(header: String, to value: String) {
		if nil == headers {
			headers = [header: value]
		}
		else {
			headers![header] = value
		}
	}
	
	/**
	Unset the given header so that the default can be applied again.
	
	- parameter header: The header's name
	*/
	public func unset(header: String) {
		_ = headers?.removeValue(forKey: header)
	}
	
	
	// MARK: - Parameter
	
	/**
	Add the given parameter to the receiver's parameter list, overwriting existing parameters. This method can take nil for convenience.
	
	- parameter params: The parameters to add to the receiver
	*/
	open func add(params inParams: OAuth2StringDict?) {
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
	func asURLComponents() throws -> URLComponents {
		let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
		guard var components = comp, "https" == components.scheme else {
			throw OAuth2Error.notUsingTLS
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
	open func asURL() throws -> URL {
		let comp = try asURLComponents()
		if let finalURL = comp.url {
			return finalURL
		}
		throw OAuth2Error.invalidURLComponents(comp)
	}
	
	/**
	Creates a mutable URL request from the receiver, taking into account settings from the provided OAuth2 instance.
	
	- parameter oauth2: The OAuth2 instance from which to take client and auth settings
	- returns: A mutable NSURLRequest
	*/
	open func asURLRequest(for oauth2: OAuth2Base) throws -> URLRequest {
		var finalParams = params
		
		// base request
		let finalURL = try asURL()
		var req = URLRequest(url: finalURL)
		req.httpMethod = method.rawValue
		req.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
		
		// handle client secret if there is one
		if let clientId = oauth2.clientConfig.clientId, !clientId.isEmpty, let secret = oauth2.clientConfig.clientSecret {
			
			// add to request body
			if oauth2.clientConfig.secretInBody {
				oauth2.logger?.debug("OAuth2", msg: "Adding “client_id” and “client_secret” to request body")
				finalParams["client_id"] = clientId
				finalParams["client_secret"] = secret
			}
			
			// add Authorization header (if not in body)
			else {
				oauth2.logger?.debug("OAuth2", msg: "Adding “Authorization” header as “Basic client-key:client-secret”")
				let pw = "\(clientId.wwwFormURLEncodedString):\(secret.wwwFormURLEncodedString)"
				if let utf8 = pw.data(using: oauth2.clientConfig.authStringEncoding) {
					req.setValue("Basic \(utf8.base64EncodedString())", forHTTPHeaderField: "Authorization")
				}
				else {
					throw OAuth2Error.utf8EncodeError
				}
				finalParams.removeValue(forKey: "client_id")
				finalParams.removeValue(forKey: "client_secret")
			}
		}
		
		// add custom headers, first from our OAuth2 instance, then our custom ones
		if let headers = oauth2.authHeaders {
			for (key, val) in headers {
				oauth2.logger?.trace("OAuth2", msg: "Overriding “\(key)” header")
				req.setValue(val, forHTTPHeaderField: key)
			}
		}
		if let headers = headers {
			for (key, val) in headers {
				oauth2.logger?.trace("OAuth2", msg: "Adding custom “\(key)” header")
				req.setValue(val, forHTTPHeaderField: key)
			}
		}
		if let customParameters = oauth2.clientConfig.customParameters {
			for (k, v) in customParameters {
				finalParams[k] = v
			}
		}
		// add a body to POST requests
		if .POST == method && finalParams.count > 0 {
			req.httpBody = try finalParams.utf8EncodedData()
		}
		return req
	}
}


/**
Struct to hold on to request parameters.

Provides utility functions so the parameters can be correctly encoded for use in URLs and request bodies.
*/
public struct OAuth2RequestParams {
	
	/// The parameters to be used.
	public private(set) var params: OAuth2StringDict? = nil
	
	/** Designated initalizer. */
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
	
	- parameter forKey: The key for the value to be removed
	- returns: The value that was removed, if any
	*/
	@discardableResult
	public mutating func removeValue(forKey key: String) -> String? {
		return params?.removeValue(forKey: key)
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
	public func utf8EncodedData() throws -> Data? {
		guard nil != params else {
			return nil
		}
		let body = percentEncodedQueryString()
		if let encoded = body.data(using: String.Encoding.utf8, allowLossyConversion: true) {
			return encoded
		}
		else {
			throw OAuth2Error.utf8EncodeError
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
		return type(of: self).formEncodedQueryStringFor(params)
	}
	
	/**
	Create a query string from a dictionary of string: string pairs.
	
	This method does **form encode** the value part. If you're using NSURLComponents you want to assign the return value to
	`percentEncodedQuery`, NOT `query` as this would double-encode the value.
	
	- parameter params: The parameters you want to have encoded
	- returns: An URL-ready query string
	*/
	public static func formEncodedQueryStringFor(_ params: OAuth2StringDict) -> String {
		var arr: [String] = []
		for (key, val) in params {
			arr.append("\(key)=\(val.wwwFormURLEncodedString)")
		}
		return arr.joined(separator: "&")
	}
}

