//
//  OAuth2+iOS.swift
//  OAuth2
//
//  Created by David Kraus on 11/26/15.
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
#if os(tvOS)

import Foundation
#if !NO_MODULE_IMPORT
import Base
#endif


public final class OAuth2Authorizer: OAuth2AuthorizerUI {
	
	/// The OAuth2 instance this authorizer belongs to.
	public unowned let oauth2: OAuth2Base
	
	
	init(oauth2: OAuth2) {
		self.oauth2 = oauth2
	}
	
	
	// no webview or webbrowser available on tvOS
	
	public func openAuthorizeURLInBrowser(_ url: URL) throws {
		throw OAuth2Error.generic("Not implemented")
	}
	
	public func authorizeEmbedded(with config: OAuth2AuthConfig, at url: URL) throws {
		throw OAuth2Error.generic("Not implemented")
	}
}

#endif
