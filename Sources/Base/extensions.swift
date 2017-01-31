//
//  extensions.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/6/14.
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


extension HTTPURLResponse {
	
	/// A localized string explaining the current `statusCode`.
	public var statusString: String {
		get {
			return HTTPURLResponse.localizedString(forStatusCode: self.statusCode)
		}
	}
}


extension String {
	
	fileprivate static var wwwFormURLPlusSpaceCharacterSet: CharacterSet = CharacterSet.wwwFormURLPlusSpaceCharacterSet
	
	/// Encodes a string to become x-www-form-urlencoded; the space is encoded as plus sign (+).
	var wwwFormURLEncodedString: String {
		let characterSet = String.wwwFormURLPlusSpaceCharacterSet
		return (addingPercentEncoding(withAllowedCharacters: characterSet) ?? "").replacingOccurrences(of: " ", with: "+")
	}
	
	/// Decodes a percent-encoded string and converts the plus sign into a space.
	var wwwFormURLDecodedString: String {
		let rep = replacingOccurrences(of: "+", with: " ")
		return rep.removingPercentEncoding ?? rep
	}
}


extension CharacterSet {
	
	/**
	Return the character set that does NOT need percent-encoding for x-www-form-urlencoded requests INCLUDING SPACE.
	YOU are responsible for replacing spaces " " with the plus sign "+".
	
	RFC3986 and the W3C spec are not entirely consistent, we're using W3C's spec which says:
	http://www.w3.org/TR/html5/forms.html#application/x-www-form-urlencoded-encoding-algorithm
	
	> If the byte is 0x20 (U+0020 SPACE if interpreted as ASCII):
	> - Replace the byte with a single 0x2B byte ("+" (U+002B) character if interpreted as ASCII).
	> If the byte is in the range 0x2A (*), 0x2D (-), 0x2E (.), 0x30 to 0x39 (0-9), 0x41 to 0x5A (A-Z), 0x5F (_),
	> 0x61 to 0x7A (a-z)
	> - Leave byte as-is
	*/
	static var wwwFormURLPlusSpaceCharacterSet: CharacterSet {
		var set = CharacterSet().union(CharacterSet.alphanumerics)
		set.insert(charactersIn: "-._* ")
		return set
	}
}


extension URLRequest {
	
	/** A string describing the request, including headers and body. */
	public var debugDescription: String {
		var msg = "HTTP/1.1 \(httpMethod ?? "METHOD") \(url?.description ?? "/")"
		allHTTPHeaderFields?.forEach() { msg += "\n\($0): \($1)" }
		if let data = httpBody, let body = String(data: data, encoding: String.Encoding.utf8) {
			msg += "\n\n\(body)"
		}
		return msg
	}
	
	/**
	Signs the receiver by setting its "Authorization" header to "Bearer {token}".
	
	Will throw if the OAuth2 instance does not have an access token.
	
	- parameter oauth2: The OAuth2 instance providing the access token to sign the request
	*/
	public mutating func sign(with oauth2: OAuth2Base) throws {
		guard let access = oauth2.clientConfig.accessToken, !access.isEmpty else {
			throw OAuth2Error.noAccessToken
		}
		setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
	}
	
	/**
	Returns a copy of the receiver, signed by setting its "Authorization" header to "Bearer {token}".
	
	Will throw if the OAuth2 instance does not have an access token.
	
	- parameter oauth2: The OAuth2 instance providing the access token to sign the receiver
	*/
	public func signed(with oauth2: OAuth2Base) throws -> URLRequest {
		var signed = self
		try signed.sign(with: oauth2)
		return signed
	}
}


extension HTTPURLResponse {
	
	/** Format HTTP status and response headers as is customary. */
	override open var debugDescription: String {
		var msg = "HTTP/1.1 \(statusCode) \(statusString)"
		allHeaderFields.forEach() { msg += "\n\($0): \($1)" }
		return msg
	}
}

