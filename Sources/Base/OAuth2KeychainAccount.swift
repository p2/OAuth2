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
Base keychain integration handler for OAuth2.
*/
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

