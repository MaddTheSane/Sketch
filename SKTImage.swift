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


@objc(SKTImage) final class SKTImage: SKTGraphic {
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
		if let newContents = NSImage(contentsOfFile: (filePath as NSString).standardizingPath) {
			contents = newContents;
		}
	}
	
	override var canSetDrawingFill: Bool {
	// Don't let the user think we would even try to fill an image with color.
		return false
	}
	
	
	override var canSetDrawingStroke: Bool {
	// Don't let the user think we would even try to draw a stroke on image.
	return false;
	}

	@objc
	init(position: NSPoint, contents aContents: NSImage) {
		contents = aContents
		
		super.init()
		let contentsSize = contents.size
		self.bounds = NSRect(origin: CGPoint(x: position.x - (contentsSize.width / 2.0), y: position.y - (contentsSize.height / 2.0)), size: contentsSize)
	}
	
	override func copy(with zone: NSZone? = nil) -> Any {
		// Do the regular Cocoa thing.
		let copy = super.copy(with: zone) as! SKTImage
		copy.contents = contents.copy() as! NSImage
		return copy
	}
	
	required init() {
		contents = NSImage()
		
		super.init()
	}
	
	required init(properties: [String : Any]) {
		if let contentData = properties[SKTImageContentsKey] as? Data {
			if let otherContents = NSUnarchiver.unarchiveObject(with: contentData) as? NSImage {
				contents = otherContents
			} else {
				contents = NSImage()
			}
		} else {
			contents = NSImage()
		}
		if let flippedHorizNumber = properties[SKTImageIsFlippedHorizontallyKey] as? Bool {
			flippedHorizontally = flippedHorizNumber
		}
		if let flippedVertNumber = properties[SKTImageIsFlippedVerticallyKey] as? Bool {
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
	
	override var keysForValuesToObserveForUndo: Set<String> {
		var ourSet = super.keysForValuesToObserveForUndo
		ourSet.formIntersection([SKTImageIsFlippedHorizontallyKey, SKTImageIsFlippedVerticallyKey])
		return ourSet
	}
	
	override class func presentablePropertyName(for key: String) -> String? {
		let presentablePropertyNamesByKey = [SKTImageIsFlippedHorizontallyKey: NSLocalizedString("Horizontal Flipping", tableName: "UndoStrings", comment: "Action name part for SKTImageIsFlippedHorizontallyKey."),
			SKTImageIsFlippedVerticallyKey: NSLocalizedString("Vertical Flipping", tableName: "UndoStrings", comment: "Action name part for SKTImageIsFlippedVerticallyKey.")]
		var presentablePropertyName = presentablePropertyNamesByKey[key]
		if presentablePropertyName == nil {
			presentablePropertyName = super.presentablePropertyName(for: key)
		}
		return presentablePropertyName
	}
	
	override func drawContents(in view: NSView?, isBeingCreateOrEdited isBeingCreatedOrEditing: Bool) {
		let bounds = self.bounds
		if self.drawingFill {
			fillColor?.set()
			NSRectFill(bounds)
		}
		
		// Surprisingly, NSImage's -draw... methods don't take into account whether or not the view is flipped. In Sketch, SKTGraphicViews are flipped (and this model class is not supposed to have dependencies on the oddities of any particular view class anyway). So, just do our own transformation matrix manipulation.
		var transform = AffineTransform()
		
		// Translating to actually place the image (as opposed to translating as part of flipping).
		transform.translate(x: bounds.origin.x, y: bounds.origin.y)

		// Flipping according to the user's wishes.
		transform.translate(x: flippedHorizontally ? bounds.size.width : 0.0, y: flippedVertically ? bounds.size.height : 0.0)
		transform.scale(x: flippedHorizontally ? -1 : 1, y: flippedVertically ? -1 : 1)
		
		// Scaling to actually size the image (as opposed to scaling as part of flipping).
		let contentsSize = self.contents.size
		transform.scale(x: bounds.size.width / contentsSize.width, y: bounds.size.height / contentsSize.height)
		
		// Flipping to accomodate -[NSImage drawAtPoint:fromRect:operation:fraction:]'s odd behavior.
		if view?.isFlipped ?? false {
			transform.translate(x: 0, y: contentsSize.height)
			transform.scale(x: 1, y: -1)
		}
		
		// Do the actual drawing, saving and restoring the graphics state so as not to interfere with the drawing of selection handles or anything else in the same view.
		NSGraphicsContext.current()?.saveGraphicsState()
		(transform as NSAffineTransform).concat()
		contents.draw(at: .zero, from: NSRect(origin: .zero, size: contentsSize), operation: .sourceOver, fraction: 1)
		NSGraphicsContext.current()?.restoreGraphicsState()
		
	}

}
