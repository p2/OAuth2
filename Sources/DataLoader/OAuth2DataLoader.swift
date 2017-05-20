//
//  OAuth2DataLoader.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 8/31/16.
//  Copyright 2016 Pascal Pfiffner
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
#if !NO_MODULE_IMPORT
import Base
import Flows
#endif


/**
A class that makes loading data from a protected endpoint easier.
*/
open class OAuth2DataLoader: OAuth2Requestable {
	
	/// The OAuth2 instance used for OAuth2 access tokvarretrieval.
	public let oauth2: OAuth2
	
	/// If set to true, a 403 is treated as a 401. The default is false.
	public var alsoIntercept403: Bool = false
	
	
	/**
	Designated initializer.
	
	Provide `host` if 301 and 302 redirects should be followed automatically, as long as they appear on the same host.
	
	- parameter oauth2: The OAuth2 instance to use for authorization when loading data.
	- parameter host:   If given will handle redirects within the same host by way of `OAuth2DataLoaderSessionTaskDelegate`
	*/
	public init(oauth2: OAuth2, host: String? = nil) {
		self.oauth2 = oauth2
		super.init(logger: oauth2.logger)
		if let host = host {
			sessionDelegate = OAuth2DataLoaderSessionTaskDelegate(loader: self, host: host)
		}
	}
	
	
	// MARK: - Make Requests
	
	/// Our FIFO queue.
	private var enqueued: [OAuth2DataRequest]?
	
	private var isAuthorizing = false
	
	/**
	Overriding this method: it intercepts `unauthorizedClient` errors, stops and enqueues all calls, starts the authorization and, upon
	success, resumes all enqueued calls.
	
	The callback is easy to use, like so:
	
	    perform(request: req) { dataStatusResponse in
	        do {
	            let (data, status) = try dataStatusResponse()
	            // do what you must with `data` as Data and `status` as Int
	        }
	        catch let error {
	            // the request failed because of `error`
	        }
	    }
	
	- parameter request:  The request to execute
	- parameter callback: The callback to call when the request completes/fails. Looks terrifying, see above on how to use it
	*/
	override open func perform(request: URLRequest, callback: @escaping ((OAuth2Response) -> Void)) {
		perform(request: request, retry: true, callback: callback)
	}
	
	/**
	This method takes an additional `retry` flag, then uses the base implementation of `perform(request:callback:)` to perform the given
	request. It intercepts 401 (and 403, if `alsoIntercept403` is true), enqueues the request and performs authorization. During
	authorization, all requests to be performed are enqueued and they are all dequeued once authorization finishes, either by retrying
	them on authorization success or by aborting them all with the same error.
	
	The callback is easy to use, like so:
	
	    perform(request: req) { dataStatusResponse in
	        do {
	            let (data, status) = try dataStatusResponse()
	            // do what you must with `data` as Data and `status` as Int
	        }
	        catch let error {
	            // the request failed because of `error`
	        }
	    }
	
	- parameter request:  The request to execute
	- parameter retry:    Whether the request should be retried on 401 (and possibly 403)
	- parameter callback: The callback to call when the request completes/fails
	*/
	open func perform(request: URLRequest, retry: Bool, callback: @escaping ((OAuth2Response) -> Void)) {
		guard !isAuthorizing else {
			enqueue(request: request, callback: callback)
			return
		}
		
		super.perform(request: request) { response in
			do {
				if self.alsoIntercept403, 403 == response.response.statusCode {
					throw OAuth2Error.unauthorizedClient
				}
				let _ = try response.responseData()
				callback(response)
			}
			
			// not authorized; stop and enqueue all requests, start authorization once, then re-try all enqueued requests
			catch OAuth2Error.unauthorizedClient {
				if retry {
					self.enqueue(request: request, callback: callback)
					self.oauth2.clientConfig.accessToken = nil
					self.attemptToAuthorize() { json, error in
						
						// dequeue all if we're authorized, throw all away if something went wrong
						if nil != json {
							self.retryAll()
						}
						else {
							self.throwAllAway(with: error ?? OAuth2Error.requestCancelled)
						}
					}
				}
				else {
					callback(response)
				}
			}
			
			// some other error, pass along
			catch {
				callback(response)
			}
		}
	}
	
	/**
	If not already authorizing, will use its `oauth2` instance to start authorization after forgetting any tokens (!).
	
	This method will ignore calls while authorization is ongoing, meaning you will only get the callback once per authorization cycle.
	
	- parameter callback: The callback passed on from `authorize(callback:)`. Authorization finishes successfully (auth parameters will be
	                      non-nil but may be an empty dict), fails (error will be non-nil) or is canceled (both params and error are nil)
	*/
	open func attemptToAuthorize(callback: @escaping ((OAuth2JSON?, OAuth2Error?) -> Void)) {
		if !isAuthorizing {
			isAuthorizing = true
			oauth2.authorize() { authParams, error in
				self.isAuthorizing = false
				callback(authParams, error)
			}
		}
	}
	
	
	// MARK: - Queue
	
	/**
	Enqueues the given URLRequest and callback. You probably don't want to use this method yourself.
	
	- parameter request:  The URLRequest to enqueue for later execution
	- parameter callback: The closure to call when the request has been executed
	*/
	public func enqueue(request: URLRequest, callback: @escaping ((OAuth2Response) -> Void)) {
		enqueue(request: OAuth2DataRequest(request: request, callback: callback))
	}
	
	/**
	Enqueues the given OAuth2DataRequest. You probably don't want to use this method yourself.
	
	- parameter request:  The OAuth2DataRequest to enqueue for later execution
	*/
	public func enqueue(request: OAuth2DataRequest) {
		if nil == enqueued {
			enqueued = [request]
		}
		else {
			enqueued!.append(request)
		}
	}
	
	/**
	Dequeue all enqueued requests, applying the given closure to all of them. The queue will be empty by the time the closure is called.
	
	- parameter closure: The closure to apply to each enqueued request
	*/
	public func dequeueAndApply(closure: ((OAuth2DataRequest) -> Void)) {
		guard let enq = enqueued else {
			return
		}
		enqueued = nil
		enq.forEach(closure)
	}
	
	/**
	Uses `dequeueAndApply()` by signing and re-performing all enqueued requests.
	*/
	func retryAll() {
		dequeueAndApply() { req in
			var request = req.request
			do {
				try request.sign(with: oauth2)
				self.perform(request: request, retry: false, callback: req.callback)
			}
			catch let error {
				NSLog("OAuth2.DataLoader.retryAll(): \(error)")
			}
		}
	}
	
	/**
	Uses `dequeueAndApply()` to all enqueued requests, calling their callback with a response representing the given error.
	
	- parameter error: The error with which to finalize all enqueued requests
	*/
	func throwAllAway(with error: OAuth2Error) {
		dequeueAndApply() { req in
			let res = OAuth2Response(data: nil, request: req.request, response: HTTPURLResponse(), error: error)
			req.callback(res)
		}
	}
}

