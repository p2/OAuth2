//
//  extensions.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/6/14.
//  Copyright (c) 2014 Pascal Pfiffner. All rights reserved.
//

import Foundation


extension Dictionary {
	mutating func addEntries(from: Dictionary) -> Dictionary {
		for (key, val) in from {
			self.updateValue(val, forKey: key)
		}
		return self
	}
}

extension NSHTTPURLResponse {
	public var statusString: String {
		get {
			return NSHTTPURLResponse.localizedStringForStatusCode(self.statusCode)
		}
	}
}
