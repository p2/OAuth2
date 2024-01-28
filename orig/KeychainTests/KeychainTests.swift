//
//  KeychainTests.swift
//  KeychainTests
//
//  Created by Yanko Dimitrov on 2/6/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import XCTest
@testable import Keychain

class KeychainTests: XCTestCase {
    
    func testErrorForStatusCode() {
        
        let keychain = Keychain()
        
        let expectedErrorCode = Int(errSecItemNotFound)
        let error = keychain.errorForStatusCode(errSecItemNotFound)
        
        XCTAssertEqual(error.code, expectedErrorCode, "Should return error with status code")
    }
    
    func testInsertItemWithAttributes() {
        
        let item = MockGenericPasswordItem(accountName: "John")
        let keychain = Keychain()
        var hasError = false
        
        do {
            
            try keychain.insertItemWithAttributes(item.attributes)
        
        } catch {
            
            hasError = true
        }
        
        XCTAssertEqual(hasError, false, "Should insert item with attributes in the Keychain")
    }
    
    func testInsertItemWithAttributesThrowsError() {
        
        let attributes = ["a": "b"]
        let keychain = Keychain()
        var hasError = false
        
        do {
            
            try keychain.insertItemWithAttributes(attributes)
            
        } catch {
            
            hasError = true
        }
        
        XCTAssertEqual(hasError, true, "Should throw error when the operation fails")
    }
    
    func testRemoveItemWithAttributes() {
        
        let item = MockGenericPasswordItem(accountName: "John")
        let keychain = Keychain()
        var hasError = false
        
        try! keychain.insertItemWithAttributes(item.attributes)
        
        do {
        
            try keychain.removeItemWithAttributes(item.attributes)
        
        } catch {
            
            hasError = true
        }
        
        XCTAssertEqual(hasError, false, "Should remove item with attributes from the Keychain")
    }
    
    func testRemoveItemWithAttributesThrowsError() {
        
        let attributes = ["a": "b"]
        let keychain = Keychain()
        var hasError = false
        
        do {
            
            try keychain.removeItemWithAttributes(attributes)
            
        } catch {
            
            hasError = true
        }
        
        XCTAssertEqual(hasError, true, "Should throw error when the operation fails")
    }
    
    func testFetchItemWithAttributes() {
        
        let item = MockGenericPasswordItem(accountName: "John")
        let keychain = Keychain()
        var hasError = false
        var fetchedToken = ""
        
        try! keychain.insertItemWithAttributes(item.attributesToSave)
        
        do {
            
            if let fetchedItem = try keychain.fetchItemWithAttributes(item.attributesForFetch) {
                
                if let data = item.dataFromAttributes(fetchedItem) {
                
                    fetchedToken = data["token"] as? String ?? ""
                }
            }
            
        } catch {
            
            hasError = true
        }
        
        XCTAssertEqual(hasError, false, "Should fetch the keychain item from the Keychain")
        XCTAssertEqual(fetchedToken, "123456", "Should return the keychain item data")
    }
    
    func testFetchItemWithAttributesThrowsError() {
        
        let attributes = ["a": "b"]
        let keychain = Keychain()
        var hasError = false
        
        do {
            
            _ = try keychain.fetchItemWithAttributes(attributes)
            
        } catch {
            
            hasError = true
        }
        
        XCTAssertEqual(hasError, true, "Should throw error when the operation fails")
    }
    
    func testFetchItemWithAttributesReturnsNilIfResultIsNotADictionary() {
        
        let item = MockGenericPasswordItem(accountName: "John")
        let keychain = Keychain()
        
        try! keychain.insertItemWithAttributes(item.attributes)
        
        let result = try! keychain.fetchItemWithAttributes(item.attributes)
        
        XCTAssertNil(result, "Should return nil if the result is not a dictionary")
    }
}
