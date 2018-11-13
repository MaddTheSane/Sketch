//
//  SKTCircle.swift
//  Sketch
//
//  Created by C.W. Betts on 10/26/14.
//
//

import Cocoa

@objc(SKTCircle) final class SKTCircle: SKTGraphic {

	override var bezierPathForDrawing: NSBezierPath {
		// Simple.
		var path = NSBezierPath(ovalInRect: self.bounds)
		path.lineWidth = self.strokeWidth
		return path;
	}

	override func isContentsUnderPoint(point: NSPoint) -> Bool {
		return bezierPathForDrawing.containsPoint(point)
	}
}
