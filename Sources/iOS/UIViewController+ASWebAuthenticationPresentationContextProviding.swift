//
//  OAuth2WebViewController.swift
//  OAuth2
//
//  Created by Christian Gossain on 12/31/20.
//  Copyright 2014 Pascal Pfiffner
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
#if os(iOS)

import AuthenticationServices
#if !NO_MODULE_IMPORT
import Base
#endif

// This extension provides a global default implementation of the `ASWebAuthenticationPresentationContextProviding` which
// is required to use `ASWebAuthenticationSession`.
extension UIViewController: ASWebAuthenticationPresentationContextProviding {
    @available(iOS 13.0, *)
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}

#endif
