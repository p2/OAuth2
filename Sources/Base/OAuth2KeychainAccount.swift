//
//  OAuth2KeychainAccount.swift
//  OAuth2
//
//  Created by David Kraus on 09/03/16.
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
#if !NO_KEYCHAIN_IMPORT     // needs to be imported when using `swift build` or with CocoaPods, not when building via Xcode
import SwiftKeychain
#endif


/// We store the client's credentials (id and secret) under this keychain key name.
let OAuth2KeychainCredentialsKey = "clientCredentials"

/// We store the current tokens under this keychain key name.
let OAuth2KeychainTokenKey = "currentTokens"


/**
Keychain integration handler for OAuth2.
*/
struct OAuth2KeychainAccount: KeychainGenericPasswordType {
	
	let serviceName: String
	
	let accountName: String
	
	var data = [String: AnyObject]()
	
	let accessMode: String
	
	
	init(oauth2: OAuth2Base, account: String, data inData: [String: AnyObject] = [:]) {
		serviceName = oauth2.keychainServiceName()
		accountName = account
		accessMode = String(oauth2.keychainAccessMode)
		data = inData
	}
}


extension KeychainGenericPasswordType {
	
	var dataToStore: [String: AnyObject] {
		return data
	}
	
	/**
	Attempts to read data from the keychain, will ignore `errSecItemNotFound` but throw others.
	*/
	mutating func fetchedFromKeychain() throws -> [String: NSCoding] {
		do {
			try fetchFromKeychain()
			if let creds_data = data as? [String: NSCoding] {
				return creds_data
			}
			throw OAuth2Error.Generic("Keychain data for \(serviceName) > \(accountName) is in wrong format. Got: “\(data)”")
		}
		catch let error as NSError where error.domain == "swift.keychain.error" && error.code == Int(errSecItemNotFound) {
			return [:]
		}
	}
}

