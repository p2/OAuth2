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
 import Flows
#endif


/**
A class that makes loading data from a protected endpoint easier.
*/
open class OAuth2DataLoader: OAuth2Requestable {
	
	/// The OAuth2 instance used for OAuth2 access token retrieval.
	public let oauth2: OAuth2
	
	public init(oauth2: OAuth2) {
		self.oauth2 = oauth2
		super.init(logger: oauth2.logger)
	}
	
	
	// MARK: - Make Requests
	
	// TODO: working on this beast
	override open func perform(request: URLRequest, callback: @escaping ((Void) throws -> (Data, Int)) -> Void) {
		
	}
}

