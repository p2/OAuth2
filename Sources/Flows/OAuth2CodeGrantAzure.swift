//
//  OAuth2CodeGrantAzure.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 2/1/15.
//  Copyright 2016 David Everlöf
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
#endif


/**
Azure requires a `resource`, hence our `init` requires it as well
*/
public class OAuth2CodeGrantAzure: OAuth2CodeGrant {
	
	/**
	Designated initializer.
	
	- parameter settings: The settings for this client
	- parameter resource: The resource we want to use
	*/
	public init(settings: OAuth2JSON, resource: String) {
		super.init(settings: settings)
		clientConfig.secretInBody = true
		clientConfig.customParameters = [
			"resource": resource
		]
	}
}

