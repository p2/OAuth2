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


/**
Keychain integration handler for OAuth2.
*/
struct OAuth2KeychainAccount: KeychainGenericPasswordType {
	
	/// The service name to use.
	let serviceName: String
	
	/// The account name to use.
	let accountName: String
	
	/// Data that ends up in the keychain.
	var data = [String: Any]()
	
	/// Keychain access mode.
	let accessMode: String
	
	
	init(oauth2: OAuth2Backing, account: String, data inData: [String: Any] = [:]) {
		serviceName = oauth2.keychainServiceName()
		accountName = account
		accessMode = String(oauth2.keychainAccessMode)
		data = inData
	}
}


extension KeychainGenericPasswordType {
	
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
		catch let error as NSError where error.domain == "swift.keychain.error" && error.code == Int(errSecItemNotFound) {
			return [:]
		}
	}
}

