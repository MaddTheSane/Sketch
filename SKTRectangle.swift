//
//  SKTRectangle.swift
//  Sketch
//
//  Created by C.W. Betts on 10/26/14.
//
//

import Cocoa

@objc(SKTRectangle) final class SKTRectangle: SKTGraphic {

	override var bezierPathForDrawing: NSBezierPath {
		// Simple.
		let path = NSBezierPath(rect: self.bounds)
		path.lineWidth = self.strokeWidth
		return path;
	}
}
