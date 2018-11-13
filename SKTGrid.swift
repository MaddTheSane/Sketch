//
//  Graphic.swift
//  SwiftSketch
//
//  Created by C.W. Betts on 10/11/14.
//  Copyright (c) 2014 C.W. Betts. All rights reserved.
//

import Cocoa

let SKTGridAnyKey = "any";
private let SKTGridTemporaryShowingTime: NSTimeInterval = 1.0;

class SKTGrid: NSObject {
	var color = NSColor.lightGrayColor()
	var _spacing: CGFloat = 9.0
	//BOOL _isAlwaysShown;
	//BOOL _isConstraining;
	var alwaysShown = false
	var constraining = false
	private var hidingTimer: NSTimer? = nil
	
	
	override init() {
		
		super.init()
	}
	
	class var keyPathsForValuesAffectingCanSetSpacing: NSSet {
		return NSSet(array:["alwaysShown", "constraining"])
	}
	
	class var keyPathsForValuesAffectingCanSetColor: NSSet {
		return NSSet(array:["alwaysShown", "usable"])
	}
	
	class var keyPathsForValuesAffectingUsable: NSSet {
		return NSSet(object:"spacing")
	}
	
	class var keyPathsForValuesAffectingAny: NSSet {
		
		// Specify that a KVO-compliant change for any of this class' non-derived properties should result in a KVO change notification for the "any" virtual property. Views that want to use this grid can observe "any" for notification of the need to redraw the grid.
		return NSSet(array:["color", "spacing", "alwaysShown", "constraining"])
		
	}
	
	func shopShowingGridForTimer(timer: NSTimer) {
		hidingTimer = nil
		
		self.willChangeValueForKey(SKTGridAnyKey)
		self.didChangeValueForKey(SKTGridAnyKey)
	}
	
	var usable: Bool {
		@objc(isUsable) get {
			return _spacing > 0
		}
	}
	
	var spacing: CGFloat {
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
						_hidingTimer.fireDate = NSDate(timeIntervalSinceNow: SKTGridTemporaryShowingTime)
					} else {
						
						// No, so show it the next time -drawRect:inView: is invoked, and then hide it again in one second.
						hidingTimer = NSTimer.scheduledTimerWithTimeInterval(SKTGridTemporaryShowingTime, target: self, selector: "stopShowingGridForTimer:", userInfo: nil, repeats: false)
						
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
	
	var canAlign: Bool {
		return usable
	}
	
	func constrainedPoint(inPoint: NSPoint) -> NSPoint {
		var point = inPoint
		// The grid might not be usable right now, or constraining might be turned off.
		if (self.usable && constraining) {
			point.x = floor((point.x / _spacing) + 0.5) * _spacing;
			point.y = floor((point.y / _spacing) + 0.5) * _spacing;
		}
		return point;
	}
	
	func alignedRect(arect: NSRect) -> NSRect {
		var rect = arect
		// Aligning is done even when constraining is not.
		var upperRight = NSMakePoint(NSMaxX(rect), NSMaxY(rect));
		rect.origin.x = floor((rect.origin.x / _spacing) + 0.5) * _spacing;
		rect.origin.y = floor((rect.origin.y / _spacing) + 0.5) * _spacing;
		upperRight.x = floor((upperRight.x / _spacing) + 0.5) * _spacing;
		upperRight.y = floor((upperRight.y / _spacing) + 0.5) * _spacing;
		rect.size.width = upperRight.x - rect.origin.x;
		rect.size.height = upperRight.y - rect.origin.y;
		return rect;
	}
	
	func drawRect(rect: NSRect, inView view: NSView) {
		// The grid might not be usable right now. It might be shown, but only temporarily.
		if self.usable && (alwaysShown || (hidingTimer != nil)) {
			
			// Figure out a big bezier path that corresponds to the entire grid. It will consist of the vertical lines and then the horizontal lines.
			var gridPath = NSBezierPath()
			var lastVerticalLineNumber = Int(floor(NSMaxX(rect) / _spacing))
			for (var lineNumber = Int(ceil(NSMinX(rect) / _spacing)); lineNumber <= lastVerticalLineNumber; lineNumber++) {
				gridPath.moveToPoint(NSPoint(x: CGFloat(lineNumber) * _spacing, y: NSMinY(rect)))
				gridPath.lineToPoint(NSPoint(x: CGFloat(lineNumber) * _spacing, y: NSMaxY(rect)))
			}
			var lastHorizontalLineNumber = Int(floor(NSMaxY(rect) / _spacing))
			for (var lineNumber = Int(ceil(NSMinY(rect) / _spacing)); lineNumber <= lastHorizontalLineNumber; lineNumber++) {
				gridPath.moveToPoint(NSPoint(x: NSMinX(rect), y: (CGFloat(lineNumber) * _spacing)))
				gridPath.moveToPoint(NSPoint(x: NSMaxX(rect), y: (CGFloat(lineNumber) * _spacing)))
			}
			
			// Draw the grid as one-pixel-wide lines of a specific color.
			color.set()
			gridPath.lineWidth = 0
			gridPath.stroke()
		}
	}
}
