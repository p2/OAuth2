//
//  OAuth2ImplicitGrant_tests.swift
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
import OAuth2


class OAuth2ImplicitGrantTests: XCTestCase
{
	func testInit() {
		//var oauth = OAuth2(settings: NSDictionary())		// TODO: how to test that this raises?
		
		let oauth = OAuth2ImplicitGrant(settings: [
			"client_id": "abc",
			"verbose": true,
			"keychain": false,
			"authorize_uri": "https://auth.ful.io",
		])
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertTrue(oauth.verbose, "Set to verbose")
		XCTAssertNil(oauth.scope, "Empty scope")
		
		XCTAssertEqual(oauth.authURL, NSURL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
	}
	
	func testReturnURLHandling() {
		let oauth = OAuth2ImplicitGrant(settings: [
			"client_id": "abc",
			"authorize_uri": "https://auth.ful.io",
			"state_for_testing": "ONSTUH",
			"keychain": false,
		])
		
		// Empty URL
		oauth.onFailure = { error in
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error!.code, OAuth2Error.PrerequisiteFailed.rawValue)
		}
		oauth.afterAuthorizeOrFailure = { wasFailure, error in
			XCTAssertTrue(wasFailure)
			XCTAssertNotNil(error, "Error message expected")
		}
		oauth.handleRedirectURL(NSURL(string: "")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// No params in URL
		oauth.onFailure = { error in
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error!.code, OAuth2Error.PrerequisiteFailed.rawValue)
		}
		oauth.handleRedirectURL(NSURL(string: "https://auth.ful.io")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// standard error
		oauth.onFailure = { error in
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error!.code, OAuth2Error.AuthorizationError.rawValue)
			XCTAssertEqual(error!.localizedDescription, "The resource owner or authorization server denied the request.")
		}
		oauth.handleRedirectURL(NSURL(string: "https://auth.ful.io#error=access_denied")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// explicit error
		oauth.onFailure = { error in
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error!.code, OAuth2Error.AuthorizationError.rawValue)
			XCTAssertEqual(error!.localizedDescription, "Not good")
		}
		oauth.handleRedirectURL(NSURL(string: "https://auth.ful.io#error_description=Not+good")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// no token type
		oauth.onFailure = { error in
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error!.code, OAuth2Error.PrerequisiteFailed.rawValue)
		}
		oauth.handleRedirectURL(NSURL(string: "https://auth.ful.io#access_token=abc&state=\(oauth.state)")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// unsupported token type
		oauth.onFailure = { error in
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error!.code, OAuth2Error.Unsupported.rawValue)
		}
		oauth.handleRedirectURL(NSURL(string: "https://auth.ful.io#token_type=helicopter&access_token=abc&state=\(oauth.state)")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// Invalid state
		oauth.onFailure = { error in
			XCTAssertNotNil(error, "Error message expected")
			XCTAssertEqual(error!.code, OAuth2Error.InvalidState.rawValue)
		}
		oauth.handleRedirectURL(NSURL(string: "https://auth.ful.io#token_type=bearer&access_token=abc&state=ONSTOH")!)
		XCTAssertNil(oauth.accessToken, "Must not have an access token")
		
		// success 1
		oauth.onFailure = { error in
			XCTAssertTrue(false, "Should not call this")
		}
		oauth.afterAuthorizeOrFailure = { wasFailure, error in
			XCTAssertFalse(wasFailure)
			XCTAssertNil(error, "No error message expected")
		}
		oauth.handleRedirectURL(NSURL(string: "https://auth.ful.io#token_type=bearer&access_token=abc&state=\(oauth.state)&expires_in=3599")!)
		XCTAssertNotNil(oauth.accessToken, "Must have an access token")
		XCTAssertEqual(oauth.accessToken!, "abc")
		XCTAssertNotNil(oauth.accessTokenExpiry)
		XCTAssertTrue(oauth.hasUnexpiredAccessToken())
		
		// success 2
		oauth.onFailure = { error in
			XCTAssertTrue(false, "Should not call this")
		}
		oauth.handleRedirectURL(NSURL(string: "https://auth.ful.io#token_type=bearer&access_token=abc&state=\(oauth.state)")!)
		XCTAssertNotNil(oauth.accessToken, "Must have an access token")
		XCTAssertEqual(oauth.accessToken!, "abc")
		XCTAssertNil(oauth.accessTokenExpiry)
		XCTAssertTrue(oauth.hasUnexpiredAccessToken())
	}
}
