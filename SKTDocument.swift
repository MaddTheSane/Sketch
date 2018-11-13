//
//  SKTDocument.swift
//  Sketch
//
//  Created by C.W. Betts on 11/17/14.
//
//

import Cocoa

// Values that are used as contexts by this class' invocation of KVO observer registration methods. See the comment near the top of SKTGraphicView.m for a discussion of this.
private let SKTDocumentUndoKeysObservationContext = "com.apple.SKTDocument.undoKeys";
private let SKTDocumentUndoObservationContext = "com.apple.SKTDocument.undo";

// The document type names that must also be used in the application's Info.plist file. We'll take out all uses of SKTDocumentOldTypeName and SKTDocumentOldVersion1TypeName (and NSPDFPboardType and NSTIFFPboardType) someday when we drop 10.4 compatibility and we can just use UTIs everywhere.
private let SKTDocumentOldTypeName = "Apple Sketch document";
private let SKTDocumentNewTypeName = "com.apple.sketch2";
private let SKTDocumentOldVersion1TypeName = "Apple Sketch 1 document";
private let SKTDocumentNewVersion1TypeName = "com.apple.sketch1";

// More keys, and a version number, which are just used in Sketch's property-list-based file format.
private let SKTDocumentVersionKey = "version";
private let SKTDocumentPrintInfoKey = "printInfo";
private let SKTDocumentCurrentVersion = 2;


private class MapTableOwner {
	let mapTable = NSMapTable(keyOptions: NSPointerFunctionsStrongMemory, valueOptions: NSPointerFunctionsStrongMemory, capacity: 0)
	
	init() {
		
	}
}

@objc(SKTDocument) class SKTDocument: NSDocument, SKTGraphicScriptingContainer {

	private var _undoGroupInsertedGraphics: NSMutableSet? = nil
	
	/* This class is KVC and KVO compliant for these keys:
	
	"canvasSize" (an NSSize-containing NSValue; read-only) - The size of the document's canvas. This is derived from the currently selected paper size and document margins.
	
	"graphics" (an NSArray of SKTGraphics; read-write) - the graphics of the document.
	
	In Sketch the graphics property of each SKTGraphicView is bound to the graphics property of the document whose contents its presented. Also, the graphics relationship of an SKTDocument is scriptable.
	
	*/
	
	// Return the current value of the property.
	var canvasSize: NSSize {
		// A Sketch's canvas size is the size of the piece of paper that the user selects in the Page Setup panel for it, minus the document margins that are set.
		let printInfo = self.printInfo
		var tmpCanvasSize = printInfo.paperSize
		tmpCanvasSize.width -= printInfo.leftMargin + printInfo.rightMargin
		tmpCanvasSize.height -= printInfo.topMargin + printInfo.bottomMargin
		return tmpCanvasSize
	}
	
	var graphics = [SKTGraphic]()
	
	override init() {
		super.init()
		
		// Before anything undoable happens, register for a notification we need.
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "observeUndoManagerCheckpoint:", name: NSUndoManagerCheckpointNotification, object: undoManager)
	}
	
	deinit {
		// Undo some of what we did in -insertGraphics:atIndexes:.
		stopObservingGraphics(graphics)
		
		// Undo what we did in -init.
		NSNotificationCenter.defaultCenter().removeObserver(self, name: NSUndoManagerCheckpointNotification, object: undoManager)
	}
	
	// MARK: *** Private KVC-Compliance for Public Properties ***
	

	func insertGraphics(graphics: [SKTGraphic], atIndexes indexes: NSIndexSet) {
		var idx = graphics.endIndex
		for var i = indexes.lastIndex; i != NSNotFound; i = indexes.indexLessThanIndex(i) {
			self.graphics.insert(graphics[--idx], atIndex: i)
		}
		
		
		// For the purposes of scripting, every graphic has to point back to the document that contains it.
		for graphic in graphics {
			graphic.scriptingContainer = self
		}
		
		// Register an action that will undo the insertion.
		undoManager?.registerUndoWithTarget(self, selector: "removeGraphicsAtIndexes:", object: indexes)
		
		// Record the inserted graphics so we can filter out observer notifications from them. This way we don't waste memory registering undo operations for changes that wouldn't have any effect because the graphics are going to be removed anyway. In Sketch this makes a difference when you create a graphic and then drag the mouse to set its initial size right away. Why don't we do this if undo registration is disabled? Because we don't want to add to this set during document reading. (See what -readFromData:ofType:error: does with the undo manager.) That would ruin the undoability of the first graphic editing you do after reading a document.
		if let anUndo = undoManager {
			if anUndo.undoRegistrationEnabled {
				if let undoGroup = _undoGroupInsertedGraphics {
					undoGroup.addObjectsFromArray(graphics)
				} else {
					_undoGroupInsertedGraphics = NSMutableSet(array: graphics)
				}
			}
		}
		
		// Start observing the just-inserted graphics so that, when they're changed, we can record undo operations.
		startObservingGraphics(graphics)
	}
	
	func removeGraphicsAtIndexes(indexes: NSIndexSet) {
		// Find out what graphics are being removed. We lazily create the graphics array if necessary even though it should never be necessary, just so a helpful exception will be thrown if this method is being misused.
		let toRemoveArray = graphics.filter { (graphic) -> Bool in
			let index = find(self.graphics, graphic)!
			return indexes.containsIndex(index)
		}
  
		// Stop observing the just-removed graphics to balance what was done in -insertGraphics:atIndexes:.
		stopObservingGraphics(toRemoveArray)
		
		// Register an action that will undo the removal. Do this before the actual removal so we don't have to worry about the releasing of the graphics that will be done.
		undoManager?.prepareWithInvocationTarget(self).insertGraphics(toRemoveArray, atIndexes: indexes)
		
		// For the purposes of scripting, every graphic had to point back to the document that contains it. Now they should stop that.
		for graphic in toRemoveArray {
			graphic.scriptingContainer = nil
		}

		// Do the actual removal.
		for var i = indexes.lastIndex; i != NSNotFound; i = indexes.indexLessThanIndex(i) {
			self.graphics.removeAtIndex(i)
		}
	}
	
	func stopObservingGraphics(agraph: [SKTGraphic]) {
	}
	
	func startObservingGraphics(agraph: [SKTGraphic]) {
	}
    /*
    override var windowNibName: String? {
        // Override returning the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
        return "SKTDocument"
    }
    */

    override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        // Add any code here that needs to be executed once the windowController has loaded the document's window.
    }

    override func dataOfType(typeName: String, error outError: NSErrorPointer) -> NSData? {
        // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        outError.memory = NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        return nil
    }
    
    override func readFromData(data: NSData, ofType typeName: String, error outError: NSErrorPointer) -> Bool {
        // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
        // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
        outError.memory = NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        return false
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }

	func objectSpecifierForGraphic(graphic: SKTGraphic) -> NSScriptObjectSpecifier? {
		var graphicObjectSpecifier: NSScriptObjectSpecifier? = nil
		
		if let graphicIndex = find(graphics, graphic) {
			if let keyClassDescription = self.objectSpecifier.keyClassDescription {
			graphicObjectSpecifier = NSIndexSpecifier(containerClassDescription: keyClassDescription, containerSpecifier: objectSpecifier, key: "graphics", index: graphicIndex)
			}
		}
		
		return graphicObjectSpecifier
	}
	
	var rectangles: [SKTRectangle] {
		return graphics.filter({
				return $0 is SKTRectangle
				}) as [SKTRectangle]
	}

	var circles: [SKTCircle] {
		return graphics.filter({
				return $0 is SKTCircle
				}) as [SKTCircle]
	}

	var lines: [SKTLine] {
		return graphics.filter({
				return $0 is SKTLine
				}) as [SKTLine]
	}

	var textAreas: [SKTText] {
		return graphics.filter({
				return $0 is SKTText
				}) as [SKTText]
	}

	var images: [SKTImage] {
		return graphics.filter({
				return $0 is SKTImage
				}) as [SKTImage]
	}

}
