//
//  SKTText.swift
//  Sketch
//
//  Created by C.W. Betts on 10/26/14.
//
//

import Cocoa

// String constants declared in the header. They may not be used by any other class in the project, but it's a good idea to provide and use them, if only to help prevent typos in source code.
let SKTTextScriptingContentsKey = "scriptingContents";
let SKTTextUndoContentsKey = "undoContents";

// A key that's used in Sketch's property-list-based file and pasteboard formats.
let SKTTextContentsKey = "contents";


private var layoutManager: NSLayoutManager = {
	var textContainer = NSTextContainer(containerSize: NSSize(width: 1.0e7, height: 1.0e7))
	let layoutManager = NSLayoutManager()
	textContainer.widthTracksTextView = false
	textContainer.heightTracksTextView = false
	layoutManager.addTextContainer(textContainer)

	return layoutManager
}()

@objc(SKTText) final class SKTText: SKTGraphic, NSTextStorageDelegate {
	private var _contents: NSTextStorage? = nil
	private var boundsBeingChangedToMatchContents = false
	private var contentsBeingChangedByScripting = false
	
	var contents: NSTextStorage {
		if _contents == nil {
			_contents = NSTextStorage()
			
			_contents?.delegate = self
		}
		return _contents!
	}
	
	deinit {
		_contents?.delegate = nil
	}
	
	override func copy(with zone: NSZone? = nil) -> Any {
		// Sending -copy or -mutableCopy to an NSTextStorage results in an NSAttributedString or NSMutableAttributedString, so we have to do something a little different. We go through [copy contents] to make sure delegation gets set up properly, and [self contents] to easily ensure we're not passing nil to -setAttributedString:.
		let copy = super.copy(with: zone) as! SKTText
		copy.contents.setAttributedString(self.contents)
		return copy;
	}
	
	class var sharedLayoutManager: NSLayoutManager {
		return layoutManager
	}
	
	var naturalSize: NSSize {
		// Figure out how big this graphic would have to be to show all of its contents. -glyphRangeForTextContainer: forces layout.
		let bounds = self.bounds
		let layoutManager = type(of: self).sharedLayoutManager
		let textContainer = layoutManager.textContainers[0] as NSTextContainer
		textContainer.containerSize = NSSize(width: bounds.size.width, height: 1.0e7)
		let contents = self.contents
		contents.addLayoutManager(layoutManager)
		layoutManager.glyphRange(for: textContainer)
		let naturalSize = layoutManager.usedRect(for: textContainer).size
		contents.removeLayoutManager(layoutManager)
		return naturalSize
	}
	
	override var bounds: NSRect {
		didSet {
			if !boundsBeingChangedToMatchContents {
				let layoutManagers = self.contents.layoutManagers
				for layoutManager in layoutManagers as [NSLayoutManager] {
					layoutManager.firstTextView?.frame = self.bounds
				}
			}
		}
	}
	
	func setHeightToMatchContents() {
		// Update the bounds of this graphic to match the height of the text. Make sure that doesn't result in the registration of a spurious undo action.
		// There might be a noticeable performance win to be had during editing by making this object a delegate of the text views it creates, implementing -[NSObject(NSTextDelegate) textDidChange:], and using information that's already calculated by the editing text view instead of invoking -makeNaturalSize like this.
		self.willChangeValue(forKey: SKTGraphicKeysForValuesToObserveForUndoKey)
		boundsBeingChangedToMatchContents = true
		self.didChangeValue(forKey: SKTGraphicKeysForValuesToObserveForUndoKey)
		let bounds = self.bounds
		let naturalSize = self.naturalSize
		self.bounds = NSRect(origin: bounds.origin, size: NSSize(width: bounds.size.width, height: naturalSize.height))
		self.willChangeValue(forKey: SKTGraphicKeysForValuesToObserveForUndoKey)
		boundsBeingChangedToMatchContents = false;
		self.didChangeValue(forKey: SKTGraphicKeysForValuesToObserveForUndoKey)
	}
	
	func textStorageDidProcessEditing(notification: NSNotification) {
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
			self.setHeightToMatchContents()
		}
	}
	
	// MARK: Private KVC-Compliance for Public Properties
	
	func willChangeScriptingContents() {
		// Tell any object that would observe this one to record undo operations to start observing. In Sketch, each SKTDocument is observing all of its graphics' "keysForValuesToObserveForUndo" values.
		self.willChangeValue(forKey: SKTGraphicKeysForValuesToObserveForUndoKey)
		contentsBeingChangedByScripting = true
		self.didChangeValue(forKey: SKTGraphicKeysForValuesToObserveForUndoKey)
		
		// Do the first part of notifying observers. It's OK if no changes are actually done by scripting before the matching invocation of -didChangeValueForKey:. Key-value observers aren't allowed to assume that every observer notification is about a real change (that's why the KVO notification method's name starts with -observeValueForKeyPath:, not -observeChangeOfValueForKeyPath:).
		self.willChangeValue(forKey: SKTTextUndoContentsKey)
	}
	
	func didChangeScriptingContents() {
		// Any changes that might have been done by the scripting command are done.
		self.didChangeValue(forKey: SKTTextUndoContentsKey)
		
		// Tell observers to stop observing to record undo operations.
		// This isn't strictly necessary in Sketch: we could just let the SKTDocument keep observing, because we know that no other objects are observing "undoContents." Partial KVO-compliance like this that only works some of the time is a dangerous game though, and it's a good idea to be very explicit about it. This class is very explictily only KVO-compliant for "undoContents" while -keysForValuesToObserveForUndo is returning a set that contains "undoContents."
		self.willChangeValue(forKey: SKTGraphicKeysForValuesToObserveForUndoKey)
		contentsBeingChangedByScripting = false
		self.didChangeValue(forKey: SKTGraphicKeysForValuesToObserveForUndoKey)
	}
	
	var scriptingContents: AnyObject {
		get {
		// Before returning an NSTextStorage that Cocoa's scripting support can work with, do the first part of notifying observers, and then schedule the second part of notifying observers for after all potential scripted changes caused by the current scripting command have been done.
		// An alternative to the way we notify key-value observers here would be to return an NSTextStorage that's a proxy to the one held by this object, and make it send this object the -willChangeValueForKey:/-didChangeValueForKey: messages around forwarding of mutation messages (sort of like what the collection proxy objects returned by KVC for sets and arrays do), but that wouldn't gain us anything as far as we know right now, and might even lead to performance problems (because one scripting command could result in potentially many KVO notifications).
		willChangeScriptingContents()
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
				self.didChangeScriptingContents()
			}
		return self.contents
		}
		set {
			// If an attributed string is passed then then do a simple replacement. If a string is passed in then reuse the character style that's already there. Either way, we must notify observers of "undoContents" that its value is changing here.
			// By the way, if this method actually changed the value of _contents we would have to move any layout managers attached to the old value of _contents to the new value, so as not to break editing if it's being done at this moment.
			willChangeScriptingContents()
			let contents = self.contents
			let allContentsRange = NSMakeRange(0, contents.length);
			if let stringNewValue = newValue as? NSAttributedString {
				contents.replaceCharacters(in: allContentsRange, with: stringNewValue)
			} else {
				contents.replaceCharacters(in: allContentsRange, with: newValue.description)
			}
			didChangeScriptingContents()
		}
	}

	@objc(coerceValueForScriptingContents:)
	func coerceValue(forScriptingContents contents: Any) -> Any? {
		var coercedContents: Any?
		if let strContents = contents as? String {
			coercedContents = strContents
		} else {
			coercedContents = NSScriptCoercionHandler.shared().coerceValue(contents, to: NSTextStorage.self)
		}
		return coercedContents
	}
	
	var undoContents: NSAttributedString {
		get {
		// Never return an object whose value will change after it's been returned. This is generally good behavior for any getter method that returns the value of an attribute or a to-many relationship. (For to-one relationships just returning the related object is the right thing to do, as in this class' -contents method.) However, this particular implementation of this good behavior might not be fast enough for all situations. If the copying here causes a performance problem, an alternative might be to return [[contents retain] autorelease], set a bit that indicates that the contents should be lazily replaced with a copy before any mutation, and then heed that bit in other methods of this class.
		return self.contents.copy() as! NSAttributedString
		}
		set {
			// When undoing a change that could have only been done by scripting, behave exactly if scripting is doing another change, for the benefit of redo.
			self.scriptingContents = newValue
		}
	}
	
	// MARK: Overrides of SKTGraphic Methods
	required init(properties: [String : Any]) {
		super.init(properties: properties)
		if let data = properties[SKTTextContentsKey] as? Data {
			if let textContents = NSUnarchiver.unarchiveObject(with: data) as? NSTextStorage {
				_contents = textContents
				
				_contents!.delegate = self
			}
		}
	}
	
	required init() {
		super.init()
	}

	override var properties: [String: Any] {
		// Let SKTGraphic do its job and then handle the one additional property defined by this subclass. The dictionary must contain nothing but values that can be written in old-style property lists.
		var properties = super.properties
		properties[SKTTextContentsKey] = NSArchiver.archivedData(withRootObject: contents)
		return properties;
	}
	
	override var drawingStroke: Bool {
		get {return false}
		set {}
	}
	
	override var drawingBounds: NSRect {
		get {
		// The drawing bounds must take into account the focus ring that might be drawn by this class' override of -drawContentsInView:isBeingCreatedOrEdited:. It can't forget to take into account drawing done by -drawHandleInView:atPoint: though. Because this class doesn't override -drawHandleInView:atPoint:, it should invoke super to let SKTGraphic take care of that, and then alter the results.
		return NSUnionRect(super.drawingBounds, NSInsetRect(self.bounds, -1.0, -1.0))
		}
		set {}
	}
	
	override func drawContents(in view: NSView, isBeingCreateOrEdited isBeingCreatedOrEditing: Bool) {
		// Draw the fill color if appropriate.
		let bounds = self.bounds;
		if (self.drawingFill) {
			self.fillColor?.set()
			NSRectFill(bounds);
		}
		
		// If this graphic is being created it has no text. If it is being edited then the editor returned by -newEditingViewWithSuperviewBounds: will draw the text.
		if (isBeingCreatedOrEditing) {
			
			// Just draw a focus ring.
			NSColor.knobColor.set()
			NSFrameRect(NSInsetRect(bounds, -1.0, -1.0));
			
		} else {
			
			// Don't bother doing anything if there isn't actually any text.
			let contents = self.contents
			if contents.length > 0 {
				
				// Get a layout manager, size its text container, and use it to draw text. -glyphRangeForTextContainer: forces layout and tells us how much of text fits in the container.
				let layoutManager = type(of: self).sharedLayoutManager;
				let textContainer = layoutManager.textContainers[0] as NSTextContainer
				textContainer.containerSize = bounds.size
				contents.addLayoutManager(layoutManager)
				let glyphRange = layoutManager.glyphRange(for: textContainer) ;
				if glyphRange.length > 0 {
					layoutManager.drawBackground(forGlyphRange: glyphRange, at: bounds.origin)
					layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: bounds.origin)
				}
				contents.removeLayoutManager(layoutManager)
			}
		}
		
	}
	
	override func makeNaturalSize() {
		let bounds = self.bounds
		let naturalSize = self.naturalSize
		
		self.bounds = NSRect(origin: bounds.origin, size: naturalSize)
	}
	
	override func newEditingViewWithSuperviewBounds(_ superviewBounds: NSRect) -> NSView? {
		// Create a text view that has the same frame as this graphic. We use -[NSTextView initWithFrame:textContainer:] instead of -[NSTextView initWithFrame:] because the latter method creates the entire collection of objects associated with an NSTextView - its NSTextContainer, NSLayoutManager, and NSTextStorage - and we already have an NSTextStorage. The text container should be the width of this graphic but very high to accomodate whatever text is typed into it.
		let bounds = self.bounds;
		let textContainer = NSTextContainer(containerSize: NSSize(width: bounds.size.width, height: 1.0e7))
		let textView = NSTextView(frame: bounds, textContainer: textContainer)
		
		// Create a layout manager that will manage the communication between our text storage and the text container, and hook it up.
		let layoutManager = NSLayoutManager()
		layoutManager.addTextContainer(textContainer)
		let contents = self.contents
		contents.addLayoutManager(layoutManager)
		
		// Of course text editing should be as undoable as anything else.
		textView.allowsUndo = true
		
		// This kind of graphic shouldn't appear opaque just because it's being edited.
		textView.drawsBackground = false
		
		/*
		// This is has been handy for debugging text editing view size problems though.
		[textView setBackgroundColor:[NSColor greenColor]];
		[textView setDrawsBackground:YES];
		*/
		
		// Start off with the all of the text selected.
		textView.setSelectedRange(NSRange(location: 0, length: contents.length))
		
		// Specify that the text view should grow and shrink to fit the text as text is added and removed, but only in the vertical direction. With these settings the NSTextView will always be large enough to show an extra line fragment but never so large that the user won't be able to see just-typed text on the screen. Sending -setVerticallyResizable:YES to the text view without also sending -setMinSize: or -setMaxSize: would be useless by the way; the default minimum and maximum sizes of a text view are the size of the frame that is specified at initialization time.
		textView.minSize = NSSize(width: bounds.size.width, height: 0)
		textView.maxSize = NSSize(width: bounds.size.width, height: superviewBounds.size.height - bounds.origin.y)
		textView.isVerticallyResizable = true
		
		// The invoker doesn't have to release this object.
		return textView;
		
	}
	
	override var canSetDrawingStroke: Bool {
		return false
	}

	override func finalize(editingView: NSView) {
		// Tell our text storage that it doesn't have to talk to the editing view's layout manager anymore.
		if let textEditingView = editingView as? NSTextView {
			if let layoutManager = textEditingView.layoutManager {
				self.contents.removeLayoutManager(layoutManager)
			}
		}
	}
	
	override var keysForValuesToObserveForUndo: Set<String> {
		// Observation of "undoContents," and the observer's resulting registration of changes with the undo manager, is only valid when changes are made to text contents via scripting. When changes are made directly by the user in a text view the text view will register better, more specific, undo actions. Also, we don't want some changes of bounds to result in undo actions.
		var keys = super.keysForValuesToObserveForUndo
		if (contentsBeingChangedByScripting || boundsBeingChangedToMatchContents) {
			if (contentsBeingChangedByScripting) {
				keys.insert(SKTTextUndoContentsKey)
			}
			if (boundsBeingChangedToMatchContents) {
				keys.insert(SKTGraphicBoundsKey)
			}
		}
		return keys
	}
	
	override class func presentablePropertyName(for key: String?) -> String? {
		if let aKey = key {
			let presentablePropertyNamesByKey = [SKTTextUndoContentsKey : NSLocalizedString("Text", tableName: "UndoStrings",  comment: "Action name part for SKTTextUndoContentsKey.")]
			var presentablePropertyString = presentablePropertyNamesByKey[aKey]
			if presentablePropertyString == nil {
				presentablePropertyString = super.presentablePropertyName(for: aKey)
			}
			
			return presentablePropertyString
		} else {
			return nil
		}
	}
}
