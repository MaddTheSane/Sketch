//
//  SKTImage.swift
//  Sketch
//
//  Created by C.W. Betts on 10/26/14.
//
//

import Cocoa

// String constants declared in the header. They may not be used by any other class in the project, but it's a good idea to provide and use them, if only to help prevent typos in source code.
let SKTImageIsFlippedHorizontallyKey = "flippedHorizontally";
let SKTImageIsFlippedVerticallyKey = "flippedVertically";
let SKTImageFilePathKey = "filePath";

// Another key, which is just used in persistent property dictionaries.
private let SKTImageContentsKey = "contents";


@objc(SKTImage) final class SKTImage: SKTGraphic, NSCopying {
	private var flippedHorizontally = false
	private var flippedVertically = false
	private(set) var contents: NSImage
	
	override var drawingFill: Bool {
	get {
		return false
	}
set {

}
}
	
	override var drawingStroke: Bool {
	get {
		return false
	}
set {

}
	}
	
	func setFilePath(filePath: String) {
		// If there's a transformed version of the contents being held as a cache, it's invalid now.
		if let newContents = NSImage(contentsOfFile: filePath.stringByStandardizingPath) {
			contents = newContents;
		}
	}
	
	func canSetDrawingFill() -> Bool {
	// Don't let the user think we would even try to fill an image with color.
		return false
	}
	
	
	func canSetDrawingStroke() -> Bool {
	// Don't let the user think we would even try to draw a stroke on image.
	return false;
	}

	
	init(position: NSPoint, contents aContents: NSImage) {
		contents = aContents
		
		super.init()
		let contentsSize = contents.size
		self.bounds = NSRect(origin: CGPoint(x: position.x - (contentsSize.width / 2.0), y: position.y - (contentsSize.height / 2.0)), size: contentsSize)
	}
	
	override func copyWithZone(zone: NSZone) -> AnyObject {
		// Do the regular Cocoa thing.
		let copy = super.copyWithZone(zone) as SKTImage
		copy.contents = contents.copy() as NSImage
		return copy
	}
	
	required init() {
		contents = NSImage()
		
		super.init()
	}
	
	required init(properties: [NSObject : AnyObject]) {
		if let contentData = properties[SKTImageContentsKey] as? NSData {
			if let otherContents = NSUnarchiver.unarchiveObjectWithData(contentData) as? NSImage {
				contents = otherContents
			} else {
				contents = NSImage()
			}
		} else {
			contents = NSImage()
		}
		if let flippedHorizNumber = properties[SKTImageIsFlippedHorizontallyKey] as? NSNumber as? Bool {
			flippedHorizontally = flippedHorizNumber
		}
		if let flippedVertNumber = properties[SKTImageIsFlippedVerticallyKey] as? NSNumber as? Bool {
			flippedVertically = flippedVertNumber
		}
		
		
		super.init(properties: properties)
	}
	
	override func flipHorizontally() {
		self.flippedHorizontally = !flippedHorizontally
	}
	
	override func flipVertically() {
		self.flippedVertically = !flippedVertically
	}
	
	override func makeNaturalSize() {
		var bounds = self.bounds
		bounds.size = contents.size
		self.bounds = bounds
		flippedHorizontally = false
		flippedVertically = false
	}
	
	override var keysForValuesToObserveForUndo: NSSet {
		var ourSet = NSMutableSet(set: super.keysForValuesToObserveForUndo)
		ourSet.addObjectsFromArray([SKTImageIsFlippedHorizontallyKey, SKTImageIsFlippedVerticallyKey])
		return ourSet
	}
	
	override class func presentablePropertyNameForKey(key: String) -> String? {
		let presentablePropertyNamesByKey = [SKTImageIsFlippedHorizontallyKey: NSLocalizedString("Horizontal Flipping", tableName: "UndoStrings", comment: "Action name part for SKTImageIsFlippedHorizontallyKey."),
			SKTImageIsFlippedVerticallyKey: NSLocalizedString("Vertical Flipping", tableName: "UndoStrings", comment: "Action name part for SKTImageIsFlippedVerticallyKey.")]
		var presentablePropertyName = presentablePropertyNamesByKey[key]
		if presentablePropertyName == nil {
			presentablePropertyName = super.presentablePropertyNameForKey(key)
		}
		return presentablePropertyName
	}
	
	override func drawContentsInView(view: NSView, isBeingCreateOrEdited isBeingCreatedOrEditing: Bool) {
		var bounds = self.bounds
		if self.drawingFill {
			fillColor?.set()
			NSRectFill(bounds)
		}
		
		// Surprisingly, NSImage's -draw... methods don't take into account whether or not the view is flipped. In Sketch, SKTGraphicViews are flipped (and this model class is not supposed to have dependencies on the oddities of any particular view class anyway). So, just do our own transformation matrix manipulation.
		var transform = NSAffineTransform()
		
		// Translating to actually place the image (as opposed to translating as part of flipping).
		transform.translateXBy(bounds.origin.x, yBy: bounds.origin.y)

		// Flipping according to the user's wishes.
		transform.translateXBy(flippedHorizontally ? bounds.size.width : 0.0, yBy: flippedVertically ? bounds.size.height : 0.0)
		transform.scaleXBy(flippedHorizontally ? -1 : 1, yBy: flippedVertically ? -1 : 1)
		
		// Scaling to actually size the image (as opposed to scaling as part of flipping).
		var contentsSize = self.contents.size
		transform.scaleXBy(bounds.size.width / contentsSize.width, yBy: bounds.size.height / contentsSize.height)
		
		// Flipping to accomodate -[NSImage drawAtPoint:fromRect:operation:fraction:]'s odd behavior.
		if view.flipped {
			transform.translateXBy(0, yBy: contentsSize.height)
			transform.scaleXBy(1, yBy: -1)
		}
		
		// Do the actual drawing, saving and restoring the graphics state so as not to interfere with the drawing of selection handles or anything else in the same view.
		NSGraphicsContext.currentContext()?.saveGraphicsState()
		transform.concat()
		contents.drawAtPoint(NSZeroPoint, fromRect: NSRect(origin: NSZeroPoint, size: contentsSize), operation: .CompositeSourceOver, fraction: 1)
		NSGraphicsContext.currentContext()?.restoreGraphicsState()
		
	}

}
