//
//  OAuth2Tests.swift
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
		XCTAssertEqual(oauth.authURL, URL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertEqual(oauth.scope!, "login", "Must init `scope`")
		XCTAssertTrue(oauth.verbose, "Must init `verbose`")
		XCTAssertFalse(oauth.useKeychain, "Must not use keychain")
	}
	
	func testAuthorizeURL() {
		let oa = genericOAuth2()
		oa.verbose = false
		let auth = try! oa.authorizeURL(withRedirect: "oauth2app://callback", scope: "launch", params: ["extra": "param"])
		
		let comp = URLComponents(url: auth, resolvingAgainstBaseURL: true)!
		XCTAssertEqual("https", comp.scheme!, "Need correct scheme")
		XCTAssertEqual("auth.ful.io", comp.host!, "Need correct host")
		
		let params = OAuth2.params(fromQuery: comp.percentEncodedQuery!)
		XCTAssertEqual(params["redirect_uri"]!, "oauth2app://callback", "Expecting correct `redirect_uri` in query")
		XCTAssertEqual(params["scope"]!, "launch", "Expecting `scope` in query")
		XCTAssertNotNil(params["state"], "Expecting `state` in query")
		XCTAssertNotNil(params["extra"], "Expecting `extra` parameter in query")
		XCTAssertEqual("param", params["extra"])
	}
	
	func testTokenRequest() {
		let oa = genericOAuth2()
		oa.verbose = false
		oa.clientConfig.refreshToken = "abc"
		let req = try! oa.tokenRequestForTokenRefresh().asURLRequest(for: oa)
		let auth = req.url!
		
		let comp = URLComponents(url: auth, resolvingAgainstBaseURL: true)!
		XCTAssertEqual("https", comp.scheme!, "Need correct scheme")
		XCTAssertEqual("token.ful.io", comp.host!, "Need correct host")
		
		let params = OAuth2.params(fromQuery: comp.percentEncodedQuery ?? "")
		//XCTAssertEqual(params["redirect_uri"]!, "oauth2app://callback", "Expecting correct `redirect_uri` in query")
		XCTAssertNil(params["state"], "Expecting no `state` in query")
	}
	
	func testAuthorizeCall() {
		let oa = genericOAuth2()
		oa.verbose = false
		XCTAssertFalse(oa.authConfig.authorizeEmbedded)
		oa.authorize() { params, error in
			XCTAssertNil(params, "Should not have auth parameters")
			XCTAssertNotNil(error)
			XCTAssertEqual(error, OAuth2Error.noRedirectURL)
		}
		XCTAssertFalse(oa.authConfig.authorizeEmbedded)
		
		// embedded
		oa.redirect = "myapp://oauth"
		oa.authorizeEmbedded(from: NSString()) { parameters, error in
			XCTAssertNotNil(error)
			XCTAssertEqual(error, OAuth2Error.invalidAuthorizationContext)
		}
		XCTAssertTrue(oa.authConfig.authorizeEmbedded)
	}
	
	func testQueryParamParsing() {
		let params1 = OAuth2.params(fromQuery: "access_token=xxx&expires=2015-00-00&more=stuff")
		XCTAssert(3 == params1.count, "Expecting 3 URL params")
		
		XCTAssertEqual(params1["access_token"]!, "xxx")
		XCTAssertEqual(params1["expires"]!, "2015-00-00")
		XCTAssertEqual(params1["more"]!, "stuff")
		
		let params2 = OAuth2.params(fromQuery: "access_token=x%26x&expires=2015-00-00&more=spacey%20stuff")
		XCTAssert(3 == params1.count, "Expecting 3 URL params")
		
		XCTAssertEqual(params2["access_token"]!, "x&x")
		XCTAssertEqual(params2["expires"]!, "2015-00-00")
		XCTAssertEqual(params2["more"]!, "spacey stuff")
		
		let params3 = OAuth2.params(fromQuery: "access_token=xxx%3D%3D&expires=2015-00-00&more=spacey+stuff+with+a+%2B")
		XCTAssert(3 == params1.count, "Expecting 3 URL params")
		
		XCTAssertEqual(params3["access_token"]!, "xxx==")
		XCTAssertEqual(params3["expires"]!, "2015-00-00")
		XCTAssertEqual(params3["more"]!, "spacey stuff with a +")
	}
	
	func testQueryParamConversion() {
		let qry = OAuth2RequestParams.formEncodedQueryStringFor(["a": "AA", "b": "BB", "x": "yz"])
		XCTAssertEqual(14, qry.characters.count, "Expecting a 14 character string")
		
		let dict = OAuth2.params(fromQuery: qry)
		XCTAssertEqual(dict["a"]!, "AA", "Must unpack `a`")
		XCTAssertEqual(dict["b"]!, "BB", "Must unpack `b`")
		XCTAssertEqual(dict["x"]!, "yz", "Must unpack `x`")
	}
	
	func testQueryParamEncoding() {
		let qry = OAuth2RequestParams.formEncodedQueryStringFor(["uri": "https://api.io", "str": "a string: cool!", "num": "3.14159"])
		XCTAssertEqual(60, qry.characters.count, "Expecting a 60 character string")
		
		let dict = OAuth2.params(fromQuery: qry)
		XCTAssertEqual(dict["uri"]!, "https://api.io", "Must correctly unpack `uri`")
		XCTAssertEqual(dict["str"]!, "a string: cool!", "Must correctly unpack `str`")
		XCTAssertEqual(dict["num"]!, "3.14159", "Must correctly unpack `num`")
	}
	
	func testSessionConfiguration() {
		let oauth = OAuth2(settings: [:])
		XCTAssertEqual(0, oauth.session.configuration.httpCookieStorage?.cookies?.count ?? 0, "Expecting ephemeral session configuration by default")
		
		// custom configuration
		oauth.sessionConfiguration = URLSessionConfiguration.default
		oauth.sessionConfiguration?.timeoutIntervalForRequest = 5.0
		XCTAssertEqual(5, oauth.session.configuration.timeoutIntervalForRequest)
		
		// custom delegate
		oauth.sessionDelegate = SessDelegate()
		XCTAssertTrue(oauth.sessionDelegate === oauth.session.delegate)
		XCTAssertEqual(5, oauth.session.configuration.timeoutIntervalForRequest)
	}
	
	class SessDelegate: NSObject, URLSessionDelegate {
	}
}

