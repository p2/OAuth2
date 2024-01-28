//
//  Keychain.swift
//  Keychain
//
//  Created by Yanko Dimitrov on 2/6/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation

// MARK: - KeychainServiceType

public protocol KeychainServiceType {
    
    func insertItemWithAttributes(_ attributes: [String: Any]) throws
    func removeItemWithAttributes(_ attributes: [String: Any]) throws
    func fetchItemWithAttributes(_ attributes: [String: Any]) throws -> [String: Any]?
}

// MARK: - KeychainItemType

public protocol KeychainItemType {
    
    var accessMode: String {get}
    var accessGroup: String? {get}
    var attributes: [String: Any] {get}
    var data: [String: Any] {get set}
    var dataToStore: [String: Any] {get}
}

extension KeychainItemType {
    
    public var accessMode: String {
        
        return String(kSecAttrAccessibleWhenUnlocked)
    }
    
    public var accessGroup: String? {
        
        return nil
    }
}

extension KeychainItemType {
    
    internal var attributesToSave: [String: Any] {
        
        var itemAttributes = attributes
        let archivedData = NSKeyedArchiver.archivedData(withRootObject: dataToStore)
        
        itemAttributes[String(kSecValueData)] = archivedData
        
        if let group = accessGroup {
            
            itemAttributes[String(kSecAttrAccessGroup)] = group
        }
        
        return itemAttributes
    }
    
    internal func dataFromAttributes(_ attributes: [String: Any]) -> [String: Any]? {
        
        guard let valueData = attributes[String(kSecValueData)] as? Data else { return nil }
        
        return NSKeyedUnarchiver.unarchiveObject(with: valueData) as? [String: Any] ?? nil
    }
    
    internal var attributesForFetch: [String: Any] {
        
        var itemAttributes = attributes
        
        itemAttributes[String(kSecReturnData)] = kCFBooleanTrue
        itemAttributes[String(kSecReturnAttributes)] = kCFBooleanTrue
        
        if let group = accessGroup {
            
            itemAttributes[String(kSecAttrAccessGroup)] = group
        }
        
        return itemAttributes
    }
}

// MARK: - KeychainGenericPasswordType

public protocol KeychainGenericPasswordType: KeychainItemType {
    
    var serviceName: String {get}
    var accountName: String {get}
}

extension KeychainGenericPasswordType {
    
    public var serviceName: String {
        
        return "swift.keychain.service"
    }
    
    public var attributes: [String: Any] {
    
        var attributes = [String: Any]()
        
        attributes[String(kSecClass)] = kSecClassGenericPassword
        attributes[String(kSecAttrAccessible)] = accessMode
        attributes[String(kSecAttrService)] = serviceName
        attributes[String(kSecAttrAccount)] = accountName
        
        return attributes
    }
}

// MARK: - Keychain

public struct Keychain: KeychainServiceType {
    
    // Default initializer
    
    public init() {}
    
    internal func errorForStatusCode(_ statusCode: OSStatus) -> NSError {
        
        return NSError(domain: "swift.keychain.error", code: Int(statusCode), userInfo: nil)
    }
    
    // Inserts or updates a keychain item with attributes
    
    public func insertItemWithAttributes(_ attributes: [String: Any]) throws {
        
        var statusCode = SecItemAdd(attributes as CFDictionary, nil)
        
        if statusCode == errSecDuplicateItem {
            
            SecItemDelete(attributes as CFDictionary)
            statusCode = SecItemAdd(attributes as CFDictionary, nil)
        }
        
        if statusCode != errSecSuccess {
            
            throw errorForStatusCode(statusCode)
        }
    }
    
    public func removeItemWithAttributes(_ attributes: [String: Any]) throws {
        
        let statusCode = SecItemDelete(attributes as CFDictionary)
        
        if statusCode != errSecSuccess {
            
            throw errorForStatusCode(statusCode)
        }
    }
    
    public func fetchItemWithAttributes(_ attributes: [String: Any]) throws -> [String: Any]? {
        
        var result: AnyObject?
        
        let statusCode = SecItemCopyMatching(attributes as CFDictionary, &result)
        
        if statusCode != errSecSuccess {
            
            throw errorForStatusCode(statusCode)
        }
        
        if let result = result as? [String: Any] {
            
            return result
        }
        
        return nil
    }
}

// MARK: - KeychainItemType + Keychain

extension KeychainItemType {
    
    public func saveInKeychain(_ keychain: KeychainServiceType = Keychain()) throws {
        
        try keychain.insertItemWithAttributes(attributesToSave)
    }
    
    public func removeFromKeychain(_ keychain: KeychainServiceType = Keychain()) throws {
        
        try keychain.removeItemWithAttributes(attributes)
    }
    
    public mutating func fetchFromKeychain(_ keychain: KeychainServiceType = Keychain()) throws -> Self {
        
        if  let result = try keychain.fetchItemWithAttributes(attributesForFetch),
            let itemData = dataFromAttributes(result) {
            
            data = itemData
        }
        
        return self
    }
}

