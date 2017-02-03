//
//  OAuth2Response.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 9/12/16.
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
Encapsulates a URLResponse to a URLRequest.

Instances of this class are returned from `OAuth2Requestable` calls, they can be used like so:

    perform(request: req) { response in
        do {
            let data = try response.responseData()
            // do what you must with `data` as Data and `response.response` as HTTPURLResponse
        }
        catch let error {
            // the request failed because of `error`
        }
    }
*/
open class OAuth2Response {
	
	/// The data that was returned.
	open var data: Data?
	
	/// The request that generated this response.
	open var request: URLRequest
	
	/// The underlying HTTPURLResponse.
	open var response: HTTPURLResponse
	
	/// Error reported by the underlying mechanisms.
	open var error: Error?
	
	
	/**
	Designated initializer.
	
	- parameter data:     Data that was returned
	- parameter request:  The request to which we responded
	- parameter response: The `HTTPURLResponse` to be represented by this instance
	- parameter error:    Error that occurred when handling our request
	*/
	public init(data: Data?, request: URLRequest, response: HTTPURLResponse, error: Error?) {
		self.data = data
		self.request = request
		self.response = response
		self.error = error
	}
	
	
	// MARK: - Response Check
	
	/**
	Throws errors if something with the request went wrong, noop otherwise. You can use this to quickly figure out how to proceed in
	request callbacks.
	
	If data is returned but the status code is >= 400, nothing will be raised **except** if there's a 401 or 403.
	
	- throws:  Specific OAuth2Errors (.requestCancelled, .unauthorizedClient, .noDataInResponse) or any Error returned from the request
	- returns: Response data
	*/
	open func responseData() throws -> Data {
		if let error = error {
			if NSURLErrorDomain == error._domain && -999 == error._code {		// request was cancelled
				throw OAuth2Error.requestCancelled
			}
			throw error
		}
		else if 401 == response.statusCode {
			throw OAuth2Error.unauthorizedClient
		}
		else if 403 == response.statusCode {
			throw OAuth2Error.forbidden
		}
		else if let data = data, data.count > 0 {
			return data
		}
		else {
			throw OAuth2Error.noDataInResponse
		}
	}
	
	/**
	Uses `responseData()`, then decodes JSON using `Foundation.JSONSerialization` on the resulting data (if there was any).
	
	- throws:  Any error thrown by `responseData()`, plus .jsonParserError if JSON did not decode into `[String: Any]`
	- returns: OAuth2JSON on success
	*/
	open func responseJSON() throws -> OAuth2JSON {
		let data = try responseData()
		let json = try JSONSerialization.jsonObject(with: data, options: [])
		if let json = json as? OAuth2JSON {
			return json
		}
		throw OAuth2Error.jsonParserError
	}
}

