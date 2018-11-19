//
//  SKTDocument.swift
//  Sketch
//
//  Created by C.W. Betts on 11/17/14.
//
//

import Cocoa

// Values that are used as contexts by this class' invocation of KVO observer registration methods. See the comment near the top of SKTGraphicView.m for a discussion of this.
private var SKTDocumentUndoKeysObservationContext: NSString = "com.apple.SKTDocument.undoKeys";
private var SKTDocumentUndoObservationContext: NSString = "com.apple.SKTDocument.undo";

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
	let mapTable = NSMapTable<NSObject, NSObject>(keyOptions: [], valueOptions: [], capacity: 0)
	
	init() {
		
	}
}

@objc(SKTDocument) class SKTDocument: NSDocument, SKTGraphicScriptingContainer {

	private var _undoGroupInsertedGraphics: Set<SKTGraphic>? = nil
	private var _undoGroupOldPropertiesPerGraphic: MapTableOwner? = nil
	private var _undoGroupPresentablePropertyName: String? = nil
	private var _undoGroupHasChangesToMultipleProperties = false
	
	/* This class is KVC and KVO compliant for these keys:
	
	"canvasSize" (an NSSize-containing NSValue; read-only) - The size of the document's canvas. This is derived from the currently selected paper size and document margins.
	
	"graphics" (an NSArray of SKTGraphics; read-write) - the graphics of the document.
	
	In Sketch the graphics property of each SKTGraphicView is bound to the graphics property of the document whose contents its presented. Also, the graphics relationship of an SKTDocument is scriptable.
	
	*/
	
	// Return the current value of the property.
	@objc dynamic var canvasSize: NSSize {
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
		NotificationCenter.default.addObserver(self, selector: #selector(SKTDocument.observeUndoManagerCheckpoint(_:)), name: .NSUndoManagerCheckpoint, object: undoManager)
	}
	
	@objc private func observeUndoManagerCheckpoint(_ notification: Notification) {
		// Start the coalescing of graphic property changes over.
		_undoGroupHasChangesToMultipleProperties = false;
		_undoGroupPresentablePropertyName = nil;
		_undoGroupOldPropertiesPerGraphic = nil;
		_undoGroupInsertedGraphics = nil;
	}
	
	deinit {
		// Undo some of what we did in -insertGraphics:atIndexes:.
		stopObservingGraphics(graphics)
		
		// Undo what we did in -init.
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSUndoManagerCheckpoint, object: undoManager)
	}
	
	// MARK: *** Private KVC-Compliance for Public Properties ***
	

	@objc(insertGraphics:atIndexes:)
	func insert(_ graphics: [SKTGraphic], at indexes: IndexSet) {
		for (graphic, i) in zip(graphics, indexes).reversed() {
			self.graphics.insert(graphic, at: i)
		}
		
		
		// For the purposes of scripting, every graphic has to point back to the document that contains it.
		for graphic in graphics {
			graphic.scriptingContainer = self
		}
		
		// Register an action that will undo the insertion.
		undoManager?.registerUndo(withTarget: self, selector: #selector(SKTDocument.removeGraphics(at:)), object: indexes)
		
		// Record the inserted graphics so we can filter out observer notifications from them. This way we don't waste memory registering undo operations for changes that wouldn't have any effect because the graphics are going to be removed anyway. In Sketch this makes a difference when you create a graphic and then drag the mouse to set its initial size right away. Why don't we do this if undo registration is disabled? Because we don't want to add to this set during document reading. (See what -readFromData:ofType:error: does with the undo manager.) That would ruin the undoability of the first graphic editing you do after reading a document.
		if let anUndo = undoManager {
			if anUndo.isUndoRegistrationEnabled {
				if _undoGroupInsertedGraphics != nil {
					_undoGroupInsertedGraphics!.formIntersection(graphics)
				} else {
					_undoGroupInsertedGraphics = Set(graphics)
				}
			}
		}
		
		// Start observing the just-inserted graphics so that, when they're changed, we can record undo operations.
		startObservingGraphics(graphics)
	}
	
	@objc(removeGraphicsAtIndexes:)
	func removeGraphics(at indexes: IndexSet) {
		// Find out what graphics are being removed. We lazily create the graphics array if necessary even though it should never be necessary, just so a helpful exception will be thrown if this method is being misused.
		let toRemoveArray = graphics.filter { (graphic) -> Bool in
			let index = self.graphics.firstIndex(of: graphic)!
			return indexes.contains(index)
		}
  
		// Stop observing the just-removed graphics to balance what was done in -insertGraphics:atIndexes:.
		stopObservingGraphics(toRemoveArray)
		
		// Register an action that will undo the removal. Do this before the actual removal so we don't have to worry about the releasing of the graphics that will be done.
		(undoManager?.prepare(withInvocationTarget: self) as AnyObject).insert(toRemoveArray, at: indexes)
		
		// For the purposes of scripting, every graphic had to point back to the document that contains it. Now they should stop that.
		for graphic in toRemoveArray {
			graphic.scriptingContainer = nil
		}

		// Do the actual removal.
		for i in indexes.reversed() {
			self.graphics.remove(at: i)
		}
	}
	
	@objc(insertGraphic:atIndex:)
	func insert(_ graphic: SKTGraphic, at index: Int) {
		// Just invoke the regular method up above.
		let graphics = [graphic]
		let indexes = IndexSet(integer: index)
		insert(graphics, at: indexes)
	}
	
	@objc(removeGraphicAtIndex:)
	func removeGraphic(at index: Int) {
		// Just invoke the regular method up above.
		let indexes = IndexSet(integer: index)
		removeGraphics(at: indexes)
	}
	
	@objc(addInGraphics:)
	func addIn(_ graphic: SKTGraphic) {
		// Just a convenience for invoking by some of the methods down below.
		insert(graphic, at: graphics.count)
	}
	
	func stopObservingGraphics(_ agraph: [SKTGraphic]) {
	}
	
	func startObservingGraphics(_ agraph: [SKTGraphic]) {
		// Each graphic can have a different set of properties that need to be observed.
		for graphic in agraph {
			let keys = graphic.keysForValuesToObserveForUndo
			for key in keys {
				// We use NSKeyValueObservingOptionOld because when something changes we want to record the old value, which is what has to be set in the undo operation. We use NSKeyValueObservingOptionNew because we compare the new value against the old value in an attempt to ignore changes that aren't really changes.
				graphic.addObserver(self, forKeyPath: key, options: [.new, .old], context: &SKTDocumentUndoObservationContext)
			}
			
			// The set of properties to be observed can itself change.
			graphic.addObserver(self, forKeyPath: SKTGraphicKeysForValuesToObserveForUndoKey, options: [.new, .old], context: &SKTDocumentUndoKeysObservationContext)
		}
	}
    /*
    override var windowNibName: String? {
        // Override returning the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
        return "SKTDocument"
    }
    */

    override func windowControllerDidLoadNib(_ aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        // Add any code here that needs to be executed once the windowController has loaded the document's window.
    }

	override func data(ofType typeName: String) throws -> Data {
		// This method must be prepared for typeName to be any value that might be in the array returned by any invocation of -writableTypesForSaveOperation:. Because this class:
		// doesn't - override -writableTypesForSaveOperation:, and
		// doesn't - override +writableTypes or +isNativeType: (which the default implementation of -writableTypesForSaveOperation: invokes),
		// and because:
		// - Sketch has a "Save a Copy As..." file menu item that results in NSSaveToOperations,
		// we know that that the type names we have to handle here include:
		// - SKTDocumentOldTypeName (on Mac OS 10.4) or SKTDocumentNewTypeName (on 10.5), because this application's Info.plist file declares that instances of this class can play the "editor" role for it, and
		// - NSPDFPboardType (on 10.4) or kUTTypePDF (on 10.5) and NSTIFFPboardType (on 10.4) or kUTTypeTIFF (on 10.5), because according to the Info.plist a Sketch document is exportable as them.
		// We use -[NSWorkspace type:conformsToType:] (new in 10.5), which is nearly always the correct thing to do with UTIs, but the arguments are reversed here compared to what's typical. Think about it: this method doesn't know how to write any particular subtype of the supported types, so it should assert if it's asked to. It does however effectively know how to write all of the supertypes of the supported types (like public.data), and there's no reason for it to refuse to do so. Not particularly useful in the context of an app like Sketch, but correct.
		// If we had reason to believe that +[SKTRenderingView pdfDataWithGraphics:] or +[SKTGraphic propertiesWithGraphics:] could return nil we would have to arrange for *outError to be set to a real value when that happens. If you signal failure in a method that takes an error: parameter and outError!=NULL you must set *outError to something decent.
		let printInfo = self.printInfo
		let workspace = NSWorkspace.shared
		if workspace.type(SKTDocumentNewTypeName, conformsToType: typeName) || typeName == SKTDocumentOldTypeName {
			var properties = [String: Any]()
			properties[SKTDocumentVersionKey] = SKTDocumentCurrentVersion
			properties[SKTDocumentGraphicsKey] = SKTGraphic.propertiesWithGraphics(graphics: graphics)
			properties[SKTDocumentPrintInfoKey] = NSArchiver.archivedData(withRootObject: printInfo)
			return try PropertyListSerialization.data(fromPropertyList: properties, format: .binary, options: 0)
		} else if workspace.type(kUTTypePDF as String, conformsToType: typeName) || typeName == NSPasteboard.PasteboardType.pdf.rawValue {
			return SKTRenderingView.pdfData(with: graphics)
		} else if workspace.type(kUTTypeTIFF as String, conformsToType: typeName) || typeName == NSPasteboard.PasteboardType.tiff.rawValue {
			return try SKTRenderingView.tiffData(with: graphics)
		}
		
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
	
	override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
        // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override class var autosavesInPlace: Bool {
        return true
    }
	
	override var printInfo: NSPrintInfo {
		willSet {
			willChangeValue(forKey: SKTDocumentCanvasSizeKey)
		}
		didSet {
			didChangeValue(forKey: SKTDocumentCanvasSizeKey)
		}
	}

	// MARK: scripting
	
	override func newScriptingObject(of objectClass2: AnyClass, forValueForKey key: String, withContentsValue contentsValue: Any?, properties: [String : Any]) -> Any? {
		var objectClass: AnyClass = objectClass2
		// "make new graphic" makes no sense because it's an abstract class. Use a default concrete class instead.
		if objectClass == SKTGraphic.self {
			objectClass = SKTCircle.self
		}
		return super.newScriptingObject(of: objectClass, forValueForKey: key, withContentsValue: contentsValue, properties: properties)
	}
	
	func objectSpecifier(for graphic: SKTGraphic) -> NSScriptObjectSpecifier? {
		var graphicObjectSpecifier: NSScriptObjectSpecifier? = nil
		
		if let graphicIndex = graphics.firstIndex(of: graphic) {
			if let keyClassDescription = self.objectSpecifier.keyClassDescription {
			graphicObjectSpecifier = NSIndexSpecifier(containerClassDescription: keyClassDescription, containerSpecifier: objectSpecifier, key: "graphics", index: graphicIndex)
			}
		}
		
		return graphicObjectSpecifier
	}
	
	var rectangles: [SKTRectangle] {
		return graphics.compactMap({
				return $0 as? SKTRectangle
				})
	}

	var circles: [SKTCircle] {
		return graphics.compactMap({
				return $0 as? SKTCircle
				})
	}

	var lines: [SKTLine] {
		return graphics.compactMap({
				return $0 as? SKTLine
				})
	}

	var textAreas: [SKTText] {
		return graphics.compactMap({
				return $0 as? SKTText
				})
	}

	var images: [SKTImage] {
		return graphics.compactMap({
				return $0 as? SKTImage
				})
	}
}
