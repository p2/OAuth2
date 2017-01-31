//
//  OAuth2AuthRequestTests.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 18/03/16.
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


class OAuth2AuthRequestTests: XCTestCase {
	
	func testMethod() {
		let url = URL(string: "http://localhost")!
		let req1 = OAuth2AuthRequest(url: url)
		XCTAssertTrue(req1.method == .POST)
		let req2 = OAuth2AuthRequest(url: url, method: .POST)
		XCTAssertTrue(req2.method == .POST)
		let req3 = OAuth2AuthRequest(url: url, method: .GET)
		XCTAssertTrue(req3.method == .GET)
	}
	
	func testContentType() {
		let url = URL(string: "http://localhost")!
		let req = OAuth2AuthRequest(url: url)
		XCTAssertTrue(req.contentType == .wwwForm)
		XCTAssertEqual("application/x-www-form-urlencoded; charset=utf-8", req.contentType.rawValue)
		
		req.contentType = .json
		XCTAssertTrue(req.contentType == .json)
		XCTAssertEqual("application/json", req.contentType.rawValue)
	}
	
	func testHeaders() {
		let url = URL(string: "http://localhost")!
		let req = OAuth2AuthRequest(url: url)
		XCTAssertTrue(0 == req.params.count)
		XCTAssertNil(req.headers)
		
		req.set(header: "Authorize", to: "Basic abc==")
		XCTAssertEqual(1, req.headers?.count)
	}
	
	func testParams() {
		let url = URL(string: "http://localhost")!
		let req = OAuth2AuthRequest(url: url)
		XCTAssertTrue(0 == req.params.count)
		
		req.params["a"] = "A"
		XCTAssertTrue(1 == req.params.count)
		req.add(params: ["a": "AA", "b": "B"])
		XCTAssertTrue(2 == req.params.count)
		XCTAssertEqual("AA", req.params["a"])
		
		req.params["c"] = "A complicated/surprising name & character=fun"
		req.params.removeValue(forKey: "b")
		XCTAssertTrue(2 == req.params.count)
		let str = req.params.percentEncodedQueryString()
		XCTAssertEqual("a=AA&c=A+complicated%2Fsurprising+name+%26+character%3Dfun", str)
	}
	
	func testURLComponents() {
		let reqNoTLS = OAuth2AuthRequest(url: URL(string: "http://not.tls.com")!)
		do {
			_ = try reqNoTLS.asURLComponents()
			XCTAssertTrue(false, "Must no longer be here, must throw because we're not using TLS")
		}
		catch OAuth2Error.notUsingTLS {
		}
		catch let error {
			XCTAssertTrue(false, "Must throw “.notUsingTLS” but threw \(error)")
		}
		
		let reqP = OAuth2AuthRequest(url: URL(string: "https://auth.io")!)
		reqP.params["a"] = "A"
		do {
			let comp = try reqP.asURLComponents()
			XCTAssertEqual("auth.io", comp.host)
			XCTAssertNil(comp.query, "Must not add params to URL for POST")
			XCTAssertNil(comp.percentEncodedQuery, "Must not add params to URL for POST")
		}
		catch let error {
			XCTAssertTrue(false, "Must not throw but threw \(error)")
		}
		
		let reqG = OAuth2AuthRequest(url: URL(string: "https://auth.io")!, method: .GET)
		reqG.params["a"] = "A"
		do {
			let comp = try reqG.asURLComponents()
			XCTAssertEqual("auth.io", comp.host)
			XCTAssertNotNil(comp.query, "Must add params to URL for GET")
			XCTAssertEqual("a=A", comp.query)
			XCTAssertNotNil(comp.percentEncodedQuery, "Must add params to URL for GET")
		}
		catch let error {
			XCTAssertTrue(false, "Must not throw but threw \(error)")
		}
	}
	
	func testRequests() {
		let settings = ["client_id": "id", "client_secret": "secret"]
		let oauth = OAuth2(settings: settings)
		let reqH = OAuth2AuthRequest(url: URL(string: "https://auth.io")!)
		do {
			let request = try reqH.asURLRequest(for: oauth)
			XCTAssertEqual("Basic aWQ6c2VjcmV0", request.value(forHTTPHeaderField: "Authorization"))
			XCTAssertNil(request.httpBody)		// because no params are left
		}
		catch let error {
			XCTAssertTrue(false, "Must not throw but threw \(error)")
		}
		
		// test header override
		reqH.set(header: "Authorization", to: "Basic def==")
		reqH.set(header: "Accept", to: "text/plain, */*")
		do {
			let request = try reqH.asURLRequest(for: oauth)
			XCTAssertEqual("Basic def==", request.value(forHTTPHeaderField: "Authorization"))
			XCTAssertEqual("text/plain, */*", request.value(forHTTPHeaderField: "Accept"))
			XCTAssertNil(request.httpBody)		// because no params are left
		}
		catch let error {
			XCTAssertTrue(false, "Must not throw but threw \(error)")
		}
		
		// test no Auth header
		oauth.clientConfig.secretInBody = true
		let reqB = OAuth2AuthRequest(url: URL(string: "https://auth.io")!)
		do {
			let request = try reqB.asURLRequest(for: oauth)
			let response = String(data: request.httpBody!, encoding: String.Encoding.utf8) ?? ""
			XCTAssertTrue(response.contains("client_id=id"))
			XCTAssertTrue(response.contains("client_secret=secret"))
			XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
		}
		catch let error {
			XCTAssertTrue(false, "Must not throw but threw \(error)")
		}
	}
}

