//
//  SKTGraphic.swift
//  Sketch
//
//  Created by C.W. Betts on 11/12/14.
//
//

import Cocoa

// String constants declared in the header. A lot of them aren't used by any other class in the project, but it's a good idea to provide and use them, if only to help prevent typos in source code.
// Why are there @"drawingFill" and @"drawingStroke" keys here when @"isDrawingFill" and @"isDrawingStroke" would be a little more consistent with Cocoa convention for boolean values? Because we might want to add setter methods for these properties some day, and key-value coding isn't smart enough to ignore "is" when looking for setter methods, and having to give methods ugly names -setIsDrawingFill: and -setIsDrawingStroke: would be irritating. In general it's best to leave the "is" off the front of keys that identify boolean values.

private let SKTGraphicUpperLeftHandle = 1
private let SKTGraphicUpperMiddleHandle = 2
private let SKTGraphicUpperRightHandle = 3
private let SKTGraphicMiddleLeftHandle = 4
private let SKTGraphicMiddleRightHandle = 5
private let SKTGraphicLowerLeftHandle = 6
private let SKTGraphicLowerMiddleHandle = 7
private let SKTGraphicLowerRightHandle = 8

private var crosshairsCursor: NSCursor? = nil
private var crosshairsCursorOnce: dispatch_once_t = 0

@objc protocol SKTGraphicScriptingContainer: NSObjectProtocol {
	// An informal protocol to which scriptable containers of SKTGraphics must conform. We declare this instead of just making it an SKTDocument method because that would needlessly reduce SKTGraphic's reusability (they would only be containable by SKTDocuments).
	func objectSpecifierForGraphic(graphic: SKTGraphic) -> NSScriptObjectSpecifier?
}

// Another constant that's declared in the header.
//let SKTGraphicNoHandle = 0;

// A key that's used in Sketch's property-list-based file and pasteboard formats.
private let SKTGraphicClassNameKey = "className";

// The handles that graphics draw on themselves are 6 point by 6 point rectangles.
let SKTGraphicHandleWidth: CGFloat = 6.0;
let SKTGraphicHandleHalfWidth: CGFloat = 6.0 / 2.0;


// Move each graphic in the array by the same amount.
func TranslateGraphics(_ graphics: [SKTGraphic], byX deltaX: CGFloat, y deltaY: CGFloat) {
	// Pretty simple.
	for graphic in graphics {
		graphic.bounds = NSOffsetRect(graphic.bounds, deltaX, deltaY)
	}
}

// Return the total "bounds" of all of the graphics in the array.
func BoundsOfGraphics(_ graphics: [SKTGraphic]) -> NSRect {
	// The bounds of an array of graphics is the union of all of their bounds.
	var bounds = NSRect.zero
	let graphicCount = graphics.count
	if graphicCount > 0 {
		bounds = graphics[0].bounds
		for index in 1..<graphicCount {
			bounds = NSUnionRect(bounds, graphics[index].bounds);
		}
	}
	
	return bounds
}

// Return the total drawing bounds of all of the graphics in the array.
func DrawingBoundsOfGraphics(_ graphics: [SKTGraphic]) -> NSRect {
	// The drawing bounds of an array of graphics is the union of all of their drawing bounds.
	var drawingBounds = NSRect.zero
	if graphics.count > 0 {
		drawingBounds = graphics[0].drawingBounds
	}
	for graphic in graphics {
		drawingBounds = NSUnionRect(drawingBounds, graphic.drawingBounds)
	}
	
	return drawingBounds
}

// MARK: *** Persistence ***

/* You can override these class methods in your subclass of SKTGraphic, but it would be a waste of time, because no one invokes these on any class other than SKTGraphic itself. Really these could just be functions if we didn't have such a syntactic sweet tooth. */

// Return an array of graphics created from flattened data of the sort returned by +pasteboardDataWithGraphics: or, if that's not possible, return nil and set *outError to an NSError that can be presented to the user to explain what went wrong.
func GraphicsWithPasteboardData(_ data: Data) throws -> [SKTGraphic] {
	// Because this data may have come from outside this process, don't assume that any property list object we get back is the right type.
	var graphics: [SKTGraphic]?
	var propertiesArray = PropertyListSerialization.propertyListFromData(data, mutabilityOption: [], format: nil, errorDescription: nil)
	if !(propertiesArray is [AnyObject]) {
		propertiesArray = nil
	}
	
	guard let ourProp = propertiesArray as? [NSDictionary]  else {
		// If property list parsing fails we have no choice but to admit that we don't know what went wrong. The error description returned by +[NSPropertyListSerialization propertyListFromData:mutabilityOption:format:errorDescription:] would be pretty technical, and not the sort of thing that we should show to a user.
		throw SKTErrorWithCode(.unknownPasteboardReadError)
	}
	
	// Convert the array of graphic property dictionaries into an array of graphics.
	return GraphicsWithProperties(ourProp)
}

// Given an array of property list dictionaries whose validity has not been determined, return an array of graphics.
func GraphicsWithProperties(_ propertiesArray: [NSDictionary]) -> [SKTGraphic] {
		// Convert the array of graphic property dictionaries into an array of graphics. Again, don't assume that property list objects are the right type.
	let graphicCount = propertiesArray.count
	var graphics = [SKTGraphic]()
	for properties in propertiesArray {
		// Figure out the class of graphic to instantiate. The value of the SKTGraphicClassNameKey entry must be an Objective-C class name. Don't trust the type of something you get out of a property list unless you know your process created it or it was read from your application or framework's resources.
		if let className = properties[SKTGraphicClassNameKey] as? String {
			if let aclass: SKTGraphic.Type = NSClassFromString(className) as? SKTGraphic.Type {
				// Create a new graphic. If it doesn't work then just do nothing. We could return an NSError, but doing things this way 1) means that a user might be able to rescue graphics from a partially corrupted document, and 2) is easier.
				let graphic = aclass(properties: properties)
				graphics.append(graphic)
			}
		}
	}
	
	return graphics
}

// Return the array of graphics as flattened data that is appropriate for passing to +graphicsWithPasteboardData:error:.
func PasteboardData(with graphics: [SKTGraphic]) -> Data? {
	// Convert the contents of the document to a property list and then flatten the property list.
	if let aProp = PropertiesWithGraphics(graphics) {
		return PropertyListSerialization.dataFromPropertyList(aProp, format: .binary, errorDescription: nil)
	}
	//
	return nil
}

// Given an array of graphics, return an array of property list dictionaries.
func PropertiesWithGraphics(_ graphics: [SKTGraphic]) -> [NSDictionary]? {
	// Convert the array of graphics dictionaries into an array of graphic property dictionaries.
	var propertiesArray = [NSDictionary]()
	for graphic in graphics {
		// Get the properties of the graphic, add the class name that can be used by +graphicsWithProperties: to it, and add the properties to the array we're building.
		var properties = graphic.properties
		properties[SKTGraphicClassNameKey] = NSStringFromClass(type(of: graphic))
		propertiesArray.append(properties)
	}
	
	return propertiesArray.count == 0 ? nil : propertiesArray
}


@objc(SKTGraphic) class SKTGraphic: NSObject, NSCopying {
	var bounds = NSZeroRect
	var drawingFill = false
	var fillColor: NSColor? = NSColor.white
	var drawingStroke = true
	var strokeColor: NSColor? = NSColor.black
	var strokeWidth: CGFloat = 1.0
	
	dynamic func copy(with zone: NSZone?) -> Any {
		let copy = type(of: self).init()
		copy.bounds = self.bounds
		copy.drawingFill = self.drawingFill
		copy.fillColor = fillColor?.copy() as? NSColor
		copy.drawingStroke = self.drawingStroke
		copy.strokeColor = self.strokeColor?.copy() as? NSColor
		copy.strokeWidth = self.strokeWidth
		
		return copy
	}
	
	required override init() {
		
		
		super.init()
	}
	
	/*
	@interface SKTGraphic : NSObject<NSCopying> {
	@private
	
	// The values underlying some of the key-value coding (KVC) and observing (KVO) compliance described below. Any corresponding getter or setter methods are there for invocation by code in subclasses, not for KVC or KVO compliance. KVC's direct instance variable access, KVO's autonotifying, and KVO's property dependency mechanism makes them unnecessary for the latter purpose.
	// If you look closely, you'll notice that SKTGraphic itself never touches these instance variables directly except in initializers, -copyWithZone:, and public accessors. SKTGraphic is following a good rule: if a class publishes getters and setters it should itself invoke them, because people who override methods to customize behavior are right to expect their overrides to actually be invoked.
	
	// The object that contains the graphic (unretained), from the point of view of scriptability. This is here only for use by this class' override of scripting's -objectSpecifier method. In Sketch this is an SKTDocument.
	id<SKTGraphicScriptingContainer> _scriptingContainer;
	
	}
	
	/* This class is KVC (except for "drawingContents") and KVO (except for the scripting-only properties) compliant for these keys:
	
	"canSetDrawingFill" and "canSetDrawingStroke" (boolean NSNumbers; read-only) - Whether or not it even makes sense to try to change the value of the "drawingFill" or "drawingStroke" property.
	
	"drawingFill" (a boolean NSNumber; read-write) - Whether or not the user wants this graphic to be filled with the "fillColor" when it's drawn.
	
	"fillColor" (an NSColor; read-write) - The color that will be used to fill this graphic when it's drawn. The value of this property is ignored when the value of "drawingFill" is NO.
	
	"drawingStroke" (a boolean NSNumber; read-write) - Whether or not the user wants this graphic to be stroked with a path that is "strokeWidth" units wide, using the "strokeColor," when it's drawn.
	
	"strokeColor" (an NSColor; read-write) - The color that will be used to stroke this graphic when it's drawn. The value of this property is ignored when the value of "drawingStroke" is NO.
	
	"strokeWidth" (a floating point NSNumber; read-write) - The width of the stroke that will be used when this graphic is drawn. The value of this property is ignored when the value of "drawingStroke" is NO.
	
	"xPosition" and "yPosition" (floating point NSNumbers; read-write) - The coordinate of the upper-left corner of the graphic.
	
	"width" and "height" (floating point NSNumbers; read-write) - The size of the graphic.
	
	"bounds" (an NSRect-containing NSValue; read-only) - The basic shape of the graphic. For instance, this doesn't include the width of any strokes that are drawn (so "bounds" is really a bit of a misnomer). Being KVO-compliant for bounds contributes to the automatic KVO compliance for drawingBounds via the use of KVO's dependency mechanism. See +[SKTGraphic keyPathsForValuesAffectingDrawingBounds].
	
	"drawingBounds" (an NSRect-containing NSValue; read-only) - The bounding box of anything the graphic might draw when sent a -drawContentsInView: or -drawHandlesInView: message.
	
	"drawingContents" (no value; not readable or writable) - A virtual property for which KVO change notifications are sent whenever any of the properties that affect the drawing of the graphic without affecting its bounds change. We use KVO for this instead of more traditional methods so that we don't have to write any code other than an invocation of KVO's +setKeys:triggerChangeNotificationsForDependentKey:. (To use NSNotificationCenter for instance we would have to write -set...: methods for all of this object's settable properties. That's pretty easy, but it's nice to avoid such boilerplate when possible.) There is no value for this property, because it would not be useful, so this class isn't actually KVC-compliant for "drawingContents." This property is not called "needsDrawing" or some such thing because instances of this class do not know how many views are using it, and potentially there will moments when it "needs drawing" in some views but not others.
	
	"keysForValuesToObserveForUndo" (an NSSet of NSStrings; read-only) - See the comment for -keysForValuesToObserveForUndo below.
	
	"scriptingFillColor" and "scriptingStrokeColor" (NSColors; read-write) - The colors that will be used to fill or stroke this graphic when it's drawn, or nil if filling or stroking is not being done. These attributes are computed from "drawingFill"/"fillColor" and "drawingStroke"/"strokeColor." They're here because, even though the separate boolean properties are OK for presenting in checkboxes in the UI, we don't want to make scripters deal with them. For scripters a color of nil ("missing value") is what's used to turn off filling or stroking.
	
	"scriptingStrokeWidth" (a floating point NSNumber; read-write) - The width of the stroke that will be used for this graphic when it's drawn, or nil if stroking is not being done. This attribute is derived from "strokeWidth." It's here because we want to accurately report "missing value" when stroking is not being done. Since it's here we might as well let scripters turn off stroking by setting "missing value" too.
	
	In Sketch various properties of the controls of the grid inspector are bound to the properties of the selection of the graphics controller belonging to the window controller of the main window. Each SKTGraphicView observes the "drawingBounds" and "drawingContents" properties of every graphic that it's displaying so it knows when they need redrawing. Each SKTDocument observes many properties of every of one of its graphics so it can register undo actions when they change; for each graphic the exact set of such properties is determined by the current value of the "keysForValuesToObserveForUndo" property. Also, many of these properties are scriptable.
	
	*/
	*/
	
	// MARK: *** Convenience ***
	
	/* You can override these class methods in your subclass of SKTGraphic, but it would be a waste of time, because no one invokes these on any class other than SKTGraphic itself. Really these could just be functions if we didn't have such a syntactic sweet tooth. */
	
	class func drawingBoundsOfGraphics(of graphics: [SKTGraphic]) -> NSRect {
		return DrawingBoundsOfGraphics(graphics)
	}
	
	class func graphicsWithProperties(propertiesArray: [NSDictionary]) -> [SKTGraphic]? {
		return GraphicsWithProperties(propertiesArray)
	}

	class func translateGraphics(graphics: [SKTGraphic], byX deltaX: CGFloat, y deltaY: CGFloat) {
		return TranslateGraphics(graphics, byX: deltaX, y: deltaY)
	}
	
	class func boundsOfGraphics(graphics: [SKTGraphic]) -> NSRect {
		return BoundsOfGraphics(graphics)
	}
	
	class func pasteboardDataWithGraphics(graphics: [SKTGraphic]) -> Data? {
		return PasteboardData(with: graphics)
	}
	
	// Given an array of graphics, return an array of property list dictionaries.
	class func propertiesWithGraphics(graphics: [SKTGraphic]) -> [NSDictionary]? {
		return PropertiesWithGraphics(graphics)
	}

	class func graphicsWithPasteboardData(data: Data) throws -> [SKTGraphic] {
		return try GraphicsWithPasteboardData(data)
	}
	
	/* Subclasses of SKTGraphic might have reason to override any of the rest of this class' methods, starting here. */
	
	// Given a dictionary having the sort of entries that would be in a dictionary returned by -properties, but whose validity has not been determined, initialize, setting the values of as many properties as possible from it. Ignore unrecognized dictionary entries. Use default values for missing dictionary entries. This is not the designated initializer for this class (-init is).
	dynamic required init(properties: [String : Any]) {
		super.init()
		
		// The dictionary entries are all instances of the classes that can be written in property lists. Don't trust the type of something you get out of a property list unless you know your process created it or it was read from your application or framework's resources. We don't have to worry about KVO-compliance in initializers like this by the way; no one should be observing an unitialized object.
		if let boundsString = properties[SKTGraphicBoundsKey] as? String {
			bounds = NSRectFromString(boundsString)
		}
		
		if let isDrawingFillNumber = properties[SKTGraphicIsDrawingFillKey] as? NSNumber {
			drawingFill = isDrawingFillNumber.boolValue
		}
		
		if let fillColorData = properties[SKTGraphicFillColorKey] as? NSData {
			fillColor = (NSUnarchiver.unarchiveObjectWithData(fillColorData)! as NSColor)
		}
		
		if let isDrawingStrokeNumber = properties[SKTGraphicIsDrawingStrokeKey] as? NSNumber {
			drawingStroke = isDrawingStrokeNumber.boolValue
		}
		
		if let strokeColorData = properties[SKTGraphicStrokeColorKey] as? NSData {
			strokeColor = (NSUnarchiver.unarchiveObjectWithData(strokeColorData) as NSColor)
		}

		if let strokeWidthNumber = properties[SKTGraphicStrokeWidthKey] as? NSNumber {
			strokeWidth = CGFloat(strokeWidthNumber.doubleValue)
		}
	}
	
	// Return a dictionary that can be used as property list object and contains enough information to recreate the graphic (except for its class, which is handled by +propertiesWithGraphics:). The returned dictionary must be mutable so that it can be added to efficiently, but the receiver must ignore any mutations made to it after it's been returned.
	var properties: NSMutableDictionary {
		var aProp = NSMutableDictionary()
		aProp[SKTGraphicBoundsKey] = NSStringFromRect(bounds)
		aProp[SKTGraphicIsDrawingFillKey] = drawingFill
		if let fillColor = self.fillColor {
			aProp[SKTGraphicFillColorKey] = NSArchiver.archivedData(withRootObject: fillColor)
		}
		aProp[SKTGraphicIsDrawingStrokeKey] = drawingStroke
		if let strokeColor = self.strokeColor {
			aProp[SKTGraphicStrokeColorKey] = NSArchiver.archivedData(withRootObject: strokeColor)
		}
		aProp [SKTGraphicStrokeWidthKey] = strokeWidth
		
		return aProp
	}
	
	//MARK: *** Simple Property Getting ***
	
	// Accessors for properties that this class stores as instance variables. These methods provide readable KVC-compliance for several of the keys mentioned in comments above, but that's not why they're here (KVC direct instance variable access makes them unnecessary for that). They're here just for invoking and overriding by subclass code.
	
	// MARK: *** Drawing ***
	
	// Return the keys of all of the properties whose values affect the appearance of an instance of the receiving subclass of SKTGraphic (even properties declared in a superclass). The first method should return the keys for such properties that affect the drawing bounds of graphics. The second method should return the keys for such properties that do not. Most subclasses of SKTGraphic should override one or both of these, and be KVO-compliant for the properties identified by keys in the returned set. Implementations of these methods don't have to be fast, at least not in the context of Sketch, because their results are cached. In Mac OS 10.5 and later these methods are invoked automatically by KVO because their names match the result of applying to "drawingBounds" and "drawingContents" the naming pattern used by the default implementation of +[NSObject(NSKeyValueObservingCustomization) keyPathsForValuesAffectingValueForKey:].
	
	dynamic class var keyPathsForValuesAffectingDrawingBounds: NSSet {
    // The only properties managed by SKTGraphic that affect the drawing bounds are the bounds and the the stroke width.
		return NSSet(array: [SKTGraphicBoundsKey, SKTGraphicStrokeWidthKey])
	}
	
	dynamic class var keyPathsforValuesAffectingDrawingContents: NSSet {
		// The only properties managed by SKTGraphic that affect drawing but not the drawing bounds are the fill and stroke parameters.
		return NSSet(array: [SKTGraphicIsDrawingFillKey, SKTGraphicFillColorKey, SKTGraphicIsDrawingStrokeKey, SKTGraphicStrokeColorKey])
	}
	
	// Return the bounding box of everything the receiver might draw when sent a -draw...InView: message. The default implementation of this method returns a bounds that assumes the default implementations of -drawContentsInView: and -drawHandlesInView:. Subclasses that override this probably have to override +keyPathsForValuesAffectingDrawingBounds too.*/
	var drawingBounds: NSRect {
		// Assume that -[SKTGraphic drawContentsInView:] and -[SKTGraphic drawHandlesInView:] will be doing the drawing. Start with the plain bounds of the graphic, then take drawing of handles at the corners of the bounds into account, then optional stroke drawing.
		var outset = SKTGraphicHandleHalfWidth
		if drawingStroke {
			var strokeOutset: CGFloat = strokeWidth / 2
			if strokeOutset > outset {
				outset = strokeOutset
			}
		}
		var inset: CGFloat = 0.0 - outset
		var drawingBounds = NSInsetRect(bounds, inset, inset)
		
		// -drawHandleInView:atPoint: draws a one-unit drop shadow too.
		drawingBounds.size.width += 1.0
		drawingBounds.size.height += 1.0
		return drawingBounds;
	}
	
	// Draw the contents the receiver in a specific view. Use isBeingCreatedOrEditing if the graphic draws differently during its creation or while it's being edited. The default implementation of this method just draws the result of invoking -bezierPathForDrawing using the current fill and stroke parameters. Subclasses have to override either this method or -bezierPathForDrawing. Subclasses that override this may have to override +keyPathsForValuesAffectingDrawingBounds, +keyPathsForValuesAffectingDrawingContents, and -drawingBounds too.
	dynamic func drawContentsInView(view: NSView, isBeingCreateOrEdited: Bool) {
		// If the graphic is so so simple that it can be boiled down to a bezier path then just draw a bezier path. It's -bezierPathForDrawing's responsibility to return a path with the current stroke width.
		if let path = bezierPathForDrawing {
			if self.drawingFill {
				self.fillColor?.set()
				path.fill()
			}
			if self.drawingStroke {
				self.strokeColor?.set()
				path.stroke()
			}
		}
	}
	
	// Return a bezier path that can be stroked and filled to draw the graphic, if the graphic can be drawn so simply, nil otherwise. The default implementation of this method returns nil. Subclasses have to override either this method or -drawContentsInView:. Any returned bezier path should already have the graphic's current stroke width set in it.
	var bezierPathForDrawing: NSBezierPath? {
		// Live to be overriden.
		//[NSException raise:NSInternalInconsistencyException format:@"Neither -drawContentsInView: nor -bezierPathForDrawing has been overridden."];
		return nil
	}
	
	// Draw the handles of the receiver in a specific view. The default implementation of this method just invokes -drawHandleInView:atPoint: for each point at the corners and on the sides of the rectangle returned by -bounds. Subclasses that override this probably have to override -handleUnderPoint: too.
	dynamic func drawHandlesInView(view: NSView) {
    // Draw handles at the corners and on the sides.
		let bounds = self.bounds
		drawHandle(in: view, atPoint: NSMakePoint(NSMinX(bounds), NSMinY(bounds)))
		drawHandle(in: view, atPoint: NSMakePoint(NSMidX(bounds), NSMinY(bounds)))
		drawHandle(in: view, atPoint: NSMakePoint(NSMaxX(bounds), NSMinY(bounds)))
		drawHandle(in: view, atPoint: NSMakePoint(NSMinX(bounds), NSMidY(bounds)))
		drawHandle(in: view, atPoint: NSMakePoint(NSMaxX(bounds), NSMidY(bounds)))
		drawHandle(in: view, atPoint: NSMakePoint(NSMinX(bounds), NSMaxY(bounds)))
		drawHandle(in: view, atPoint: NSMakePoint(NSMidX(bounds), NSMaxY(bounds)))
		drawHandle(in: view, atPoint: NSMakePoint(NSMaxX(bounds), NSMaxY(bounds)))
	}
	
	// Draw handle at a specific point in a specific view. Subclasses that override -drawHandlesInView: can invoke this to easily draw handles whereever they like.
	func drawHandle(in view: NSView, atPoint point: NSPoint) {
		// Figure out a rectangle that's centered on the point but lined up with device pixels.
		var handleBounds = NSRect(x: point.x - SKTGraphicHandleHalfWidth, y:point.y - SKTGraphicHandleHalfWidth, width: SKTGraphicHandleWidth, height: SKTGraphicHandleWidth)
		handleBounds = view.centerScanRect(handleBounds)
		
		// Draw the shadow of the handle.
		var handleShadowBounds = NSOffsetRect(handleBounds, 1.0, 1.0)
		NSColor.controlDarkShadowColor.set()
		NSRectFill(handleShadowBounds);
		
		// Draw the handle itself.
		NSColor.knobColor.set()
		NSRectFill(handleBounds);
	}
	
	// MARK: *** Editing ***
	
	// Return a cursor that can be used when the user has clicked using the creation tool and is dragging the mouse to size a new instance of the receiving class.
	//+ (NSCursor *)creationCursor;
	class var creationCursor: NSCursor {
		dispatch_once(&crosshairsCursorOnce) {
			var crosshairsImage = NSImage(named: "Cross")!
			let crosshairsImageSize = crosshairsImage.size
			crosshairsCursor = NSCursor(image: crosshairsImage, hotSpot: NSMakePoint((crosshairsImageSize.width / 2.0), (crosshairsImageSize.height / 2.0)))
		}
		return crosshairsCursor!
	}
	
	// Return the number of the handle that the user is dragging when they move the mouse after clicking to create a new instance of the receiving class. The default implementation of this method returns a number that corresponds to one of the corners of the graphic's bounds. Subclasses that override this should probably override -resizeByMovingHandle:toPoint: too.
	var creationSizingHandle: Int {
		// Return the number of the handle for the lower-right corner. If the user drags it so that it's no longer in the lower-right, -resizeByMovingHandle:toPoint: will deal with it.
		return SKTGraphicLowerRightHandle;
	}
	
	// Return YES if it's useful to let the user toggle drawing of the fill or stroke, NO otherwise. The default implementations of these methods return YES.
	var canSetDrawingFill: Bool {
		// The default implementation of -drawContentsInView: can draw fills.
		return true
	}
	
	var canSetDrawingStroke: Bool {
		// The default implementation of -drawContentsInView: can draw strokes.
		return true
	}
	
	// Return YES if sending -makeNaturalSize to the receiver would do something noticable by the user, NO otherwise. The default implementation of this method returns YES if the defaultimplementation of -makeNaturalSize would actually do something, NO otherwise.
	var canMakeNaturalSize: Bool {
		// Only return YES if -makeNaturalSize would actually do something.
		let bounds = self.bounds;
		return bounds.size.width != bounds.size.height
	}
	
	// Return YES if the point is in the contents of the receiver, NO otherwise. The default implementation of this method returns YES if the point is inside [self bounds].
	func isContentsUnderPoint(point: NSPoint) -> Bool {
		// Just check against the graphic's bounds.
		return NSPointInRect(point, bounds);
	}
	
	// If the point is in one of the handles of the receiver return its number, SKTGraphicNoHandle otherwise. The default implementation of this method invokes -isHandleAtPoint:underPoint: for the corners and on the sides of the rectangle returned by -bounds. Subclasses that override this probably have to override several other methods too.
	func handleUnderPoint(_ point: NSPoint) -> Int {
		// Check handles at the corners and on the sides.

		var handle = SKTGraphicNoHandle
		let bounds = self.bounds
		if (isHandle(at: NSMakePoint(NSMinX(bounds), NSMinY(bounds)), under:point)) {
			handle = SKTGraphicUpperLeftHandle;
		} else if (isHandle(at: NSMakePoint(NSMidX(bounds), NSMinY(bounds)), under:point)) {
			handle = SKTGraphicUpperMiddleHandle;
		} else if (isHandle(at: NSMakePoint(NSMaxX(bounds), NSMinY(bounds)), under:point)) {
			handle = SKTGraphicUpperRightHandle;
		} else if (isHandle(at: NSMakePoint(NSMinX(bounds), NSMidY(bounds)), under:point)) {
			handle = SKTGraphicMiddleLeftHandle;
		} else if (isHandle(at: NSMakePoint(NSMaxX(bounds), NSMidY(bounds)), under:point)) {
			handle = SKTGraphicMiddleRightHandle;
		} else if (isHandle(at: NSMakePoint(NSMinX(bounds), NSMaxY(bounds)), under:point)) {
			handle = SKTGraphicLowerLeftHandle;
		} else if (isHandle(at: NSMakePoint(NSMidX(bounds), NSMaxY(bounds)), under:point)) {
			handle = SKTGraphicLowerMiddleHandle;
		} else if isHandle(at: NSMakePoint(NSMaxX(bounds), NSMaxY(bounds)), under:point) {
			handle = SKTGraphicLowerRightHandle;
		}
		
		return handle
	}
	
	// Return YES if the handle at a point is under another point. Subclasses that override -handleUnderPoint: can invoke this to hit-test the sort of handles that would be drawn by -drawHandleInView:atPoint:.
	func isHandle(at handlePoint: NSPoint, under point: NSPoint) -> Bool {
		// Check a handle-sized rectangle that's centered on the handle point.
		var handleBounds = NSZeroRect
		handleBounds.origin.x = handlePoint.x - SKTGraphicHandleHalfWidth;
		handleBounds.origin.y = handlePoint.y - SKTGraphicHandleHalfWidth;
		handleBounds.size.width = SKTGraphicHandleWidth;
		handleBounds.size.height = SKTGraphicHandleWidth;
		return NSPointInRect(point, handleBounds);
	}
	
	// Given that one of the receiver's handles has been dragged by the user, resize to match, and return the handle number that should be passed into subsequent invocations of this same method. The default implementation of this method assumes that the passed-in handle number was returned by a previous invocation of +creationSizingHandle or -handleUnderPoint:, so subclasses that override this should probably override +creationSizingHandle and -handleUnderPoint: too. It also invokes -flipHorizontally and -flipVertically when the user flips the graphic.
	func resizeByMovingHandle(shandle: Int, toPoint point: NSPoint) -> Int {
		var handle = shandle
		// Start with the original bounds.
		var bounds = self.bounds
		
		// Is the user changing the width of the graphic?
		if (handle == SKTGraphicUpperLeftHandle || handle == SKTGraphicMiddleLeftHandle || handle == SKTGraphicLowerLeftHandle) {
			
			// Change the left edge of the graphic.
			bounds.size.width = NSMaxX(bounds) - point.x;
			bounds.origin.x = point.x;
			
		} else if (handle==SKTGraphicUpperRightHandle || handle==SKTGraphicMiddleRightHandle || handle==SKTGraphicLowerRightHandle) {
			
			// Change the right edge of the graphic.
			bounds.size.width = point.x - bounds.origin.x;
			
		}
		
		// Did the user actually flip the graphic over?
		if (bounds.size.width < 0.0) {
			
			// The handle is now playing a different role relative to the graphic.
			//static NSInteger flippings[9];
			let flippings = [SKTGraphicUpperLeftHandle: SKTGraphicUpperRightHandle,
				SKTGraphicUpperMiddleHandle: SKTGraphicUpperMiddleHandle,
				SKTGraphicUpperRightHandle: SKTGraphicUpperLeftHandle,
				SKTGraphicMiddleLeftHandle: SKTGraphicMiddleRightHandle,
				SKTGraphicMiddleRightHandle: SKTGraphicMiddleLeftHandle,
				SKTGraphicMiddleRightHandle: SKTGraphicMiddleLeftHandle,
				SKTGraphicLowerLeftHandle: SKTGraphicLowerRightHandle,
				SKTGraphicLowerLeftHandle: SKTGraphicLowerRightHandle,
				SKTGraphicLowerMiddleHandle: SKTGraphicLowerMiddleHandle,
				SKTGraphicLowerRightHandle: SKTGraphicLowerLeftHandle]
			handle = flippings[handle]!;
			
			// Make the graphic's width positive again.
			bounds.size.width = 0.0 - bounds.size.width;
			bounds.origin.x -= bounds.size.width;
			
			// Tell interested subclass code what just happened.
			flipHorizontally()
			
		}
		
		// Is the user changing the height of the graphic?
		if (handle==SKTGraphicUpperLeftHandle || handle==SKTGraphicUpperMiddleHandle || handle==SKTGraphicUpperRightHandle) {
			
			// Change the top edge of the graphic.
			bounds.size.height = NSMaxY(bounds) - point.y;
			bounds.origin.y = point.y;
			
		} else if (handle==SKTGraphicLowerLeftHandle || handle==SKTGraphicLowerMiddleHandle || handle==SKTGraphicLowerRightHandle) {
			
			// Change the bottom edge of the graphic.
			bounds.size.height = point.y - bounds.origin.y;
			
		}
		
		// Did the user actually flip the graphic upside down?
		if (bounds.size.height < 0.0) {
			
			// The handle is now playing a different role relative to the graphic.
			let flippings = [SKTGraphicUpperLeftHandle: SKTGraphicLowerLeftHandle,
				SKTGraphicUpperMiddleHandle: SKTGraphicLowerMiddleHandle,
				SKTGraphicUpperRightHandle: SKTGraphicLowerRightHandle,
				SKTGraphicMiddleLeftHandle: SKTGraphicMiddleLeftHandle,
				SKTGraphicMiddleRightHandle: SKTGraphicMiddleRightHandle,
				SKTGraphicLowerLeftHandle: SKTGraphicUpperLeftHandle,
				SKTGraphicLowerMiddleHandle: SKTGraphicUpperMiddleHandle,
				SKTGraphicLowerRightHandle: SKTGraphicUpperRightHandle]
			handle = flippings[handle]!;
			
			// Make the graphic's height positive again.
			bounds.size.height = 0.0 - bounds.size.height;
			bounds.origin.y -= bounds.size.height;
			
			// Tell interested subclass code what just happened.
			flipVertically()
		}
		
		// Done.
		self.bounds = bounds

		return handle
	}
	
	// Given that -resizeByMovingHandle:toPoint: is being invoked and sensed that the user has flipped the graphic one way or the other, change the graphic to accomodate, whatever that means. Subclasses that represent asymmetrical graphics can override these to accomodate the user's dragging of handles without having to override and mostly reimplement -resizeByMovingHandle:toPoint:.
	func flipHorizontally() {
		// Live to be overridden.
	}
	
	func flipVertically() {
		// Live to be overridden.
	}
	
	// Given that [[self class] canMakeNaturalSize] would return YES, set the the bounds of the receiver to whatever is "natural" for its particular subclass of SKTGraphic. The default implementation of this method just squares the bounds.
	func makeNaturalSize() {
		// Just make the graphic square.
		var bounds = self.bounds;
		if (bounds.size.width < bounds.size.height) {
			bounds.size.height = bounds.size.width;
			self.bounds = bounds
		} else if (bounds.size.width>bounds.size.height) {
			bounds.size.width = bounds.size.height;
			self.bounds = bounds
		}
	}
	
	// Set the bounds of the graphic, doing whatever scaling and translation is necessary.
	
	// Set the color of the graphic, whatever that means. The default implementation of this method just sets isDrawingFill to YES and fillColor to the passed-in color. In Sketch this method is invoked when the user drops a color chip on the graphic or uses the color panel to change the color of all of the selected graphics.
	func setColor(color: NSColor) {
		// This method demonstrates something interesting: we haven't bothered to provide setter methods for the properties we want to change, but we can still change them using KVC. KVO autonotification will make sure observers hear about the change (it works with -setValue:forKey: as well as -set<Key>:). Of course, if we found ourselvings doing this a little more often we would go ahead and just add the setter methods. The point is that KVC direct instance variable access very often makes boilerplate accessors unnecessary but if you want to just put them in right away, eh, go ahead.
		
		// Can we fill the graphic?
		if self.canSetDrawingFill {
			// Are we filling it? If not, start, using the new color.
			if !self.drawingFill {
				setValue(true, forKey: SKTGraphicIsDrawingFillKey)
			}
			setValue(color, forKey: SKTGraphicFillColorKey)
		}
	}
	
	// Given that the receiver has just been created or double-clicked on or something, create and return a view that can present its editing interface to the user, or return nil. The returned view should be suitable for becoming a subview of a view whose bounds is passed in. Its frame should match the bounds of the receiver. The receiver should not assume anything about the lifetime of the returned editing view; it may remain in use even after subsequent invocations of this method, which should, again, create a new editing view each time. In other words, overrides of this method should be prepared for a graphic to have more than editing view outstanding. The default implementation of this method returns nil. In Sketch SKTText overrides it.
	func newEditingViewWithSuperviewBounds(superviewBounds: NSRect) -> NSView? {
		// Live to be overridden.
		return nil;
	}
	
	// Given an editing view that was returned by a previous invocation of -newEditingViewWithSuperviewBounds:, tear down whatever connections exist between it and the receiver.
	func finalizeEditingView(editingView: NSView) {
		// Live to be overridden.
	}
	
	// MARK: *** Undo ***
	
	// Return the keys of all of the properties for which value changes are undoable. In Sketch SKTDocument observes the value for each key in the set returned by invoking this method on each graphic in the document, and registers undo operations when the values change. It also observes this "keysForValuesToObserveForUndo" property itself and reacts accordingly, because the value can change dynamically. For example, SKTText overrides this (and KVO-notifies about changes to what the override would return) for a couple of reasons.
	var keysForValuesToObserveForUndo: NSSet {
		return NSSet(objects: SKTGraphicIsDrawingFillKey, SKTGraphicFillColorKey, SKTGraphicIsDrawingStrokeKey, SKTGraphicStrokeColorKey, SKTGraphicStrokeWidthKey, SKTGraphicBoundsKey)
	}
	
	// Given a key from the set returned by a previous invocation of -keysForValuesToObserveForUndo, return the human-readable, title-capitalized, localized, name of the property identified by the key, or nil for invalid keys (invokers should throw exceptions if nil is returned, because nil indicates a programming mistake). In Sketch SKTDocument uses this to create an undo action name when the user has changed the value of the property.
	class func presentablePropertyNameForKey(key: String) -> String? {
		// Pretty simple. Don't be surprised if you never see "Bounds" appear in an undo action name in Sketch. SKTGraphicView invokes -[NSUndoManager setActionName:] for things like moving, resizing, and aligning, thereby overwriting whatever SKTDocument sets with something more specific.
		let presentablePropertyNamesByKey = [SKTGraphicIsDrawingFillKey: NSLocalizedString("Filling", tableName: "UndoStrings", comment: "Action name part for SKTGraphicIsDrawingFillKey."),
			SKTGraphicFillColorKey: NSLocalizedString("Fill Color", tableName: "UndoStrings", comment: "Action name part for SKTGraphicFillColorKey."),
			SKTGraphicIsDrawingStrokeKey: NSLocalizedString("Stroking", tableName: "UndoStrings", comment: "Action name part for SKTGraphicIsDrawingStrokeKey."),
			SKTGraphicFillColorKey: NSLocalizedString("Stroke Color", tableName: "UndoStrings", comment: "Action name part for SKTGraphicStrokeColorKey."),
			SKTGraphicFillColorKey: NSLocalizedString("Stroke Width", tableName: "UndoStrings", comment: "Action name part for SKTGraphicStrokeWidthKey."),
			SKTGraphicFillColorKey: NSLocalizedString("Bounds", tableName: "UndoStrings", comment: "Action name part for SKTGraphicBoundsKey.")]
		return presentablePropertyNamesByKey[key];
	}
	
	// MARK: *** Scripting ***
	
	// Given that the receiver is now contained by some other object, or is no longer contained by another, take a pointer to its container, but do not retain it.
	weak var scriptingContainer: SKTGraphicScriptingContainer? = nil
	
	override var objectSpecifier: NSScriptObjectSpecifier? {
		var objectSpecifier = scriptingContainer?.objectSpecifierForGraphic(self)
		if objectSpecifier == nil {
			//[NSException raise:NSInternalInconsistencyException format:@"A scriptable graphic has no scriptable container, or one that doesn't implement -objectSpecifierForGraphic: correctly."];
		}
		return objectSpecifier;

	}
}
