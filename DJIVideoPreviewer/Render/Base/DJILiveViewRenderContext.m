//
//  DJILiveViewRenderContext.m
//  DJIWidget
//
//  Created by ai.chuyue on 2016/10/23.
//  Copyright © 2016年 Jerome.zhang. All rights reserved.
//

#import "DJILiveViewRenderContext.h"
#import <OpenGLES/EAGLDrawable.h>
#import <AVFoundation/AVFoundation.h>

#define MAXSHADERPROGRAMSALLOWEDINCACHE 40

@interface DJILiveViewRenderContext()
{
    NSMutableDictionary *shaderProgramCache;
    NSMutableArray *shaderProgramUsageHistory;
    EAGLSharegroup *_sharegroup;
    BOOL _multiThread;
}

@end

@implementation DJILiveViewRenderContext

@synthesize context = _context;
@synthesize currentShaderProgram = _currentShaderProgram;
@synthesize coreVideoTextureCache = _coreVideoTextureCache;

- (id)init{
    return [self initWithMultiThreadSupport:NO];
}

- (id)initWithMultiThreadSupport:(BOOL)multiThread;
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _multiThread = multiThread;
    shaderProgramCache = [[NSMutableDictionary alloc] init];
    shaderProgramUsageHistory = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)useAsCurrentContext;
{
    EAGLContext *imageProcessingContext = [self context];
    if ([EAGLContext currentContext] != imageProcessingContext)
    {
        [EAGLContext setCurrentContext:imageProcessingContext];
    }
}

- (void)setContextShaderProgram:(DJILiveViewRenderProgram *)shaderProgram;
{
    EAGLContext *imageProcessingContext = [self context];
    if ([EAGLContext currentContext] != imageProcessingContext)
    {
        [EAGLContext setCurrentContext:imageProcessingContext];
    }
    
    if (self.currentShaderProgram != shaderProgram)
    {
        _currentShaderProgram = shaderProgram;
        [shaderProgram use];
    }
}

+ (GLint)maximumTextureSizeForThisDevice;
{
    static dispatch_once_t pred;
    static GLint maxTextureSize = 0;
    
    dispatch_once(&pred, ^{
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    });
    
    return maxTextureSize;
}


+ (CGSize)sizeThatFitsWithinATextureForSize:(CGSize)inputSize;
{
    GLint maxTextureSize = [self maximumTextureSizeForThisDevice];
    if ( (inputSize.width < maxTextureSize) && (inputSize.height < maxTextureSize) )
    {
        return inputSize;
    }
    
    CGSize adjustedSize;
    if (inputSize.width > inputSize.height)
    {
        adjustedSize.width = (CGFloat)maxTextureSize;
        adjustedSize.height = ((CGFloat)maxTextureSize / inputSize.width) * inputSize.height;
    }
    else
    {
        adjustedSize.height = (CGFloat)maxTextureSize;
        adjustedSize.width = ((CGFloat)maxTextureSize / inputSize.height) * inputSize.width;
    }
    
    return adjustedSize;
}

- (void)presentBufferForDisplay;
{
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (DJILiveViewRenderProgram *)programForVertexShaderString:(NSString *)vertexShaderString fragmentShaderString:(NSString *)fragmentShaderString;
{
    NSString *lookupKeyForShaderProgram = [NSString stringWithFormat:@"V: %@ - F: %@", vertexShaderString, fragmentShaderString];
    DJILiveViewRenderProgram *programFromCache = [shaderProgramCache objectForKey:lookupKeyForShaderProgram];
    
    if (programFromCache == nil)
    {
        programFromCache = [[DJILiveViewRenderProgram alloc] initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
        [shaderProgramCache setObject:programFromCache forKey:lookupKeyForShaderProgram];
        //        [shaderProgramUsageHistory addObject:lookupKeyForShaderProgram];
        //        if ([shaderProgramUsageHistory count] >= MAXSHADERPROGRAMSALLOWEDINCACHE)
        //        {
        //            for (NSUInteger currentShaderProgramRemovedFromCache = 0; currentShaderProgramRemovedFromCache < 10; currentShaderProgramRemovedFromCache++)
        //            {
        //                NSString *shaderProgramToRemoveFromCache = [shaderProgramUsageHistory objectAtIndex:0];
        //                [shaderProgramUsageHistory removeObjectAtIndex:0];
        //                [shaderProgramCache removeObjectForKey:shaderProgramToRemoveFromCache];
        //            }
        //        }
    }
    
    return programFromCache;
}

- (EAGLContext *)createContext;
{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    context.multiThreaded = _multiThread;
    NSAssert(context != nil, @"Unable to create an OpenGL ES 2.0 context. The GPUImage framework requires OpenGL ES 2.0 support to work.");
    return context;
}


#pragma mark -
#pragma mark Manage fast texture upload

+ (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
    
#endif
}

#pragma mark -
#pragma mark Accessors

- (EAGLContext *)context;
{
    if (_context == nil)
    {
        _context = [self createContext];
        [EAGLContext setCurrentContext:_context];
        
        // Set up a few global settings for the image processing pipeline
        glDisable(GL_DEPTH_TEST);
    }
    
    return _context;
}

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache;
{
    if (_coreVideoTextureCache == NULL)
    {
#if defined(__IPHONE_6_0)
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [self context], NULL, &_coreVideoTextureCache);
#else
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge void *)[self context], NULL, &_coreVideoTextureCache);
#endif
        
        if (err)
        {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
        }
        
    }
    
    return _coreVideoTextureCache;
}

@end

