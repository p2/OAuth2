//
//  OAuth2Request.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/24/14.
//  Copyright (c) 2014 Pascal Pfiffner. All rights reserved.
//

import Foundation


/**
 *  A request that can be signed by an OAuth2 instance.
 */
public class OAuth2Request: NSMutableURLRequest {
	
	convenience init(URL: NSURL!, oauth: OAuth2, cachePolicy: NSURLRequestCachePolicy, timeoutInterval: NSTimeInterval) {
		self.init(URL: URL, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
		self.sign(oauth)
	}
	
	func sign(oauth: OAuth2) {
		if oauth.accessToken.isEmpty {
			fatalError("Cannot sign the request with an empty access token")
		}
		self.setValue("Bearer \(oauth.accessToken)", forHTTPHeaderField: "Authorization")
	}
}

