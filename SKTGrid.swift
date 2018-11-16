//
//  Graphic.swift
//  SwiftSketch
//
//  Created by C.W. Betts on 10/11/14.
//  Copyright (c) 2014 C.W. Betts. All rights reserved.
//

import Cocoa

let SKTGridAnyKey = "any";
private let SKTGridTemporaryShowingTime: TimeInterval = 1.0;

class SKTGrid: NSObject {
	@objc var color = NSColor.lightGray
	var _spacing: CGFloat = 9.0
	//BOOL _isAlwaysShown;
	//BOOL _isConstraining;
	@objc var alwaysShown = false
	@objc var constraining = false
	private var hidingTimer: Timer? = nil
	
	
	override init() {
		
		super.init()
	}
	
	@objc class var keyPathsForValuesAffectingCanSetSpacing: Set<String> {
		return Set(["alwaysShown", "constraining"])
	}
	
	@objc class var keyPathsForValuesAffectingCanSetColor: Set<String> {
		return Set(["alwaysShown", "usable"])
	}
	
	@objc class var keyPathsForValuesAffectingUsable: Set<String> {
		return Set(["spacing"])
	}
	
	@objc class var keyPathsForValuesAffectingAny: Set<String> {
		
		// Specify that a KVO-compliant change for any of this class' non-derived properties should result in a KVO change notification for the "any" virtual property. Views that want to use this grid can observe "any" for notification of the need to redraw the grid.
		return Set(["color", "spacing", "alwaysShown", "constraining"])
		
	}
	
	@objc(stopShowingGridForTimer:)
	func stopShowingGrid(for timer: Timer) {
		hidingTimer = nil
		
		self.willChangeValue(forKey: SKTGridAnyKey)
		self.didChangeValue(forKey: SKTGridAnyKey)
	}
	
	@objc(usable) var isUsable: Bool {
		@objc(isUsable) get {
			return _spacing > 0
		}
	}
	
	@objc var spacing: CGFloat {
		get {
			return _spacing
		}
		set {
			// Weed out redundant invocations.
			if (newValue != _spacing) {
				_spacing = spacing;
				
				// If the grid is drawable, make sure the user gets visual feedback of the change. We don't have to do anything special if the grid is being shown right now.  Observers of "any" will get notified of this change because of what we did in +initialize. They're expected to invoke -drawRect:inView:.
				if (_spacing > 0 && !alwaysShown) {
					
					// Are we already showing the grid temporarily?
					if let _hidingTimer = hidingTimer {
						
						// Yes, and now the user's changed the grid spacing again, so put off the hiding of the grid.
						_hidingTimer.fireDate = Date(timeIntervalSinceNow: SKTGridTemporaryShowingTime)
					} else {
						
						// No, so show it the next time -drawRect:inView: is invoked, and then hide it again in one second.
						hidingTimer = Timer.scheduledTimer(timeInterval: SKTGridTemporaryShowingTime, target: self, selector: #selector(SKTGrid.stopShowingGrid(for:)), userInfo: nil, repeats: false)
						
						// Don't bother with a separate _showsGridTemporarily instance variable. -drawRect: can just check to see if _hidingTimer is non-nil.
						
					}
				}
			}
		}
	}
	
	var canSetSpacing: Bool {
		// Don't let the user change the spacing of the grid when that would be useless.
		return alwaysShown || constraining
	}
	
	@objc var canAlign: Bool {
		return isUsable
	}
	
	@objc(constrainedPoint:)
	func constrainedPoint(_ inPoint: NSPoint) -> NSPoint {
		var point = inPoint
		// The grid might not be usable right now, or constraining might be turned off.
		if (self.isUsable && constraining) {
			point.x = floor((point.x / _spacing) + 0.5) * _spacing;
			point.y = floor((point.y / _spacing) + 0.5) * _spacing;
		}
		return point;
	}
	
	@objc
	func alignedRect(_ arect: NSRect) -> NSRect {
		var rect = arect
		// Aligning is done even when constraining is not.
		var upperRight = NSPoint(x: rect.maxX, y: rect.maxY)
		rect.origin.x = floor((rect.origin.x / _spacing) + 0.5) * _spacing;
		rect.origin.y = floor((rect.origin.y / _spacing) + 0.5) * _spacing;
		upperRight.x = floor((upperRight.x / _spacing) + 0.5) * _spacing;
		upperRight.y = floor((upperRight.y / _spacing) + 0.5) * _spacing;
		rect.size.width = upperRight.x - rect.origin.x;
		rect.size.height = upperRight.y - rect.origin.y;
		return rect;
	}
	
	@objc(drawRect:inView:)
	func draw(_ rect: NSRect, in view: NSView) {
		// The grid might not be usable right now. It might be shown, but only temporarily.
		if self.isUsable && (alwaysShown || (hidingTimer != nil)) {
			
			// Figure out a big bezier path that corresponds to the entire grid. It will consist of the vertical lines and then the horizontal lines.
			let gridPath = NSBezierPath()
			let lastVerticalLineNumber = Int(floor(rect.maxX / _spacing))
			for lineNumber in Int(ceil(rect.minX / _spacing)) ... lastVerticalLineNumber  {
				gridPath.move(to: NSPoint(x: CGFloat(lineNumber) * _spacing, y: rect.minY))
				gridPath.line(to: NSPoint(x: CGFloat(lineNumber) * _spacing, y: rect.maxY))
			}
			let lastHorizontalLineNumber = Int(floor(rect.maxY / _spacing))
			for lineNumber in Int(ceil(NSMinY(rect) / _spacing)) ... lastHorizontalLineNumber {
				gridPath.move(to: NSPoint(x: NSMinX(rect), y: (CGFloat(lineNumber) * _spacing)))
				gridPath.move(to: NSPoint(x: NSMaxX(rect), y: (CGFloat(lineNumber) * _spacing)))
			}
			
			// Draw the grid as one-pixel-wide lines of a specific color.
			color.set()
			gridPath.lineWidth = 0
			gridPath.stroke()
		}
	}
}
