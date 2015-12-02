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


extension NSHTTPURLResponse
{
	/// A localized string explaining the current `statusCode`.
	public var statusString: String {
		get {
			return NSHTTPURLResponse.localizedStringForStatusCode(self.statusCode)
		}
	}
}


extension String
{
	private static var wwwFormURLPlusSpaceCharacterSet: NSCharacterSet = NSMutableCharacterSet.wwwFormURLPlusSpaceCharacterSet()
	
	/// Encodes a string to become x-www-form-urlencoded; the space is encoded as plus sign (+).
	var wwwFormURLEncodedString: String {
		let characterSet = String.wwwFormURLPlusSpaceCharacterSet
		return (stringByAddingPercentEncodingWithAllowedCharacters(characterSet) ?? "").stringByReplacingOccurrencesOfString(" ", withString: "+")
	}
	
	/// Decodes a percent-encoded string and converts the plus sign into a space.
	var wwwFormURLDecodedString: String {
		let rep = stringByReplacingOccurrencesOfString("+", withString: " ")
		return rep.stringByRemovingPercentEncoding ?? rep
	}
}


extension NSMutableCharacterSet
{
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
	class func wwwFormURLPlusSpaceCharacterSet() -> NSMutableCharacterSet {
		let set = NSMutableCharacterSet.alphanumericCharacterSet()
		set.addCharactersInString("-._* ")
		return set
	}
}


extension NSURLRequest {
	
	/** Print the requests's headers and body to stdout. */
	public func oauth2_print() {
		print("---")
		print("HTTP/1.1 \(HTTPMethod) \(URL?.description ?? "/")")
		allHTTPHeaderFields?.forEach() { print("\($0): \($1)") }
		print("")
		if let data = HTTPBody, let body = NSString(data: data, encoding: NSUTF8StringEncoding) {
			print(body as String)
		}
		print("---")
	}
}

