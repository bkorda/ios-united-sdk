//
//  GLProgram.m
//  HTY360Player
//
//  Created by  on 11/8/15.
//  Copyright © 2015 Hanton. All rights reserved.
//

#import "LoopMeGLProgram.h"
#import "LoopMeLogging.h"

// START:typedefs
#pragma mark Function Pointer Definitions
typedef void (*GLInfoFunction)(GLuint program,
GLenum pname,
GLint* params);
typedef void (*GLLogFunction) (GLuint program,
GLsizei bufsize,
GLsizei* length,
GLchar* infolog);
// END:typedefs

#pragma mark -
#pragma mark Private Extension Method Declaration
// START:extension
@interface LoopMeGLProgram()

- (BOOL)compileShader:(GLuint *)shader
                 type:(GLenum)type
               string:(NSString *)shaderString;
- (NSString *)logForOpenGLObject:(GLuint)object
                    infoCallback:(GLInfoFunction)infoFunc
                         logFunc:(GLLogFunction)logFunc;
@end
// END:extension
#pragma mark -

@implementation LoopMeGLProgram

// START:init
@synthesize program;

- (id)initWithVertexShaderString:(NSString *)vShaderString
            fragmentShaderString:(NSString *)fShaderString {
  if ((self = [super init])) {
    attributes = [[NSMutableArray alloc] init];
    uniforms = [[NSMutableArray alloc] init];
    program = glCreateProgram();
    
    if (![self compileShader:&vertShader
                        type:GL_VERTEX_SHADER
                      string:vShaderString]) {
        LoopMeLogDebug(@"Failed to compile vertex shader");
    }
    
    // Create and compile fragment shader
    if (![self compileShader:&fragShader
                        type:GL_FRAGMENT_SHADER
                      string:fShaderString]) {
        LoopMeLogDebug(@"Failed to compile fragment shader");
    }
    
    glAttachShader(program, vertShader);
    glAttachShader(program, fragShader);
  }
  
  return self;
}

- (id)initWithVertexShaderString:(NSString *)vShaderString
          fragmentShaderFilename:(NSString *)fShaderFilename {
    NSBundle *resourcesBundle = [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"LoopMeResources" withExtension:@"bundle"]];
    NSString *fragShaderPathname = [resourcesBundle pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];
  
    self = [self initWithVertexShaderString:vShaderString fragmentShaderString:fragmentShaderString];
  
    return self;
}

- (id)initWithVertexShaderFilename:(NSString *)vShaderFilename
            fragmentShaderFilename:(NSString *)fShaderFilename {
    NSBundle *resourcesBundle = [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"LoopMeResources" withExtension:@"bundle"]];
    NSString *vertShaderPathname = [resourcesBundle pathForResource:vShaderFilename ofType:@"vsh"];
    NSString *vertexShaderString = [NSString stringWithContentsOfFile:vertShaderPathname encoding:NSUTF8StringEncoding error:nil];
  
    NSString *fragShaderPathname = [resourcesBundle pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];
  
    self = [self initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
  
    return self;
}
// END:init

// START:compile
- (BOOL)compileShader:(GLuint *)shader
                 type:(GLenum)type
               string:(NSString *)shaderString {
    GLint status;
    const GLchar *source;

    source = (GLchar *)[shaderString UTF8String];
    if (!source) {
        LoopMeLogDebug(@"Failed to load vertex shader");
        return NO;
    }

    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);

    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);

    if (status != GL_TRUE) {
        GLint logLength;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
          GLchar *log = (GLchar *)malloc(logLength);
          glGetShaderInfoLog(*shader, logLength, &logLength, log);
          LoopMeLogDebug(@"Shader compile log:\n%s", log);
          free(log);
        }
    }

    return status == GL_TRUE;
}
// END:compile

#pragma mark -
// START:addattribute
- (void)addAttribute:(NSString *)attributeName {
    if (![attributes containsObject:attributeName]) {
        [attributes addObject:attributeName];
        glBindAttribLocation(program,
                         (GLuint)[attributes indexOfObject:attributeName],
                         [attributeName UTF8String]);
  }
}
// END:addattribute

// START:indexmethods
- (GLuint)attributeIndex:(NSString *)attributeName {
    return (GLuint)[attributes indexOfObject:attributeName];
}

- (GLuint)uniformIndex:(NSString *)uniformName {
    return glGetUniformLocation(program, [uniformName UTF8String]);
}
// END:indexmethods

#pragma mark -
// START:link
- (BOOL)link {
    GLint status;
    glLinkProgram(program);

    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        return NO;
    }

    if (vertShader) {
        glDeleteShader(vertShader);
        vertShader = 0;
    }
    if (fragShader) {
        glDeleteShader(fragShader);
        fragShader = 0;
    }

    return YES;
}
// END:link

// START:use
- (void)use {
  glUseProgram(program);
}
// END:use

#pragma mark -
// START:privatelog
- (NSString *)logForOpenGLObject:(GLuint)object
                    infoCallback:(GLInfoFunction)infoFunc
                         logFunc:(GLLogFunction)logFunc {
    GLint logLength = 0, charsWritten = 0;

    infoFunc(object, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength < 1) {
        return nil;
    }

    char *logBytes = malloc(logLength);
    logFunc(object, logLength, &charsWritten, logBytes);
    NSString *log = [[NSString alloc] initWithBytes:logBytes
                                           length:logLength
                                         encoding:NSUTF8StringEncoding];
    free(logBytes);
    return log;
}
// END:privatelog

// START:log
- (NSString *)vertexShaderLog {
    return [self logForOpenGLObject:vertShader
                     infoCallback:(GLInfoFunction)&glGetProgramiv
                          logFunc:(GLLogFunction)&glGetProgramInfoLog];
  
}

- (NSString *)fragmentShaderLog {
    return [self logForOpenGLObject:fragShader
                     infoCallback:(GLInfoFunction)&glGetProgramiv
                          logFunc:(GLLogFunction)&glGetProgramInfoLog];
}

- (NSString *)programLog {
    return [self logForOpenGLObject:program
                     infoCallback:(GLInfoFunction)&glGetProgramiv
                          logFunc:(GLLogFunction)&glGetProgramInfoLog];
}
// END:log

- (void)validate {
    GLint logLength;
  
    glValidateProgram(program);
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
}

#pragma mark -
// START:dealloc
- (void)dealloc {
    if (vertShader) {
        glDeleteShader(vertShader);
    }
  
    if (fragShader) {
        glDeleteShader(fragShader);
    }
  
    if (program) {
        glDeleteProgram(program);
    }
}
// END:dealloc

@end
