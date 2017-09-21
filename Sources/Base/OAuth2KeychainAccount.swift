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
#if !NO_KEYCHAIN_IMPORT     // needs to be imported when using `swift build`, not when building via Xcode
import SwiftKeychain
#endif


/**
Keychain integration handler for OAuth2.
*/
struct OAuth2KeychainAccount: KeychainGenericPasswordType {
	
	/// The service name to use.
	let serviceName: String
	
	/// The account name to use.
	let accountName: String
	
	/// The keychain access group.
	var accessGroup: String?
	
	/// Data that ends up in the keychain.
	var data = [String: Any]()
	
	/// Keychain access mode.
	let accessMode: String
	
	
	/**
	Designated initializer.
	
	- parameter oauth2:  The OAuth2 instance from which to retrieve settings
	- parameter account: The account name to use
	- parameter data:    Data that we want to store to the keychain
	*/
	init(oauth2: OAuth2Securable, account: String, data inData: [String: Any] = [:]) {
		serviceName = oauth2.keychainServiceName()
		accountName = account
		accessMode = String(oauth2.keychainAccessMode)
		accessGroup = oauth2.keychainAccessGroup
		data = inData
	}
}


extension KeychainGenericPasswordType {
	
	/// Data to store to the keychain.
	var dataToStore: [String: Any] {
		return data
	}
	
	/**
	Attempts to read data from the keychain, will ignore `errSecItemNotFound` but throw others.
	
	- returns: A [String: Any] dictionary of data fetched from the keychain
	*/
	mutating func fetchedFromKeychain() throws -> [String: Any] {
		do {
			try _ = fetchFromKeychain()
			return data
		}
		catch let error where error._domain == "swift.keychain.error" && error._code == Int(errSecItemNotFound) {
			return [:]
		}
	}
}

