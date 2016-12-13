//
//  OAuth2RequestPerformer.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 9/12/16.
//  Copyright © 2016 Pascal Pfiffner. All rights reserved.
//

import Foundation


/**
Protocol for types that can perform `URLRequest`s.

The class `OAuth2DataTaskRequestPerformer` implements this protocol and is by default used by all `OAuth2` classes to perform requests.
*/
public protocol OAuth2RequestPerformer {
	
	/**
	This method should start executing the given request, returning a URLSessionTask if it chooses to do so. **You do not neet to call
	`resume()` on this task**, it's supposed to already have started. It is being returned so you may be able to do additional stuff.
	
	- parameter request: An URLRequest object that provides the URL, cache policy, request type, body data or body stream, and so on.
	- parameter completionHandler: The completion handler to call when the load request is complete.
	- returns: An already running session task
	*/
	func perform(request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionTask?
}


/**
Simple implementation of `OAuth2RequestPerformer`, using `URLSession.dataTask()` to perform requests.
*/
open class OAuth2DataTaskRequestPerformer: OAuth2RequestPerformer {
	
	/// The URLSession that should be used.
	public var session: URLSession
	
	
	/**
	Designated initializer.
	*/
	public init(session: URLSession) {
		self.session = session
	}
	
	/**
	This method should start executing the given request, returning a URLSessionTask if it chooses to do so. **You do not neet to call
	`resume()` on this task**, it's supposed to already have started. It is being returned so you may be able to do additional stuff.
	
	- parameter request: An URLRequest object that provides the URL, cache policy, request type, body data or body stream, and so on.
	- parameter completionHandler: The completion handler to call when the load request is complete.
	- returns: An already running session data task
	*/
	@discardableResult
	open func perform(request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionTask? {
		let task = session.dataTask(with: request, completionHandler: completionHandler)
		task.resume()
		return task
	}
}

