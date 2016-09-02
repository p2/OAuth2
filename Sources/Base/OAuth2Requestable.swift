//
//  OAuth2Requestable.swift
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
public typealias OAuth2JSON = [String: Any]

/// Typealias to work with dictionaries full of strings.
public typealias OAuth2StringDict = [String: String]


/**
Abstract base class for OAuth2 authorization as well as client registration classes.
*/
open class OAuth2Requestable {
	
	/// Set to `true` to log all the things. `false` by default. Use `"verbose": bool` in settings or assign `logger` yourself.
	open var verbose = false {
		didSet {
			logger = verbose ? OAuth2DebugLogger() : nil
		}
	}
	
	/// The logger being used. Auto-assigned to a debug logger if you set `verbose` to true or false.
	open var logger: OAuth2Logger?
	
	
	/**
	Base initializer.
	*/
	public init(verbose: Bool) {
		self.verbose = verbose
		logger = verbose ? OAuth2DebugLogger() : nil
		logger?.debug("OAuth2", msg: "Initialization finished")
	}
	
	public init(logger: OAuth2Logger?) {
		self.logger = logger
		self.verbose = (nil != logger)
		logger?.debug("OAuth2", msg: "Initialization finished")
	}
	
	
	// MARK: - Requests
	
	/// The instance's current session, creating one by the book if necessary. Defaults to using an ephemeral session, you can use
	/// `sessionConfiguration` and/or `sessionDelegate` to affect how the session is configured.
	open var session: URLSession {
		if nil == _session {
			let config = sessionConfiguration ?? URLSessionConfiguration.ephemeral
			_session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
		}
		return _session!
	}
	
	/// The backing store for `session`.
	private var _session: URLSession?
	
	/// The configuration to use when creating `session`. Uses an `+ephemeralSessionConfiguration()` if nil.
	open var sessionConfiguration: URLSessionConfiguration? {
		didSet {
			_session = nil
		}
	}
	
	/// URL session delegate that should be used for the `NSURLSession` the instance uses for requests.
	open var sessionDelegate: URLSessionDelegate? {
		didSet {
			_session = nil
		}
	}
	
	/**
	Perform the supplied request and call the callback with the response JSON dict or an error. This method is intended for authorization
	calls, not for data calls outside of the OAuth2 dance.
	
	This implementation uses the shared `NSURLSession` and executes a data task. If the server responds with an error, this will be
	converted into an error according to information supplied in the response JSON (if availale).
	
	The callback looks terrifying but is actually easy to use, like so:
	
	    perform(request: req) { dataStatusResponse in
	        do {
	            let (data, status) = try dataStatusResponse()
	            // do what you must with `data` as Data and `status` as Int
	        }
	        catch let error {
	            // the request failed because of `error`
	        }
	    }
	
	Easy, right?
	
	- parameter request:  The request to execute
	- parameter callback: The callback to call when the request completes/fails. Looks terrifying, see above on how to use it
	*/
	open func perform(request: URLRequest, callback: @escaping ((Void) throws -> (Data, Int)) -> Void) {
		self.logger?.trace("OAuth2", msg: "REQUEST\n\(request.debugDescription)\n---")
		let task = session.dataTask(with: request) { sessData, sessResponse, error in
			self.abortableTask = nil
			self.logger?.trace("OAuth2", msg: "RESPONSE\n\(sessResponse?.debugDescription ?? "no response")\n\n\(String(data: sessData ?? Data(), encoding: String.Encoding.utf8) ?? "no data")\n---")
			do {
				let (data, status) = try self.requestDidReturn(with: sessData, response: sessResponse, error: error)
				callback({ return (data, status) })
			}
			catch let error {
				callback({ throw error })
			}
		}
		abortableTask = task
		task.resume()
	}
	
	/**
	Can be fed the output of `NSURLSession.dataTask(with:completionHandler:)` and either throws or returns data and the HTTP status code.
	
	- parameter data:     A hopefully non-nil Data instance
	- parameter response: The URLResponse, hopefully as HTTPURLResponse
	- parameter error:    An error that might have been returned
	- returns:            A tuple containing non-optional data and the HTTP status code
	*/
	func requestDidReturn(with data: Data?, response: URLResponse?, error: Error?) throws -> (Data, Int) {
		if let error = error {
			if NSURLErrorDomain == error._domain && -999 == error._code {		// request was cancelled
				throw OAuth2Error.requestCancelled
			}
			throw error
		}
		else if let data = data, let http = response as? HTTPURLResponse {
			if 401 == http.statusCode {
				throw OAuth2Error.unauthorizedClient
			}
			return (data, http.statusCode)
		}
		if nil == data {
			throw OAuth2Error.noDataInResponse
		}
		throw OAuth2Error.generic("Unknown response \(response) with data “\(String(data: data!, encoding: String.Encoding.utf8))”")
	}
	
	/// Currently running abortable session task.
	private var abortableTask: URLSessionTask?
	
	/**
	Can be called to immediately abort the currently running authorization request, if it was started by `perform(request:callback:)`.
	
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
	
	
	// MARK: - Utilities
	
	/**
	Parse string-only JSON from NSData.
	
	- parameter data: NSData returned from the call, assumed to be JSON with string-values only.
	- returns: An OAuth2JSON instance
	*/
	open func parseJSON(_ data: Data) throws -> OAuth2JSON {
		do {
			let json = try JSONSerialization.jsonObject(with: data, options: [])
			if let json = json as? OAuth2JSON {
				return json
			}
			if let str = String(data: data, encoding: String.Encoding.utf8) {
				logger?.warn("OAuth2", msg: "JSON did not resolve to a dictionary, was: \(str)")
			}
			throw OAuth2Error.jsonParserError
		}
		catch let error where NSCocoaErrorDomain == error._domain && 3840 == error._code {		// JSON parser error
			if let str = String(data: data, encoding: String.Encoding.utf8) {
				logger?.warn("OAuth2", msg: "Unparsable JSON was: \(str)")
			}
			throw OAuth2Error.jsonParserError
		}
	}
	
	/**
	Parse a query string into a dictionary of String: String pairs.
	
	If you're retrieving a query or fragment from NSURLComponents, use the `percentEncoded##` variant as the others
	automatically perform percent decoding, potentially messing with your query string.
	
	- parameter fromQuery: The query string you want to have parsed
	- returns: A dictionary full of strings with the key-value pairs found in the query
	*/
	public final class func params(fromQuery query: String) -> OAuth2StringDict {
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
public func callOnMainThread(_ callback: ((Void) -> Void)) {
	if Thread.isMainThread {
		callback()
	}
	else {
		DispatchQueue.main.sync(execute: callback)
	}
}

