//
//  OAuth2CodeGrantLinkedIn.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 21/12/15.
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


/**
    LinkedIn-specific subclass to deal with LinkedIn peculiarities:
    
    - Must have client-id/secret in request body
    - Must use custom web view in order to be able to intercept http(s) redirects
    - Will **not** return the "token_type" value, so must ignore it not being present
 */
public class OAuth2CodeGrantLinkedIn: OAuth2CodeGrant {
    
	public override init(settings: OAuth2JSON) {
		super.init(settings: settings)
		authConfig.secretInBody = true
		authConfig.authorizeEmbedded = true     // necessary because only http(s) redirects are allowed
		authConfig.ui.useSafariView = false     // must use custom web view in order to be able to intercept http(s) redirects
	}
	
	override func assureCorrectBearerType(params: OAuth2JSON) throws {
	}
}

