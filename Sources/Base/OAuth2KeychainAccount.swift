//
//  OAuth2KeychainAccount.swift
//  OAuth2
//
//  Created by David Kraus on 09/03/16.
//  Copyright © 2016 Pascal Pfiffner. All rights reserved.
//

import Foundation
#if IMPORT_SWIFT_KEYCHAIN       // experimental for SwiftKeychain integration via CocoaPods (iOS only)
    import SwiftKeychain
#elseif !NO_KEYCHAIN_IMPORT     // needs to be imported when using `swift build`, not when building via Xcode
    import SwiftKeychain
#endif

struct OAuth2KeychainAccount: KeychainGenericPasswordType {
    let accountName: String
    let internalServiceName: String
    
    var data = [String: AnyObject]()
    
    var dataToStore: [String: AnyObject] {
        return data
    }
    
    var serviceName: String {
        return internalServiceName
    }
    
    init(serviceName: String, name: String, data: [String: AnyObject] = [:]) {
        self.internalServiceName = serviceName
        self.accountName = name
        self.data = data
    }
}