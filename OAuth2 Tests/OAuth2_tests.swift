//
//  OAuth2_Tests.swift
//  OAuth2 Tests
//
//  Created by Pascal Pfiffner on 6/6/14.
//  Copyright (c) 2014 Pascal Pfiffner. All rights reserved.
//

import XCTest
import OAuth2


class OAuth2Tests: XCTestCase {
	
	func genericOAuth2() -> OAuth2 {
		return OAuth2(settings: [
			"client_id": "abc",
			"api_uri": "https://api.ful.io",
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
		XCTAssertEqual(oa.apiURL!, NSURL(string: "https://api.ful.io"), "Must init `api_uri`")
		XCTAssertEqual(oa.authURL!, NSURL(string: "https://auth.ful.io"), "Must init `authorize_uri`")
		XCTAssertEqual(oa.scope!, "login", "Must init `scope`")
		XCTAssertTrue(oa.verbose, "Must init `verbose`")
	}
	
	func testAuthorizeURL() {
		let oa = genericOAuth2()
		let auth = oa.authorizeURL(oa.authURL!, redirect: "oauth2app://callback", scope: "launch", responseType: "code", params: nil)
		
		let comp = NSURLComponents(URL: auth, resolvingAgainstBaseURL: true)
		XCTAssertEqual("https", comp.scheme!, "Need correct scheme")
		XCTAssertEqual("auth.ful.io", comp.host!, "Need correct host")
		
		let params = OAuth2.paramsFromQuery(comp.query)
		XCTAssertEqual(params["redirect_uri"]!, "oauth2app://callback", "Expecting `` in query")
		XCTAssertEqual(params["scope"]!, "launch", "Expecting `scope` in query")
//		XCTAssertTrue(String(params["state"] as String).utf16count > 0, "Expecting `state` in query")
	}
	
	func testQueryParamConversion() {
		let qry = OAuth2.queryStringFor(["a": "AA", "b": "BB", "x": "yz"])
		XCTAssertTrue(14 == countElements(qry), "Expecting a 14 character string")
		
		let dict = OAuth2.paramsFromQuery(qry)
		XCTAssertEqual(dict["a"]!, "AA", "Must unpack `a`")
		XCTAssertEqual(dict["b"]!, "BB", "Must unpack `b`")
		XCTAssertEqual(dict["x"]!, "yz", "Must unpack `x`")
	}
}
