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
    
    func insertItemWithAttributes(attributes: [String: AnyObject]) throws
    func removeItemWithAttributes(attributes: [String: AnyObject]) throws
    func fetchItemWithAttributes(attributes: [String: AnyObject]) throws -> [String: AnyObject]?
}

// MARK: - KeychainItemType

public protocol KeychainItemType {
    
    var accessMode: String {get}
    var attributes: [String: AnyObject] {get}
    var data: [String: AnyObject] {get set}
    var dataToStore: [String: AnyObject] {get}
}

extension KeychainItemType {
    
    public var accessMode: String {
        
        return String(kSecAttrAccessibleWhenUnlocked)
    }
}

extension KeychainItemType {
    
    internal var attributesToSave: [String: AnyObject] {
        
        var itemAttributes = attributes
        let archivedData = NSKeyedArchiver.archivedDataWithRootObject(dataToStore)
        
        itemAttributes[String(kSecValueData)] = archivedData
        
        return itemAttributes
    }
    
    internal func dataFromAttributes(attributes: [String: AnyObject]) -> [String: AnyObject]? {
        
        guard let valueData = attributes[String(kSecValueData)] as? NSData else { return nil }
        
        return NSKeyedUnarchiver.unarchiveObjectWithData(valueData) as? [String: AnyObject] ?? nil
    }
    
    internal var attributesForFetch: [String: AnyObject] {
        
        var itemAttributes = attributes
        
        itemAttributes[String(kSecReturnData)] = true
        itemAttributes[String(kSecReturnAttributes)] = true
        
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
    
    public var attributes: [String: AnyObject] {
    
        var attributes = [String: AnyObject]()
        
        attributes[String(kSecClass)] = kSecClassGenericPassword
        attributes[String(kSecAttrAccessible)] = accessMode
        attributes[String(kSecAttrService)] = serviceName
        attributes[String(kSecAttrAccount)] = accountName
        
        return attributes
    }
}

// MARK: - Keychain

public struct Keychain: KeychainServiceType {
    
    internal func errorForStatusCode(statusCode: OSStatus) -> NSError {
        
        return NSError(domain: "swift.keychain.error", code: Int(statusCode), userInfo: nil)
    }
    
    // Inserts or updates a keychain item with attributes
    
    public func insertItemWithAttributes(attributes: [String: AnyObject]) throws {
        
        var statusCode = SecItemAdd(attributes, nil)
        
        if statusCode == errSecDuplicateItem {
            
            SecItemDelete(attributes)
            statusCode = SecItemAdd(attributes, nil)
        }
        
        if statusCode != errSecSuccess {
            
            throw errorForStatusCode(statusCode)
        }
    }
    
    public func removeItemWithAttributes(attributes: [String: AnyObject]) throws {
        
        let statusCode = SecItemDelete(attributes)
        
        if statusCode != errSecSuccess {
            
            throw errorForStatusCode(statusCode)
        }
    }
    
    public func fetchItemWithAttributes(attributes: [String: AnyObject]) throws -> [String: AnyObject]? {
        
        var result: AnyObject?
        
        let statusCode = withUnsafeMutablePointer(&result) { pointer in
            
            SecItemCopyMatching(attributes, UnsafeMutablePointer(pointer))
        }
        
        if statusCode != errSecSuccess {
            
            throw errorForStatusCode(statusCode)
        }
        
        if let result = result as? [String: AnyObject] {
            
            return result
        }
        
        return nil
    }
}

// MARK: - KeychainItemType + Keychain

extension KeychainItemType {
    
    public func saveInKeychain(keychain: KeychainServiceType = Keychain()) throws {
        
        try keychain.insertItemWithAttributes(attributesToSave)
    }
    
    public func removeFromKeychain(keychain: KeychainServiceType = Keychain()) throws {
        
        try keychain.removeItemWithAttributes(attributes)
    }
    
    public mutating func fetchFromKeychain(keychain: KeychainServiceType = Keychain()) throws -> Self {
        
        if  let result = try keychain.fetchItemWithAttributes(attributesForFetch),
            let itemData = dataFromAttributes(result) {
            
            data = itemData
        }
        
        return self
    }
}
