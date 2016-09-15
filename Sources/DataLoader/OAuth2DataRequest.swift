//
//  OAuth2DataRequest.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 8/31/16.
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
#if !NO_MODULE_IMPORT
import Base
import Flows
#endif


/**
A struct encapsulating an OAuth2 request made to obtain data.
*/
public struct OAuth2DataRequest {
	
	/// The URLRequest to be executed.
	public let request: URLRequest
	
	/// The callback executed when the request is done.
	public let callback: (OAuth2Response) -> Void
	
	/// Any context to associate with the request.
	public var context: Any? = nil
	
	
	/** The one initializer. */
	public init(request: URLRequest, callback: @escaping (OAuth2Response) -> Void) {
		self.request = request
		self.callback = callback
	}
}

