//
//  OAuth2_Tests.swift
//  OAuth2 Tests
//
//  Created by Pascal Pfiffner on 6/6/14.
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

#if os(OSX)
import Cocoa
#endif
import XCTest

@testable
import OAuth2


class OAuth2Tests: XCTestCase {
	
	func genericOAuth2() -> OAuth2 {
		return OAuth2(settings: [
			"client_id": "abc",
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
			"scope": "login",
			"verbose": true,
			"keychain": false,
		])
	}
	
	func testInit() {
		var oauth = OAuth2(settings: ["client_id": "def"])
		XCTAssertFalse(oauth.verbose, "Non-verbose by default")
		XCTAssertEqual(oauth.clientId, "def", "Must init `client_id`")
		
		oauth = genericOAuth2()
		XCTAssertEqual(oauth.authURL, NSURL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertEqual(oauth.scope!, "login", "Must init `scope`")
		XCTAssertTrue(oauth.verbose, "Must init `verbose`")
		XCTAssertFalse(oauth.useKeychain, "Must not use keychain")
	}
	
	func testAuthorizeURL() {
		let oa = genericOAuth2()
		oa.verbose = false
		let auth = try! oa.authorizeURLWithRedirect("oauth2app://callback", scope: "launch", params: nil)
		
		let comp = NSURLComponents(URL: auth, resolvingAgainstBaseURL: true)!
		XCTAssertEqual("https", comp.scheme!, "Need correct scheme")
		XCTAssertEqual("auth.ful.io", comp.host!, "Need correct host")
		
		let params = OAuth2.paramsFromQuery(comp.percentEncodedQuery!)
		XCTAssertEqual(params["redirect_uri"]!, "oauth2app://callback", "Expecting correct `redirect_uri` in query")
		XCTAssertEqual(params["scope"]!, "launch", "Expecting `scope` in query")
		XCTAssertNotNil(params["state"], "Expecting `state` in query")
	}
	
	func testTokenURL() {
		let oa = genericOAuth2()
		oa.verbose = false
		let auth = try! oa.authorizeURLWithParams([:], asTokenURL: true)
		
		let comp = NSURLComponents(URL: auth, resolvingAgainstBaseURL: true)!
		XCTAssertEqual("https", comp.scheme!, "Need correct scheme")
		XCTAssertEqual("token.ful.io", comp.host!, "Need correct host")
		
		let params = OAuth2.paramsFromQuery(comp.percentEncodedQuery!)
		//XCTAssertEqual(params["redirect_uri"]!, "oauth2app://callback", "Expecting correct `redirect_uri` in query")
		XCTAssertNil(params["state"], "Expecting no `state` in query")
	}
	
	func testAuthorizeCall() {
		let oa = genericOAuth2()
		oa.verbose = false
		XCTAssertFalse(oa.authConfig.authorizeEmbedded)
		oa.onAuthorize = { params in
			XCTAssertTrue(false, "Should not call success callback")
		}
		oa.onFailure = { error in
			XCTAssertNotNil(error)
			XCTAssertEqual((error as! OAuth2Error), OAuth2Error.NoRedirectURL)
		}
		oa.authorize()
		XCTAssertFalse(oa.authConfig.authorizeEmbedded)
		
		// embedded
		oa.redirect = "myapp://oauth"
		oa.onFailure = { error in
			XCTAssertNotNil(error)
			XCTAssertEqual((error as! OAuth2Error), OAuth2Error.InvalidAuthorizationContext)
		}
		oa.afterAuthorizeOrFailure = { wasFailure, error in
			XCTAssertTrue(wasFailure)
			XCTAssertNotNil(error)
			XCTAssertEqual((error as! OAuth2Error), OAuth2Error.InvalidAuthorizationContext)
		}
		oa.authorizeEmbeddedFrom("A string")
		XCTAssertTrue(oa.authConfig.authorizeEmbedded)
	}
	
	func testQueryParamParsing() {
		let params1 = OAuth2.paramsFromQuery("access_token=xxx&expires=2015-00-00&more=stuff")
		XCTAssert(3 == params1.count, "Expecting 3 URL params")
		
		XCTAssertEqual(params1["access_token"]!, "xxx")
		XCTAssertEqual(params1["expires"]!, "2015-00-00")
		XCTAssertEqual(params1["more"]!, "stuff")
		
		let params2 = OAuth2.paramsFromQuery("access_token=x%26x&expires=2015-00-00&more=spacey%20stuff")
		XCTAssert(3 == params1.count, "Expecting 3 URL params")
		
		XCTAssertEqual(params2["access_token"]!, "x&x")
		XCTAssertEqual(params2["expires"]!, "2015-00-00")
		XCTAssertEqual(params2["more"]!, "spacey stuff")
		
		let params3 = OAuth2.paramsFromQuery("access_token=xxx%3D%3D&expires=2015-00-00&more=spacey+stuff+with+a+%2B")
		XCTAssert(3 == params1.count, "Expecting 3 URL params")
		
		XCTAssertEqual(params3["access_token"]!, "xxx==")
		XCTAssertEqual(params3["expires"]!, "2015-00-00")
		XCTAssertEqual(params3["more"]!, "spacey stuff with a +")
	}
	
	func testQueryParamConversion() {
		let qry = OAuth2.queryStringFor(["a": "AA", "b": "BB", "x": "yz"])
		XCTAssertEqual(14, qry.characters.count, "Expecting a 14 character string")
		
		let dict = OAuth2.paramsFromQuery(qry)
		XCTAssertEqual(dict["a"]!, "AA", "Must unpack `a`")
		XCTAssertEqual(dict["b"]!, "BB", "Must unpack `b`")
		XCTAssertEqual(dict["x"]!, "yz", "Must unpack `x`")
	}
	
	func testQueryParamEncoding() {
		let qry = OAuth2.queryStringFor(["uri": "https://api.io", "str": "a string: cool!", "num": "3.14159"])
		XCTAssertEqual(60, qry.characters.count, "Expecting a 60 character string")
		
		let dict = OAuth2.paramsFromQuery(qry)
		XCTAssertEqual(dict["uri"]!, "https://api.io", "Must correctly unpack `uri`")
		XCTAssertEqual(dict["str"]!, "a string: cool!", "Must correctly unpack `str`")
		XCTAssertEqual(dict["num"]!, "3.14159", "Must correctly unpack `num`")
	}
	
	func testSessionConfiguration() {
		let oauth = OAuth2(settings: [:])
		XCTAssertEqual(NSURLSession.sharedSession(), oauth.session, "Expecting default session by default")
		
		// custom configuration
		oauth.sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
		oauth.sessionConfiguration?.timeoutIntervalForRequest = 5.0
		XCTAssertEqual(5, oauth.session.configuration.timeoutIntervalForRequest)
		
		// custom delegate
		oauth.sessionDelegate = SessDelegate()
		XCTAssertTrue(oauth.sessionDelegate === oauth.session.delegate)
		XCTAssertEqual(5, oauth.session.configuration.timeoutIntervalForRequest)
	}
	
	class SessDelegate: NSObject, NSURLSessionDelegate {
	}
}

