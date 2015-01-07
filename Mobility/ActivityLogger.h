//
//  ActivityLogger.h
//  Mobility
//
//  Created by Charles Forkish on 12/15/14.
//  Copyright (c) 2014 Open mHealth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MobilityDataPoint.h"

@interface ActivityLogger : NSObject

+ (instancetype)sharedLogger;

@property (nonatomic, readonly) NSMutableArray *logEntries;
@property (copy) void (^newLogEntryBlock)(NSDictionary *logEntry);

- (void)startLogging;
- (void)stopLogging;
//
//- (void)enterBackgroundMode;
//- (void)exitBackgroundMode;

@end
