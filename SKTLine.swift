//
//  SKTLine.swift
//  Sketch
//
//  Created by C.W. Betts on 10/26/14.
//
//

import Cocoa

let SKTLineBeginPointKey = "beginPoint";
let SKTLineEndPointKey = "endPoint";

// SKTGraphic's default selection handle machinery draws more handles than we need, so this class implements its own.
let SKTLineBeginHandle = 1
let SKTLineEndHandle = 2

private var presentablePropertyNamesByKey = [String: String]()
private var presentablePropertyNamesByKeyInstance: dispatch_once_t = 0

@objc(SKTLine) final class SKTLine: SKTGraphic {
	private var pointsRight = false
	private var pointsDown = false
	
	class var keyPathsForValuesAffectingEndPoint: NSSet {
		return NSSet(object: SKTGraphicBoundsKey)
	}
	
	private(set) var beginPoint: NSPoint {
		get {
		// Convert from our odd storage format to something natural.
		var beginPoint = NSZeroPoint;
		let bounds = self.bounds;
		beginPoint.x = pointsRight ? NSMinX(bounds) : NSMaxX(bounds);
		beginPoint.y = pointsDown ? NSMinY(bounds) : NSMaxY(bounds);
		return beginPoint;
		}
		set {
			// It's easiest to compute the results of setting these points together.
			self.bounds = SKTLine.boundsWithBeginPoint(newValue, endPoint: endPoint, pointsRight: &pointsRight, down: &pointsDown)
		}
	}
	
	class var keyPathsForValuesAffectingEndPont: NSSet {
		return NSSet(object: SKTGraphicBoundsKey)
	}
	
	private(set) var endPoint: NSPoint {
		get {
			var anEndPoint = NSZeroPoint
			let bounds = self.bounds
			anEndPoint.x = pointsRight ? NSMaxX(bounds) : NSMinX(bounds)
			anEndPoint.y = pointsDown ? NSMaxY(bounds) : NSMinY(bounds)
			
			return anEndPoint
		}
		set {
			// It's easiest to compute the results of setting these points together.
			bounds = SKTLine.boundsWithBeginPoint(beginPoint, endPoint: newValue, pointsRight: &pointsRight, down: &pointsDown)
		}
	}
	
	override var drawingFill: Bool {
		get {
		return false
	}
		set {
			
		}
	}
	
	override var drawingStroke: Bool {
		get {
		return true
	}
		set {
			
		}
	}
	
	override var canSetDrawingFill: Bool {
		return false
	}
	
	override var canSetDrawingStroke: Bool {
		return false
	}
	
	override var canMakeNaturalSize: Bool {
		return false
	}
	
	class func boundsWith(beginPoint: NSPoint, endPoint: NSPoint, pointsRight outPointsRight: inout Bool, down outPointsDown: inout Bool) -> NSRect {
		// Convert the begin and end points of the line to its bounds and flags specifying the direction in which it points.
		let pointsRight = beginPoint.x < endPoint.x
		let pointsDown = beginPoint.y < endPoint.y
		let xPosition = pointsRight ? beginPoint.x : endPoint.x
		let yPosition = pointsDown ? beginPoint.y : endPoint.y
		let width = fabs(endPoint.x - beginPoint.x)
		let height = fabs(endPoint.y - beginPoint.y)
		outPointsRight = pointsRight
		outPointsDown = pointsDown
		
		return NSRect(x: xPosition, y: yPosition, width: width, height: height)
	}
		
	required init(properties: [String : Any]) {
		var beginPoint: NSPoint
		var endPoint: NSPoint
		var beginPointString: Any? = properties[SKTLineBeginPointKey]
		if let beginPointAString = beginPointString as? String {
			beginPoint = NSPointFromString(beginPointAString)
		} else {
			beginPoint = NSZeroPoint
		}
		
		if let endPointString = properties[SKTLineEndPointKey] as? String {
			endPoint = NSPointFromString(endPointString)
		} else {
			endPoint = NSZeroPoint
		}		
		
		super.init(properties: properties)
		self.bounds = SKTLine.boundsWithBeginPoint(beginPoint, endPoint: endPoint, pointsRight: &pointsRight, down: &pointsDown)
	}

	required init() {
	    //fatalError("init() has not been implemented")
		
		super.init()
	}
	
	override var properties: NSMutableDictionary {
		// Let SKTGraphic do its job but throw out the bounds entry in the dictionary it returned and add begin and end point entries insteads. We do this instead of simply recording the currnet value of _pointsRight and _pointsDown because bounds+pointsRight+pointsDown is just too unnatural to immortalize in a file format. The dictionary must contain nothing but values that can be written in old-style property lists.
		var aProp = super.properties
		aProp.removeObjectForKey(SKTGraphicBoundsKey)
		aProp[SKTLineBeginPointKey] = NSStringFromPoint(beginPoint)
		aProp[SKTLineEndPointKey] = NSStringFromPoint(endPoint)
		
		return aProp
	}
	
	override func setColor(color: NSColor) {
		// Because lines aren't filled we'll consider the stroke's color to be the one.
		self.setValue(color, forKey: SKTGraphicStrokeColorKey)
	}
	
	override func copyWithZone(zone: NSZone) -> AnyObject {
		// Do the regular Cocoa thing.
		
		var copy = super.copyWithZone(zone) as SKTLine
		copy.pointsRight = self.pointsRight
		copy.pointsDown = self.pointsDown
		return copy
	}
	
	override var keysForValuesToObserveForUndo: NSSet {
		// When the user drags one of the handles of a line we don't want to just have changes to "bounds" registered in the undo group. That would be:
		// 1) Insufficient. We would also have to register changes of "pointsRight" and "pointsDown," but we already decided to keep those properties private (see the comments in the header).
		// 2) Not very user-friendly. We don't want the user to see an "Undo Change of Bounds" item in the Edit menu. We want them to see "Undo Change of Endpoint."
		// So, tell the observer of undoable properties (SKTDocument, in Sketch) to observe "beginPoint" and "endPoint" instead of "bounds."
		var oldKeys = NSMutableSet(set: super.keysForValuesToObserveForUndo)
		oldKeys.removeObject(SKTGraphicBoundsKey)
		oldKeys.addObject(SKTLineBeginPointKey)
		oldKeys.addObject(SKTLineEndPointKey)
		
		return oldKeys
	}
	
	override var bezierPathForDrawing: NSBezierPath {
		let path = NSBezierPath()
		path.moveToPoint(beginPoint)
		path.lineToPoint(endPoint)
		path.lineWidth = strokeWidth
		
		return path
	}
	
	override func drawHandlesInView(view: NSView) {
	// A line only has two handles.
		self.drawHandleInView(view, atPoint: beginPoint)
		self.drawHandleInView(view, atPoint: endPoint)
	}
	
	override func isContentsUnderPoint(point: NSPoint) -> Bool {
		// Do a gross check against the bounds.
		var isUnder = false
		if NSPointInRect(point, bounds) {
			// Let the user click within the stroke width plus some slop.
			let acceptableDistance = (strokeWidth / 2) + 2
			
			// Before doing anything avoid a divide by zero error.
			let beginPoint = self.beginPoint
			let endPoint = self.endPoint
			let xDelta = endPoint.x - beginPoint.x
			if xDelta == 0 && fabs(point.x - beginPoint.x) <= acceptableDistance {
				isUnder = true
			} else {
				// Do a weak approximation of distance to the line segment.
				let slope = (endPoint.y - beginPoint.y) / xDelta
				if fabs(((point.x - beginPoint.x) * slope) - (point.y - beginPoint.y)) <= acceptableDistance {
					isUnder = true
				}
			}
		}
		
		return isUnder
	}
	
	override func handleUnderPoint(point: NSPoint) -> Int {
		// A line just has handles at its ends.
		var handle = SKTGraphicNoHandle
		
		if isHandleAtPoint(beginPoint, underPoint: point) {
			handle = SKTLineBeginHandle
		} else if isHandleAtPoint(endPoint, underPoint: point) {
			handle = SKTLineEndHandle
		}
		
		return handle
	}
	
	override func resizeByMovingHandle(handle: Int, toPoint point: NSPoint) -> Int {
		// A line just has handles at its ends.
		if handle == SKTLineBeginHandle {
			beginPoint = point
		} else if handle == SKTLineEndHandle {
			endPoint = point
		}// else a cataclysm occurred.
		
		// We don't have to do the kind of handle flipping that SKTGraphic does.
		return handle;
	}
	
	override class func presentablePropertyNameForKey(key: String) -> String? {
		// Pretty simple. As is usually the case when a key is passed into a method like this, we have to invoke super if we don't recognize the key. As far as the user is concerned both points that define a line are "endpoints."
		dispatch_once(&presentablePropertyNamesByKeyInstance, { () -> Void in
			presentablePropertyNamesByKey[SKTLineBeginPointKey] = NSLocalizedString("Beginpoint", tableName: "UndoStrings",comment: "Action name part for SKTLineBeginPointKey.")
			presentablePropertyNamesByKey[SKTLineEndPointKey] = NSLocalizedString("Endpoint", tableName: "UndoStrings",comment: "Action name part for SKTLineEndPointKey.")
		})
		
		var presentablePropertyName = presentablePropertyNamesByKey[key]
		if presentablePropertyName == nil {
			presentablePropertyName = super.presentablePropertyNameForKey(key)
		}
		
		return presentablePropertyName
	}
	
}
