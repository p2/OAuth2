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

import XCTest
import OAuth2


class OAuth2Tests: XCTestCase {
	
	func genericOAuth2() -> OAuth2 {
		return OAuth2(settings: [
			"client_id": "abc",
			"authorize_uri": "https://auth.ful.io",
			"scope": "login",
			"verbose": true
		])
	}
	
	func testInit() {
		//var oauth = OAuth2(settings: NSDictionary())		// TODO: how to test that this raises?
		
		var oauth = OAuth2(settings: ["client_id": "def"])
		XCTAssertFalse(oauth.verbose, "Non-verbose by default")
		XCTAssertEqual(oauth.clientId, "def", "Must init `client_id`")
		
		let oa = self.genericOAuth2()
		XCTAssertEqual(oa.authURL!, NSURL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertEqual(oa.scope!, "login", "Must init `scope`")
		XCTAssertTrue(oa.verbose, "Must init `verbose`")
	}
	
	func testAuthorizeURL() {
		let oa = genericOAuth2()
		let auth = oa.authorizeURL(oa.authURL!, redirect: "oauth2app://callback", scope: "launch", responseType: "code", params: nil)
		
		let comp = NSURLComponents(URL: auth, resolvingAgainstBaseURL: true)!
		XCTAssertEqual("https", comp.scheme!, "Need correct scheme")
		XCTAssertEqual("auth.ful.io", comp.host!, "Need correct host")
		
		let params = OAuth2.paramsFromQuery(comp.query!)
		XCTAssertEqual(params["redirect_uri"]!, "oauth2app://callback", "Expecting `` in query")
		XCTAssertEqual(params["scope"]!, "launch", "Expecting `scope` in query")
//		XCTAssertTrue(String(params["state"] as String).utf16count > 0, "Expecting `state` in query")
	}
	
	func testQueryParamParsing() {
		let params = OAuth2.paramsFromQuery("access_token=xxx&expires=2015-00-00&more=stuff")
		XCTAssert(3 == countElements(params), "Expecting 3 URL params")
		
		XCTAssertEqual(params["access_token"]!, "xxx")
		XCTAssertEqual(params["expires"]!, "2015-00-00")
		XCTAssertEqual(params["more"]!, "stuff")
	}
	
	func testQueryParamConversion() {
		let qry = OAuth2.queryStringFor(["a": "AA", "b": "BB", "x": "yz"])
		XCTAssertEqual(14, countElements(qry), "Expecting a 14 character string")
		
		let dict = OAuth2.paramsFromQuery(qry)
		XCTAssertEqual(dict["a"]!, "AA", "Must unpack `a`")
		XCTAssertEqual(dict["b"]!, "BB", "Must unpack `b`")
		XCTAssertEqual(dict["x"]!, "yz", "Must unpack `x`")
	}
	
	func testQueryParamEncoding() {
		let qry = OAuth2.queryStringFor(["uri": "https://api.io", "str": "a string: cool!", "num": "3.14159"])
		XCTAssertEqual(60, countElements(qry), "Expecting a 60 character string")
		
		let dict = OAuth2.paramsFromQuery(qry)
		XCTAssertEqual(dict["uri"]!, "https%3A%2F%2Fapi.io", "Must unpack `uri`")
		XCTAssertEqual(dict["str"]!, "a+string%3A+cool%21", "Must unpack `str`")
		XCTAssertEqual(dict["num"]!, "3.14159", "Must unpack `num`")
	}
}
