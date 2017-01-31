//
//  OAuth2ImplicitGrantTests.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 2/12/15.
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

import XCTest

#if !NO_MODULE_IMPORT
@testable
import Base
@testable
import Flows
#else
@testable
import OAuth2
#endif


class OAuth2ImplicitGrantTests: XCTestCase
{
	func testInit() {
		let oauth = OAuth2ImplicitGrant(settings: [
			"client_id": "abc",
			"keychain": false,
			"authorize_uri": "https://auth.ful.io",
		])
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertNil(oauth.scope, "Empty scope")
		
		XCTAssertEqual(oauth.authURL, URL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
	}
	
	func testReturnURLHandling() {
		let oauth = OAuth2ImplicitGrant(settings: [
			"client_id": "abc",
			"authorize_uri": "https://auth.ful.io",
			"keychain": false,
		])
		
		// Empty redirect URL
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNil(authParameters, "Nil auth dict expected")
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error, OAuth2Error.invalidRedirectURL("file:///"))
		}
		oauth.afterAuthorizeOrFail = { authParameters, error in
			XCTAssertNil(authParameters, "Nil auth dict expected")
			XCTAssertNotNil(error, "Error message expected")
		}
		oauth.context._state = "ONSTUH"
		oauth.handleRedirectURL(URL(string: "file:///")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// No params in redirect URL
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNil(authParameters, "Nil auth dict expected")
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error, OAuth2Error.invalidRedirectURL("https://auth.ful.io"))
		}
		oauth.handleRedirectURL(URL(string: "https://auth.ful.io")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// standard error
		oauth.context._state = "ONSTUH"		// because it has been reset
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNil(authParameters, "Nil auth dict expected")
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error, OAuth2Error.accessDenied)
			XCTAssertEqual(error?.description, "The resource owner or authorization server denied the request.")
		}
		oauth.handleRedirectURL(URL(string: "https://auth.ful.io#error=access_denied")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// explicit error
		oauth.context._state = "ONSTUH"		// because it has been reset
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNil(authParameters, "Nil auth dict expected")
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertNotEqual(error, OAuth2Error.generic("Not good"))
			XCTAssertEqual(error, OAuth2Error.responseError("Not good"))
			XCTAssertEqual(error?.description, "Not good")
		}
		oauth.handleRedirectURL(URL(string: "https://auth.ful.io#error_description=Not+good")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// no token type
		oauth.context._state = "ONSTUH"		// because it has been reset
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNil(authParameters, "Nil auth dict expected")
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error, OAuth2Error.noTokenType)
		}
		oauth.handleRedirectURL(URL(string: "https://auth.ful.io#access_token=abc&state=\(oauth.context.state)")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// unsupported token type
		oauth.context._state = "ONSTUH"		// because it has been reset
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNil(authParameters, "Nil auth dict expected")
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error, OAuth2Error.unsupportedTokenType("Only “bearer” token is supported, but received “helicopter”"))
		}
		oauth.handleRedirectURL(URL(string: "https://auth.ful.io#token_type=helicopter&access_token=abc&state=\(oauth.context.state)")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// Missing state
		oauth.context._state = "ONSTUH"		// because it has been reset
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNil(authParameters, "Nil auth dict expected")
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error, OAuth2Error.missingState)
		}
		oauth.handleRedirectURL(URL(string: "https://auth.ful.io#token_type=bearer&access_token=abc")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// Invalid state
		oauth.context._state = "ONSTUH"		// because it has been reset
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNil(authParameters, "Nil auth dict expected")
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error, OAuth2Error.invalidState)
		}
		oauth.handleRedirectURL(URL(string: "https://auth.ful.io#token_type=bearer&access_token=abc&state=ONSTOH")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// success 1
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNotNil(authParameters, "auth parameters expected")
			XCTAssertNil(error, "No error message expected")
		}
		oauth.afterAuthorizeOrFail = { authParameters, error in
			XCTAssertNotNil(authParameters, "auth parameters expected")
			XCTAssertNil(error, "No error message expected")
		}
		oauth.handleRedirectURL(URL(string: "https://auth.ful.io#token_type=bearer&access_token=abc&state=\(oauth.context.state)&expires_in=3599")!)
		XCTAssertNotNil(oauth.accessToken, "Must have an access token")
		XCTAssertEqual(oauth.accessToken!, "abc")
		XCTAssertNotNil(oauth.accessTokenExpiry)
		XCTAssertTrue(oauth.hasUnexpiredAccessToken())
		
		// success 2
		oauth.didAuthorizeOrFail = { authParameters, error in
			XCTAssertNotNil(authParameters, "auth parameters expected")
			XCTAssertNil(error, "No error message expected")
		}
		oauth.handleRedirectURL(URL(string: "https://auth.ful.io#token_type=bearer&access_token=abc&state=\(oauth.context.state)")!)
		XCTAssertNotNil(oauth.accessToken, "Must have an access token")
		XCTAssertEqual(oauth.accessToken!, "abc")
		XCTAssertNil(oauth.accessTokenExpiry)
		XCTAssertTrue(oauth.hasUnexpiredAccessToken())
	}
}

