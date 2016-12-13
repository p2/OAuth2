//
//  OAuth2Requestable.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/2/15.
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

import Foundation


/**
Base class to add keychain storage functionality.
*/
open class OAuth2Securable: OAuth2Requestable {
	
	/// Server-side settings, as set upon initialization.
	final let settings: OAuth2JSON
	
	/// If set to `true` (the default) will use system keychain to store tokens. Use `"keychain": bool` in settings.
	public var useKeychain = true {
		didSet {
			if useKeychain {
				updateFromKeychain()
			}
		}
	}
	
	/// The keychain account to use to store tokens. Defaults to "currentTokens".
	open var keychainAccountForTokens = "currentTokens" {
		didSet {
			assert(!keychainAccountForTokens.isEmpty)
			updateFromKeychain()
		}
	}
	
	/// The keychain account name to use to store client credentials. Defaults to "clientCredentials".
	open var keychainAccountForClientCredentials = "clientCredentials" {
		didSet {
			assert(!keychainAccountForClientCredentials.isEmpty)
		}
	}
	
	/// Defaults to `kSecAttrAccessibleWhenUnlocked`. MUST be set via `keychain_access_group` init setting.
	open internal(set) var keychainAccessMode = kSecAttrAccessibleWhenUnlocked
	
	/// Keychain access group, none is set by default. MUST be set via `keychain_access_group` init setting.
	open internal(set) var keychainAccessGroup: String?
	
	
	/**
	Base initializer.
	
	Looks at the `verbose`, `keychain`, `keychain_access_mode`, `keychain_access_group` `keychain_account_for_client_credentials` and `keychain_account_for_tokens`. Everything else is handled by subclasses.
	*/
	public init(settings: OAuth2JSON) {
		self.settings = settings
		
		// keychain settings
		if let accountForClientCredentials = settings["keychain_account_for_client_credentials"] as? String {
			keychainAccountForClientCredentials = accountForClientCredentials
		}
		if let accountForTokens = settings["keychain_account_for_tokens"] as? String {
			keychainAccountForTokens = accountForTokens
		}
		if let keychain = settings["keychain"] as? Bool {
			useKeychain = keychain
		}
		if let accessMode = settings["keychain_access_mode"] as? String {
			keychainAccessMode = accessMode as CFString
		}
		if let accessGroup = settings["keychain_access_group"] as? String {
			keychainAccessGroup = accessGroup
		}
		
		// logging settings
		var verbose = false
		if let verb = settings["verbose"] as? Bool {
			verbose = verb
		}
		super.init(verbose: verbose)
		
		// init from keychain
		if useKeychain {
			updateFromKeychain()
		}
	}
	
	
	// MARK: - Keychain Integration
	
	/** The service key under which to store keychain items. Returns "http://localhost", subclasses override to return the authorize URL. */
	open func keychainServiceName() -> String {
		return "http://localhost"
	}
	
	/** Queries the keychain for tokens stored for the receiver's authorize URL, and updates the token properties accordingly. */
	private func updateFromKeychain() {
		logger?.debug("OAuth2", msg: "Looking for items in keychain")
		
		do {
			var creds = OAuth2KeychainAccount(oauth2: self, account: keychainAccountForClientCredentials)
			let creds_data = try creds.fetchedFromKeychain()
			updateFromKeychainItems(creds_data)
		}
		catch {
			logger?.warn("OAuth2", msg: "Failed to load client credentials from keychain: \(error)")
		}
		
		do {
			var toks = OAuth2KeychainAccount(oauth2: self, account: keychainAccountForTokens)
			let toks_data = try toks.fetchedFromKeychain()
			updateFromKeychainItems(toks_data)
		}
		catch {
			logger?.warn("OAuth2", msg: "Failed to load tokens from keychain: \(error)")
		}
	}
	
	/** Updates instance properties according to the items found in the given dictionary, which was found in the keychain. */
	func updateFromKeychainItems(_ items: [String: Any]) {
	}
	
	/**
	Items that should be stored when storing client credentials.
	
	- returns: A dictionary with `String` keys and `Any` items
	*/
	open func storableCredentialItems() -> [String: Any]? {
		return nil
	}
	
	/** Stores our client credentials in the keychain. */
	open func storeClientToKeychain() {
		if let items = storableCredentialItems() {
			logger?.debug("OAuth2", msg: "Storing client credentials to keychain")
			let keychain = OAuth2KeychainAccount(oauth2: self, account: keychainAccountForClientCredentials, data: items)
			do {
				try keychain.saveInKeychain()
			}
			catch {
				logger?.warn("OAuth2", msg: "Failed to store client credentials to keychain: \(error)")
			}
		}
	}
	
	/**
	Items that should be stored when tokens are stored to the keychain.
	
	- returns: A dictionary with `String` keys and `Any` items
	*/
	open func storableTokenItems() -> [String: Any]? {
		return nil
	}
	
	/** Stores our current token(s) in the keychain. */
	public func storeTokensToKeychain() {
		if let items = storableTokenItems() {
			logger?.debug("OAuth2", msg: "Storing tokens to keychain")
			let keychain = OAuth2KeychainAccount(oauth2: self, account: keychainAccountForTokens, data: items)
			do {
				try keychain.saveInKeychain()
			}
			catch let error {
				logger?.warn("OAuth2", msg: "Failed to store tokens to keychain: \(error)")
			}
		}
	}
	
	/** Unsets the client credentials and deletes them from the keychain. */
	open func forgetClient() {
		logger?.debug("OAuth2", msg: "Forgetting client credentials and removing them from keychain")
		let keychain = OAuth2KeychainAccount(oauth2: self, account: keychainAccountForClientCredentials)
		do {
			try keychain.removeFromKeychain()
		}
		catch {
			logger?.warn("OAuth2", msg: "Failed to delete credentials from keychain: \(error)")
		}
	}
	
	/** Unsets the tokens and deletes them from the keychain. */
	open func forgetTokens() {
		logger?.debug("OAuth2", msg: "Forgetting tokens and removing them from keychain")

		let keychain = OAuth2KeychainAccount(oauth2: self, account: keychainAccountForTokens)
		do {
			try keychain.removeFromKeychain()
		}
		catch {
			logger?.warn("OAuth2", msg: "Failed to delete tokens from keychain: \(error)")
		}
	}
}

