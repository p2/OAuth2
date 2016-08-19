//
//  OAuth2CodeGrantNoTokenType.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 1/15/16.
//  Copyright 2016 Pascal Pfiffner.
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

#if !NO_MODULE_IMPORT
import Base
#endif


/**
Subclass to deal with sites that don't return `token_type`, such as Instagram or Bitly.
*/
public class OAuth2CodeGrantNoTokenType: OAuth2CodeGrant {
	
	override open func assureCorrectBearerType(_ params: OAuth2JSON) throws {
	}
}
