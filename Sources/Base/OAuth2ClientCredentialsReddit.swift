//
//  OAuth2ClientCredentialsReddit.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 3/20/16.
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


/**
Enables Reddit's special client credentials flow for installed apps.

This flow will specify `https://oauth.reddit.com/grants/installed_client` as grant type and also supply a `device_id`, which you must set
during configuration or by setting the `deviceId` property.

https://github.com/reddit/reddit/wiki/OAuth2#application-only-oauth
*/
public class OAuth2ClientCredentialsReddit: OAuth2ClientCredentials {
	
	public override class var grantType: String {
		return "https://oauth.reddit.com/grants/installed_client"
	}
	
	/// An identifier of the device requesting the token. You should generate and save a unique ID on your client. DO NOT use any personally
	/// identifiable information (including non-user-resettable information, such as Android's TelephonyManager.getDeviceId() or iOS's IDFA).
	public var deviceId: String?
	
	
	/**
	The special Reddit client credentials flow for installed apps adds the `device_id` key to the settings dictionary.
	
	- parameter settings: The authorization settings
	*/
	public override init(settings: OAuth2JSON) {
		deviceId = settings["device_id"] as? String
		super.init(settings: settings)
		clientConfig.clientSecret = ""
	}
	
	/** Add `device_id` parameter to the request created by the superclass. */
	override func tokenRequest(params: OAuth2StringDict? = nil) throws -> OAuth2AuthRequest {
		guard let device = deviceId else {
			throw OAuth2Error.Generic("You must configure this flow with a `device_id` (via settings) or manually assign `deviceId`")
		}
		
		let req = try super.tokenRequest(params)
		req.params["device_id"] = device
		return req
	}
}

