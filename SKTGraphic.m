
/*
     File: SKTGraphic.m
 Abstract: The base class for Sketch graphics objects.
 
 This class is KVC (except for "drawingContents") and KVO (except for the scripting-only properties) compliant for these keys:
 
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
 
 
  Version: 1.8
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 
 */

#import "SKTGraphic.h"
#import "SKTError.h"


// String constants declared in the header. A lot of them aren't used by any other class in the project, but it's a good idea to provide and use them, if only to help prevent typos in source code.
// Why are there @"drawingFill" and @"drawingStroke" keys here when @"isDrawingFill" and @"isDrawingStroke" would be a little more consistent with Cocoa convention for boolean values? Because we might want to add setter methods for these properties some day, and key-value coding isn't smart enough to ignore "is" when looking for setter methods, and having to give methods ugly names -setIsDrawingFill: and -setIsDrawingStroke: would be irritating. In general it's best to leave the "is" off the front of keys that identify boolean values.
NSString *SKTGraphicCanSetDrawingFillKey = @"canSetDrawingFill";
NSString *SKTGraphicCanSetDrawingStrokeKey = @"canSetDrawingStroke";
NSString *SKTGraphicIsDrawingFillKey = @"drawingFill";
NSString *SKTGraphicFillColorKey = @"fillColor";
NSString *SKTGraphicIsDrawingStrokeKey = @"drawingStroke";
NSString *SKTGraphicStrokeColorKey = @"strokeColor";
NSString *SKTGraphicStrokeWidthKey = @"strokeWidth";
NSString *SKTGraphicXPositionKey = @"xPosition";
NSString *SKTGraphicYPositionKey = @"yPosition";
NSString *SKTGraphicWidthKey = @"width";
NSString *SKTGraphicHeightKey = @"height";
NSString *SKTGraphicBoundsKey = @"bounds";
NSString *SKTGraphicDrawingBoundsKey = @"drawingBounds";
NSString *SKTGraphicDrawingContentsKey = @"drawingContents";
NSString *SKTGraphicKeysForValuesToObserveForUndoKey = @"keysForValuesToObserveForUndo";

// Another constant that's declared in the header.
const NSInteger SKTGraphicNoHandle = 0;

// A key that's used in Sketch's property-list-based file and pasteboard formats.
static NSString *SKTGraphicClassNameKey = @"className";

// The values that might be returned by -[SKTGraphic creationSizingHandle] and -[SKTGraphic handleUnderPoint:], and that are understood by -[SKTGraphic resizeByMovingHandle:toPoint:]. We provide specific indexes in this enumeration so make sure none of them are zero (that's SKTGraphicNoHandle) and to make sure the flipping arrays in -[SKTGraphic resizeByMovingHandle:toPoint:] work.
/*enum {
    SKTGraphicUpperLeftHandle = 1,
    SKTGraphicUpperMiddleHandle = 2,
    SKTGraphicUpperRightHandle = 3,
    SKTGraphicMiddleLeftHandle = 4,
    SKTGraphicMiddleRightHandle = 5,
    SKTGraphicLowerLeftHandle = 6,
    SKTGraphicLowerMiddleHandle = 7,
    SKTGraphicLowerRightHandle = 8,
};*/

// The handles that graphics draw on themselves are 6 point by 6 point rectangles.
CGFloat SKTGraphicHandleWidth = 6.0f;
CGFloat SKTGraphicHandleHalfWidth = 6.0f / 2.0f;


@implementation SKTGraphic


// An override of the superclass' designated initializer.
- (id)init {

    // Do the regular Cocoa thing.
    self = [super init];
    if (self) {
	
	// Set up decent defaults for a new graphic.
	_bounds = NSZeroRect;
	_isDrawingFill = NO;
	_fillColor = [NSColor whiteColor];
	_isDrawingStroke = YES;
	_strokeColor = [NSColor blackColor];
	_strokeWidth = 1.0f;
	
    }
    return self;
    
}


// Conformance to the NSCopying protocol. SKTGraphics are copyable for the sake of scriptability.
- (id)copyWithZone:(NSZone *)zone {

    // Pretty simple, but there's plenty of opportunity for mistakes. We use [self class] instead of SKTGraphic so that overrides of this method can invoke super. We copy instead of retaining the fill and stroke color even though it probably doesn't make a difference because that's the correct thing to do for attributes (to-one relationships, that's another story). We don't copy _scriptingContainer because the copy doesn't have any scripting container until it's added to one.
    SKTGraphic *copy = [[[self class] alloc] init];
    copy->_bounds = _bounds;
    copy->_isDrawingFill = _isDrawingFill;
    copy->_fillColor = [_fillColor copy];
    copy->_isDrawingStroke = _isDrawingStroke;
    copy->_strokeColor = [_strokeColor copy];
    copy->_strokeWidth = _strokeWidth;
    return copy;

}


#pragma mark *** Private KVC-Compliance for Public Properties ***


// An override of the NSObject(NSKeyValueObservingCustomization) method.
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {

    // We don't want KVO autonotification for these properties. Because the setters for all of them invoke -setBounds:, and this class is KVO-compliant for "bounds," and we declared that the values of these properties depend on "bounds," we would up end up with double notifications for them. That would probably be unnoticable, but it's a little wasteful. Something you have to think about with codependent mutable properties like these (regardless of what notification mechanism you're using).
    BOOL automaticallyNotifies;
    if ([[NSSet setWithObjects:SKTGraphicXPositionKey, SKTGraphicYPositionKey, SKTGraphicWidthKey, SKTGraphicHeightKey, nil] containsObject:key]) {
	automaticallyNotifies = NO;
    } else {
	automaticallyNotifies = [super automaticallyNotifiesObserversForKey:key];
    }
    return automaticallyNotifies;

}


// In Mac OS 10.5 and newer KVO's dependency mechanism invokes class methods to find out what properties affect properties being observed, like these.
+ (NSSet *)keyPathsForValuesAffectingXPosition {
    return [NSSet setWithObject:SKTGraphicBoundsKey];
}
+ (NSSet *)keyPathsForValuesAffectingYPosition {
    return [NSSet setWithObject:SKTGraphicBoundsKey];
}
+ (NSSet *)keyPathsForValuesAffectingWidth {
    return [NSSet setWithObject:SKTGraphicBoundsKey];
}
+ (NSSet *)keyPathsForValuesAffectingHeight {
    return [NSSet setWithObject:SKTGraphicBoundsKey];
}
- (CGFloat)xPosition {
    return [self bounds].origin.x;
}
- (CGFloat)yPosition {
    return [self bounds].origin.y;
}
- (CGFloat)width {
    return [self bounds].size.width;
}
- (CGFloat)height {
    return [self bounds].size.height;
}
- (void)setXPosition:(CGFloat)xPosition {
    NSRect bounds = [self bounds];
    bounds.origin.x = xPosition;
    [self setBounds:bounds];
}
- (void)setYPosition:(CGFloat)yPosition {
    NSRect bounds = [self bounds];
    bounds.origin.y = yPosition;
    [self setBounds:bounds];
}
- (void)setWidth:(CGFloat)width {
    NSRect bounds = [self bounds];
    bounds.size.width = width;
    [self setBounds:bounds];
}
- (void)setHeight:(CGFloat)height {
    NSRect bounds = [self bounds];
    bounds.size.height = height;
    [self setBounds:bounds];
}


#pragma mark *** Convenience ***


+ (NSRect)boundsOfGraphics:(NSArray *)graphics {

    // The bounds of an array of graphics is the union of all of their bounds.
    NSRect bounds = NSZeroRect;
    NSUInteger graphicCount = [graphics count];
    if (graphicCount>0) {
	bounds = [graphics[0] bounds];
	for (NSUInteger index = 1; index<graphicCount; index++) {
            bounds = NSUnionRect(bounds, [graphics[index] bounds]);
	}
    }
    return bounds;

}


+ (NSRect)drawingBoundsOfGraphics:(NSArray *)graphics {

    // The drawing bounds of an array of graphics is the union of all of their drawing bounds.
    NSRect drawingBounds = NSZeroRect;
    NSUInteger graphicCount = [graphics count];
    if (graphicCount>0) {
	drawingBounds = [graphics[0] drawingBounds];
	for (NSUInteger index = 1; index<graphicCount; index++) {
            drawingBounds = NSUnionRect(drawingBounds, [graphics[index] drawingBounds]);
	}
    }
    return drawingBounds;

}


+ (void)translateGraphics:(NSArray *)graphics byX:(CGFloat)deltaX y:(CGFloat)deltaY {

    // Pretty simple.
    NSUInteger graphicCount = [graphics count];
    for (NSUInteger index = 0; index<graphicCount; index++) {
	SKTGraphic *graphic = graphics[index];
	[graphic setBounds:NSOffsetRect([graphic bounds], deltaX, deltaY)];
    }

}


#pragma mark *** Persistence ***


+ (NSArray *)graphicsWithPasteboardData:(NSData *)data error:(NSError **)outError {

    // Because this data may have come from outside this process, don't assume that any property list object we get back is the right type.
    NSArray *graphics = nil;
    NSArray *propertiesArray = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:outError];
    if (![propertiesArray isKindOfClass:[NSArray class]]) {
	propertiesArray = nil;
    }
    if (propertiesArray) {

	// Convert the array of graphic property dictionaries into an array of graphics.
	graphics = [self graphicsWithProperties:propertiesArray];

    } else if (outError) {

	// If property list parsing fails we have no choice but to admit that we don't know what went wrong. The error description returned by +[NSPropertyListSerialization propertyListFromData:mutabilityOption:format:errorDescription:] would be pretty technical, and not the sort of thing that we should show to a user.
	*outError = SKTErrorWithCode(SKTErrorUnknownPasteboardRead);

    }
    return graphics;

}


+ (NSArray *)graphicsWithProperties:(NSArray *)propertiesArray {

    // Convert the array of graphic property dictionaries into an array of graphics. Again, don't assume that property list objects are the right type.
    NSUInteger graphicCount = [propertiesArray count];
    NSMutableArray *graphics = [[NSMutableArray alloc] initWithCapacity:graphicCount];
    for (NSUInteger index = 0; index<graphicCount; index++) {
	NSDictionary *properties = propertiesArray[index];
	if ([properties isKindOfClass:[NSDictionary class]]) {

	    // Figure out the class of graphic to instantiate. The value of the SKTGraphicClassNameKey entry must be an Objective-C class name. Don't trust the type of something you get out of a property list unless you know your process created it or it was read from your application or framework's resources.
	    NSString *className = properties[SKTGraphicClassNameKey];
	    if ([className isKindOfClass:[NSString class]]) {
		Class class = NSClassFromString(className);
			if (!class && [className isEqualToString:@"SKTTextArea"]) {
				class = NSClassFromString(@"SKTText");
			}
		if (class) {

		    // Create a new graphic. If it doesn't work then just do nothing. We could return an NSError, but doing things this way 1) means that a user might be able to rescue graphics from a partially corrupted document, and 2) is easier.
		    SKTGraphic *graphic = [[class alloc] initWithProperties:properties];
		    if (graphic) {
			[graphics addObject:graphic];
		    }

		}

	    }

	}
    }
    return graphics;

}


+ (NSData *)pasteboardDataWithGraphics:(NSArray *)graphics {

    // Convert the contents of the document to a property list and then flatten the property list.
    return [NSPropertyListSerialization dataFromPropertyList:[self propertiesWithGraphics:graphics] format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];

}


+ (NSArray *)propertiesWithGraphics:(NSArray *)graphics {

    // Convert the array of graphics dictionaries into an array of graphic property dictionaries.
    NSUInteger graphicCount = [graphics count];
    NSMutableArray *propertiesArray = [[NSMutableArray alloc] initWithCapacity:graphicCount];
    for (NSUInteger index = 0; index<graphicCount; index++) {
	SKTGraphic *graphic = graphics[index];

	// Get the properties of the graphic, add the class name that can be used by +graphicsWithProperties: to it, and add the properties to the array we're building.
	NSMutableDictionary *properties = [graphic properties];
	properties[SKTGraphicClassNameKey] = NSStringFromClass([graphic class]);
	[propertiesArray addObject:properties];

    }
    return propertiesArray;

}


- (instancetype)initWithProperties:(NSDictionary *)properties {

    // Invoke the designated initializer.
    self = [self init];
    if (self) {

	// The dictionary entries are all instances of the classes that can be written in property lists. Don't trust the type of something you get out of a property list unless you know your process created it or it was read from your application or framework's resources. We don't have to worry about KVO-compliance in initializers like this by the way; no one should be observing an unitialized object.
	Class dataClass = [NSData class];
	Class numberClass = [NSNumber class];
	Class stringClass = [NSString class];
	NSString *boundsString = properties[SKTGraphicBoundsKey];
	if ([boundsString isKindOfClass:stringClass]) {
	    _bounds = NSRectFromString(boundsString);
	}
	NSNumber *isDrawingFillNumber = properties[SKTGraphicIsDrawingFillKey];
	if ([isDrawingFillNumber isKindOfClass:numberClass]) {
	    _isDrawingFill = [isDrawingFillNumber boolValue];
	}
	NSData *fillColorData = properties[SKTGraphicFillColorKey];
	if ([fillColorData isKindOfClass:dataClass]) {
	    _fillColor = [NSUnarchiver unarchiveObjectWithData:fillColorData];
	}
	NSNumber *isDrawingStrokeNumber = properties[SKTGraphicIsDrawingStrokeKey];
	if ([isDrawingStrokeNumber isKindOfClass:numberClass]) {
	    _isDrawingStroke = [isDrawingStrokeNumber boolValue];
	}
	NSData *strokeColorData = properties[SKTGraphicStrokeColorKey];
	if ([strokeColorData isKindOfClass:dataClass]) {
	    _strokeColor = [NSUnarchiver unarchiveObjectWithData:strokeColorData];
	}
	NSNumber *strokeWidthNumber = properties[SKTGraphicStrokeWidthKey];
	if ([strokeWidthNumber isKindOfClass:numberClass]) {
	    _strokeWidth = [strokeWidthNumber doubleValue];
	}

    }
    return self;

}


- (NSMutableDictionary *)properties {

    // Return a dictionary that contains nothing but values that can be written in property lists.
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    properties[SKTGraphicBoundsKey] = NSStringFromRect([self bounds]);
    properties[SKTGraphicIsDrawingFillKey] = @([self isDrawingFill]);
    NSColor *fillColor = [self fillColor];
    if (fillColor) {
        properties[SKTGraphicFillColorKey] = [NSArchiver archivedDataWithRootObject:fillColor];
    }
    properties[SKTGraphicIsDrawingStrokeKey] = @([self isDrawingStroke]);
    NSColor *strokeColor = [self strokeColor];
    if (strokeColor) {
        properties[SKTGraphicStrokeColorKey] = [NSArchiver archivedDataWithRootObject:strokeColor];
    }
    properties[SKTGraphicStrokeWidthKey] = @([self strokeWidth]);
    return properties;

}


#pragma mark *** Simple Property Getting ***

@synthesize bounds = _bounds;
@synthesize drawingFill = _isDrawingFill;
@synthesize fillColor = _fillColor;
@synthesize drawingStroke = _isDrawingStroke;
@synthesize strokeColor = _strokeColor;
@synthesize strokeWidth = _strokeWidth;


#pragma mark *** Drawing ***


+ (NSSet *)keyPathsForValuesAffectingDrawingBounds {
    
    // The only properties managed by SKTGraphic that affect the drawing bounds are the bounds and the the stroke width.
    return [NSSet setWithObjects:SKTGraphicBoundsKey, SKTGraphicStrokeWidthKey, nil];

}


+ (NSSet *)keyPathsForValuesAffectingDrawingContents {
    
    // The only properties managed by SKTGraphic that affect drawing but not the drawing bounds are the fill and stroke parameters.
    return [NSSet setWithObjects:SKTGraphicIsDrawingFillKey, SKTGraphicFillColorKey, SKTGraphicIsDrawingStrokeKey, SKTGraphicStrokeColorKey, nil];
    
}


- (NSRect)drawingBounds {

    // Assume that -[SKTGraphic drawContentsInView:] and -[SKTGraphic drawHandlesInView:] will be doing the drawing. Start with the plain bounds of the graphic, then take drawing of handles at the corners of the bounds into account, then optional stroke drawing.
    CGFloat outset = SKTGraphicHandleHalfWidth;
    if ([self isDrawingStroke]) {
	CGFloat strokeOutset = [self strokeWidth] / 2.0f;
	if (strokeOutset>outset) {
	    outset = strokeOutset;
	}
    }
    CGFloat inset = 0.0f - outset;
    NSRect drawingBounds = NSInsetRect([self bounds], inset, inset);
    
    // -drawHandleInView:atPoint: draws a one-unit drop shadow too.
    drawingBounds.size.width += 1.0f;
    drawingBounds.size.height += 1.0f;
    return drawingBounds;

}


- (void)drawContentsInView:(NSView *)view isBeingCreateOrEdited:(BOOL)isBeingCreatedOrEditing {

    // If the graphic is so so simple that it can be boiled down to a bezier path then just draw a bezier path. It's -bezierPathForDrawing's responsibility to return a path with the current stroke width.
    NSBezierPath *path = [self bezierPathForDrawing];
    if (path) {
	if ([self isDrawingFill]) {
	    [[self fillColor] set];
	    [path fill];
	}
	if ([self isDrawingStroke]) {
	    [[self strokeColor] set];
	    [path stroke];
	}
    }

}

- (NSBezierPath *)bezierPathForDrawing {
    
    // Live to be overriden.
    [NSException raise:NSInternalInconsistencyException format:@"Neither -drawContentsInView: nor -bezierPathForDrawing has been overridden."];
    return nil;
    
}


- (void)drawHandlesInView:(NSView *)view {

    // Draw handles at the corners and on the sides.
    NSRect bounds = [self bounds];
    [self drawHandleInView:view atPoint:NSMakePoint(NSMinX(bounds), NSMinY(bounds))];
    [self drawHandleInView:view atPoint:NSMakePoint(NSMidX(bounds), NSMinY(bounds))];
    [self drawHandleInView:view atPoint:NSMakePoint(NSMaxX(bounds), NSMinY(bounds))];
    [self drawHandleInView:view atPoint:NSMakePoint(NSMinX(bounds), NSMidY(bounds))];
    [self drawHandleInView:view atPoint:NSMakePoint(NSMaxX(bounds), NSMidY(bounds))];
    [self drawHandleInView:view atPoint:NSMakePoint(NSMinX(bounds), NSMaxY(bounds))];
    [self drawHandleInView:view atPoint:NSMakePoint(NSMidX(bounds), NSMaxY(bounds))];
    [self drawHandleInView:view atPoint:NSMakePoint(NSMaxX(bounds), NSMaxY(bounds))];

}


- (void)drawHandleInView:(NSView *)view atPoint:(NSPoint)point {

    // Figure out a rectangle that's centered on the point but lined up with device pixels.
    NSRect handleBounds;
    handleBounds.origin.x = point.x - SKTGraphicHandleHalfWidth;
    handleBounds.origin.y = point.y - SKTGraphicHandleHalfWidth;
    handleBounds.size.width = SKTGraphicHandleWidth;
    handleBounds.size.height = SKTGraphicHandleWidth;
    handleBounds = [view centerScanRect:handleBounds];
    
    // Draw the shadow of the handle.
    NSRect handleShadowBounds = NSOffsetRect(handleBounds, 1.0f, 1.0f);
    [[NSColor controlDarkShadowColor] set];
    NSRectFill(handleShadowBounds);

    // Draw the handle itself.
    [[NSColor knobColor] set];
    NSRectFill(handleBounds);

}


#pragma mark *** Editing ***


+ (NSCursor *)creationCursor {

    // By default we use the crosshairs cursor.
    static NSCursor *crosshairsCursor = nil;
    if (!crosshairsCursor) {
        NSImage *crosshairsImage = [NSImage imageNamed:@"Cross"];
        NSSize crosshairsImageSize = [crosshairsImage size];
        crosshairsCursor = [[NSCursor alloc] initWithImage:crosshairsImage hotSpot:NSMakePoint((crosshairsImageSize.width / 2.0), (crosshairsImageSize.height / 2.0))];
    }
    return crosshairsCursor;

}


+ (NSInteger)creationSizingHandle {

    // Return the number of the handle for the lower-right corner. If the user drags it so that it's no longer in the lower-right, -resizeByMovingHandle:toPoint: will deal with it.
    return SKTGraphicLowerRightHandle;

}


- (BOOL)canSetDrawingFill {

    // The default implementation of -drawContentsInView: can draw fills.
    return YES;

}


- (BOOL)canSetDrawingStroke {

    // The default implementation of -drawContentsInView: can draw strokes.
    return YES;

}


- (BOOL)canMakeNaturalSize {

    // Only return YES if -makeNaturalSize would actually do something.
    NSRect bounds = [self bounds];
    return bounds.size.width!=bounds.size.height;

}


- (BOOL)isContentsUnderPoint:(NSPoint)point {

    // Just check against the graphic's bounds.
    return NSPointInRect(point, [self bounds]);

}


- (NSInteger)handleUnderPoint:(NSPoint)point {
    
    // Check handles at the corners and on the sides.
    NSInteger handle = SKTGraphicNoHandle;
    NSRect bounds = [self bounds];
    if ([self isHandleAtPoint:NSMakePoint(NSMinX(bounds), NSMinY(bounds)) underPoint:point]) {
	handle = SKTGraphicUpperLeftHandle;
    } else if ([self isHandleAtPoint:NSMakePoint(NSMidX(bounds), NSMinY(bounds)) underPoint:point]) {
	handle = SKTGraphicUpperMiddleHandle;
    } else if ([self isHandleAtPoint:NSMakePoint(NSMaxX(bounds), NSMinY(bounds)) underPoint:point]) {
	handle = SKTGraphicUpperRightHandle;
    } else if ([self isHandleAtPoint:NSMakePoint(NSMinX(bounds), NSMidY(bounds)) underPoint:point]) {
	handle = SKTGraphicMiddleLeftHandle;
    } else if ([self isHandleAtPoint:NSMakePoint(NSMaxX(bounds), NSMidY(bounds)) underPoint:point]) {
	handle = SKTGraphicMiddleRightHandle;
    } else if ([self isHandleAtPoint:NSMakePoint(NSMinX(bounds), NSMaxY(bounds)) underPoint:point]) {
	handle = SKTGraphicLowerLeftHandle;
    } else if ([self isHandleAtPoint:NSMakePoint(NSMidX(bounds), NSMaxY(bounds)) underPoint:point]) {
	handle = SKTGraphicLowerMiddleHandle;
    } else if ([self isHandleAtPoint:NSMakePoint(NSMaxX(bounds), NSMaxY(bounds)) underPoint:point]) {
	handle = SKTGraphicLowerRightHandle;
    }
    return handle;

}


- (BOOL)isHandleAtPoint:(NSPoint)handlePoint underPoint:(NSPoint)point {
    
    // Check a handle-sized rectangle that's centered on the handle point.
    NSRect handleBounds;
    handleBounds.origin.x = handlePoint.x - SKTGraphicHandleHalfWidth;
    handleBounds.origin.y = handlePoint.y - SKTGraphicHandleHalfWidth;
    handleBounds.size.width = SKTGraphicHandleWidth;
    handleBounds.size.height = SKTGraphicHandleWidth;
    return NSPointInRect(point, handleBounds);

}


- (NSInteger)resizeByMovingHandle:(NSInteger)handle toPoint:(NSPoint)point {

    // Start with the original bounds.
    NSRect bounds = [self bounds];

    // Is the user changing the width of the graphic?
    if (handle==SKTGraphicUpperLeftHandle || handle==SKTGraphicMiddleLeftHandle || handle==SKTGraphicLowerLeftHandle) {

	// Change the left edge of the graphic.
        bounds.size.width = NSMaxX(bounds) - point.x;
        bounds.origin.x = point.x;

    } else if (handle==SKTGraphicUpperRightHandle || handle==SKTGraphicMiddleRightHandle || handle==SKTGraphicLowerRightHandle) {

	// Change the right edge of the graphic.
        bounds.size.width = point.x - bounds.origin.x;

    }

    // Did the user actually flip the graphic over?
    if (bounds.size.width<0.0f) {

	// The handle is now playing a different role relative to the graphic.
	static NSInteger flippings[9];
	static BOOL flippingsInitialized = NO;
	if (!flippingsInitialized) {
	    flippings[SKTGraphicUpperLeftHandle] = SKTGraphicUpperRightHandle;
	    flippings[SKTGraphicUpperMiddleHandle] = SKTGraphicUpperMiddleHandle;
	    flippings[SKTGraphicUpperRightHandle] = SKTGraphicUpperLeftHandle;
	    flippings[SKTGraphicMiddleLeftHandle] = SKTGraphicMiddleRightHandle;
	    flippings[SKTGraphicMiddleRightHandle] = SKTGraphicMiddleLeftHandle;
	    flippings[SKTGraphicLowerLeftHandle] = SKTGraphicLowerRightHandle;
	    flippings[SKTGraphicLowerMiddleHandle] = SKTGraphicLowerMiddleHandle;
	    flippings[SKTGraphicLowerRightHandle] = SKTGraphicLowerLeftHandle;
	    flippingsInitialized = YES;
	}
        handle = flippings[handle];

	// Make the graphic's width positive again.
        bounds.size.width = 0.0f - bounds.size.width;
        bounds.origin.x -= bounds.size.width;

	// Tell interested subclass code what just happened.
        [self flipHorizontally];

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
    if (bounds.size.height<0.0f) {

	// The handle is now playing a different role relative to the graphic.
	static NSInteger flippings[9];
	static BOOL flippingsInitialized = NO;
	if (!flippingsInitialized) {
	    flippings[SKTGraphicUpperLeftHandle] = SKTGraphicLowerLeftHandle;
	    flippings[SKTGraphicUpperMiddleHandle] = SKTGraphicLowerMiddleHandle;
	    flippings[SKTGraphicUpperRightHandle] = SKTGraphicLowerRightHandle;
	    flippings[SKTGraphicMiddleLeftHandle] = SKTGraphicMiddleLeftHandle;
	    flippings[SKTGraphicMiddleRightHandle] = SKTGraphicMiddleRightHandle;
	    flippings[SKTGraphicLowerLeftHandle] = SKTGraphicUpperLeftHandle;
	    flippings[SKTGraphicLowerMiddleHandle] = SKTGraphicUpperMiddleHandle;
	    flippings[SKTGraphicLowerRightHandle] = SKTGraphicUpperRightHandle;
	    flippingsInitialized = YES;
	}
        handle = flippings[handle];
	
	// Make the graphic's height positive again.
        bounds.size.height = 0.0f - bounds.size.height;
        bounds.origin.y -= bounds.size.height;

	// Tell interested subclass code what just happened.
        [self flipVertically];

    }

    // Done.
    [self setBounds:bounds];
    return handle;

}


- (void)flipHorizontally {
    
    // Live to be overridden.

}


- (void)flipVertically {
    
    // Live to be overridden.

}


- (void)makeNaturalSize {

    // Just make the graphic square.
    NSRect bounds = [self bounds];
    if (bounds.size.width<bounds.size.height) {
        bounds.size.height = bounds.size.width;
        [self setBounds:bounds];
    } else if (bounds.size.width>bounds.size.height) {
        bounds.size.width = bounds.size.height;
        [self setBounds:bounds];
    }
    
}


- (void)setColor:(NSColor *)color {

    // This method demonstrates something interesting: we haven't bothered to provide setter methods for the properties we want to change, but we can still change them using KVC. KVO autonotification will make sure observers hear about the change (it works with -setValue:forKey: as well as -set<Key>:). Of course, if we found ourselvings doing this a little more often we would go ahead and just add the setter methods. The point is that KVC direct instance variable access very often makes boilerplate accessors unnecessary but if you want to just put them in right away, eh, go ahead.

    // Can we fill the graphic?
    if ([self canSetDrawingFill]) {

	// Are we filling it? If not, start, using the new color.
	if (![self isDrawingFill]) {
	    [self setValue:@YES forKey:SKTGraphicIsDrawingFillKey];
	}
	[self setValue:color forKey:SKTGraphicFillColorKey];

    }

}


- (NSView *)newEditingViewWithSuperviewBounds:(NSRect)superviewBounds {
    
    // Live to be overridden.
    return nil;

}


- (void)finalizeEditingView:(NSView *)editingView {
    
    // Live to be overridden.
    
}


#pragma mark *** Undo ***


- (NSSet *)keysForValuesToObserveForUndo {

    // Of the properties managed by SKTGraphic, "drawingingBounds," "drawingContents," "canSetDrawingFill," and "canSetDrawingStroke" aren't anything that the user changes, so changes of their values aren't registered undo operations. "xPosition," "yPosition," "width," and "height" are all derived from "bounds," so we don't need to register those either. Changes of any other property are undoable.
    return [NSSet setWithObjects:SKTGraphicIsDrawingFillKey, SKTGraphicFillColorKey, SKTGraphicIsDrawingStrokeKey, SKTGraphicStrokeColorKey, SKTGraphicStrokeWidthKey, SKTGraphicBoundsKey, nil];

}


+ (NSString *)presentablePropertyNameForKey:(NSString *)key {
    
    // Pretty simple. Don't be surprised if you never see "Bounds" appear in an undo action name in Sketch. SKTGraphicView invokes -[NSUndoManager setActionName:] for things like moving, resizing, and aligning, thereby overwriting whatever SKTDocument sets with something more specific.
    static NSDictionary *presentablePropertyNamesByKey = nil;
    if (!presentablePropertyNamesByKey) {
	presentablePropertyNamesByKey = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
	    NSLocalizedStringFromTable(@"Filling", @"UndoStrings", @"Action name part for SKTGraphicIsDrawingFillKey."), SKTGraphicIsDrawingFillKey,
	    NSLocalizedStringFromTable(@"Fill Color", @"UndoStrings",@"Action name part for SKTGraphicFillColorKey."), SKTGraphicFillColorKey,
	    NSLocalizedStringFromTable(@"Stroking", @"UndoStrings", @"Action name part for SKTGraphicIsDrawingStrokeKey."), SKTGraphicIsDrawingStrokeKey,
	    NSLocalizedStringFromTable(@"Stroke Color", @"UndoStrings", @"Action name part for SKTGraphicStrokeColorKey."), SKTGraphicStrokeColorKey,
	    NSLocalizedStringFromTable(@"Stroke Width", @"UndoStrings", @"Action name part for SKTGraphicStrokeWidthKey."), SKTGraphicStrokeWidthKey,
	    NSLocalizedStringFromTable(@"Bounds", @"UndoStrings", @"Action name part for SKTGraphicBoundsKey."), SKTGraphicBoundsKey,
	    nil];
    }
    return presentablePropertyNamesByKey[key];

}


#pragma mark *** Scripting ***

@synthesize scriptingContainer = _scriptingContainer;
- (void)setScriptingContainer:(id <SKTGraphicScriptingContainer>)scriptingContainer {

    // Don't retain the container. It's supposed to be retaining this object.
    _scriptingContainer = scriptingContainer;

}


// Conformance to the NSObject(NSScriptObjectSpecifiers) informal protocol.
- (NSScriptObjectSpecifier *)objectSpecifier {

    // This object can't create an object specifier for itself, so ask its scriptable container to do it.
    NSScriptObjectSpecifier *objectSpecifier = [_scriptingContainer objectSpecifierForGraphic:self];
    if (!objectSpecifier) {
	[NSException raise:NSInternalInconsistencyException format:@"A scriptable graphic has no scriptable container, or one that doesn't implement -objectSpecifierForGraphic: correctly."];
    }
    return objectSpecifier;

}


- (NSColor *)scriptingFillColor {

    // Return nil if the graphic is not filled. The scripter will see that as "missing value."
    return [self isDrawingFill] ? [self fillColor] : nil;

}


- (NSColor *)scriptingStrokeColor {

    // Return nil if the graphic is not stroked. The scripter will see that as "missing value."
    return [self isDrawingStroke] ? [self strokeColor] : nil;

}


- (NSNumber *)scriptingStrokeWidth {

    // Return nil if the graphic is not stroked. The scripter will see that as "missing value."
    return [self isDrawingStroke] ? @([self strokeWidth]) : nil;

}


- (void)setScriptingFillColor:(NSColor *)fillColor {

    // See the comment in -setColor: about using KVC like we do here.

    // For the convenience of scripters, turn filling on or off if necessary, if that's allowed. Don't forget that -isDrawingFill can return YES or NO regardless of what -canSetDrawingFill is returning.
    if (fillColor) {
	BOOL canSetFillColor = YES;
	if (![self isDrawingFill]) {
	    if ([self canSetDrawingFill]) {
		[self setValue:@YES forKey:SKTGraphicIsDrawingFillKey];
	    } else {

		// Not allowed. Tell the scripter what happened.
		NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
		[currentScriptCommand setScriptErrorNumber:errAEEventFailed];
		[currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't set the fill color of this kind of graphic.", @"SKTGraphic", @"A scripting error message.")];
		canSetFillColor = NO;

	    }
	}
	if (canSetFillColor) {
	    [self setValue:fillColor forKey:SKTGraphicFillColorKey];
	}
    } else {
	if ([self isDrawingFill]) {
	    if ([self canSetDrawingFill]) {
		[self setValue:@NO forKey:SKTGraphicIsDrawingFillKey];
	    } else {

		// Not allowed. Tell the scripter what happened.
		NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
		[currentScriptCommand setScriptErrorNumber:errAEEventFailed];
		[currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't remove the fill from this kind of graphic.", @"SKTGraphic", @"A scripting error message.")];

	    }
	}
    }

}


// The same as above, but for stroke color instead of fill color.
- (void)setScriptingStrokeColor:(NSColor *)strokeColor {
    if (strokeColor) {
	BOOL canSetStrokeColor = YES;
	if (![self isDrawingStroke]) {
	    if ([self canSetDrawingStroke]) {
		[self setValue:@YES forKey:SKTGraphicIsDrawingStrokeKey];
	    } else {
		NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
		[currentScriptCommand setScriptErrorNumber:errAEEventFailed];
		[currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't set the stroke color of this kind of graphic.", @"SKTGraphic", @"A scripting error message.")];
		canSetStrokeColor = NO;
	    }
	}
	if (canSetStrokeColor) {
	    [self setValue:strokeColor forKey:SKTGraphicStrokeColorKey];
	}
    } else {
	if ([self isDrawingStroke]) {
	    if ([self canSetDrawingStroke]) {
		[self setValue:@NO forKey:SKTGraphicIsDrawingStrokeKey];
	    } else {
		NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
		[currentScriptCommand setScriptErrorNumber:errAEEventFailed];
		[currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't remove the stroke from this kind of graphic.", @"SKTGraphic", @"A scripting error message.")];
	    }
	}
    }
}


- (void)setScriptingStrokeWidth:(NSNumber *)strokeWidth {

    // See the comment in -setColor: about using KVC like we do here.

    // For the convenience of scripters, turn stroking on or off if necessary, if that's allowed. Don't forget that -isDrawingStroke can return YES or NO regardless of what -canSetDrawingStroke is returning.
    if (strokeWidth) {
	BOOL canSetStrokeWidth = YES;
	if (![self isDrawingStroke]) {
	    if ([self canSetDrawingStroke]) {
		[self setValue:@YES forKey:SKTGraphicIsDrawingStrokeKey];
	    } else {

		// Not allowed. Tell the scripter what happened.
		NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
		[currentScriptCommand setScriptErrorNumber:errAEEventFailed];
		[currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't set the stroke thickness of this kind of graphic.", @"SKTGraphic", @"A scripting error message.")];
		canSetStrokeWidth = NO;

	    }
	}
	if (canSetStrokeWidth) {
	    [self setValue:strokeWidth forKey:SKTGraphicStrokeWidthKey];
	}
    } else {
	if ([self isDrawingStroke]) {
	    if ([self canSetDrawingStroke]) {
		[self setValue:@NO forKey:SKTGraphicIsDrawingStrokeKey];
	    } else {

		// Not allowed. Tell the scripter what happened.
		NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
		[currentScriptCommand setScriptErrorNumber:errAEEventFailed];
		[currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't remove the stroke from this kind of graphic.", @"SKTGraphic", @"A scripting error message.")];

	    }
	}
    }

}

#pragma mark *** Debugging ***


// An override of the NSObject method.
- (NSString *)description {

    // Make 'po aGraphic' do something useful in gdb.
    return [[self properties] description];

}


@end


@implementation SKTGraphic (OldReading)
const NSString *const SKTOldClassKey = @"Class";
const NSString *const SKTOldBoundsKey = @"Bounds";
const NSString *const SKTOldDrawsFillKey = @"DrawsFill";
const NSString *const SKTOldFillColorKey = @"FillColor";
const NSString *const SKTOldDrawsStrokeKey = @"DrawsStroke";
const NSString *const SKTOldStrokeColorKey = @"StrokeColor";
const NSString *const SKTOldStrokeLineWidthKey = @"StrokeLineWidth";

+ (id)graphicWithPropertyListRepresentation:(NSDictionary *)dict
{
	NSString *classStr = [dict objectForKey:SKTOldClassKey];
	Class theClass = NSClassFromString(classStr);
	id theGraphic = nil;
	
	// Prepend SKT to the class name if we did not find it literally.  When we write the classname key we strip the prefix.  We try it first without the prefix because for a short time Sketch did not strip the prefix so there could be documents that do not need it prepended.
	if (!theClass) {
		theClass = NSClassFromString([@"SKT" stringByAppendingString:[dict objectForKey:SKTOldClassKey]]);
	}
	if (!theClass && ([@"SKTTextArea" isEqualToString:classStr] || [classStr isEqualToString:@"TextArea"])) {
		theClass = NSClassFromString(@"SKTText");
	}
	if (theClass) {
		theGraphic = [[theClass alloc] init];
		if (theGraphic) {
			[theGraphic loadOldPropertyListRepresentation:dict];
		}
	}
	return theGraphic;
}

- (void)loadOldPropertyListRepresentation:(NSDictionary *)dict {
	id obj;
	
	obj = [dict objectForKey:SKTOldBoundsKey];
	if (obj) {
		[self setBounds:NSRectFromString(obj)];
	}
	obj = [dict objectForKey:SKTOldFillColorKey];
	if (obj) {
		self.fillColor = [NSUnarchiver unarchiveObjectWithData:obj];
	}
	obj = [dict objectForKey:SKTOldDrawsFillKey];
	if (obj) {
		[self setDrawingFill:[obj isEqualToString:@"YES"]];
	}
	obj = [dict objectForKey:SKTOldStrokeColorKey];
	if (obj) {
		[self setStrokeColor:[NSUnarchiver unarchiveObjectWithData:obj]];
	}
	obj = [dict objectForKey:SKTOldStrokeLineWidthKey];
	if (obj) {
		[self setStrokeWidth:[obj floatValue]];
	}
	obj = [dict objectForKey:SKTOldDrawsStrokeKey];
	if (obj) {
		[self setDrawingStroke:[obj isEqualToString:@"YES"]];
	}
	return;
}

@end
