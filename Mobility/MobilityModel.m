//
//  MobilityModel.m
//  Mobility
//
//  Created by Charles Forkish on 12/24/14.
//  Copyright (c) 2014 Open mHealth. All rights reserved.
//

#import "MobilityModel.h"
#import <CoreData/CoreData.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>

@interface MobilityModel ()

@property(nonatomic, strong) NSURL *persistentStoreURL;
@property(nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property(nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property(nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, copy) NSString *userEmail;

@end

@implementation MobilityModel

+ (instancetype)sharedModel
{
    static MobilityModel *_sharedModel = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedModel = [[self alloc] initPrivate];
    });
    
    return _sharedModel;
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Singleton"
                                   reason:@"Use +[MobilityModel sharedModel]"
                                 userInfo:nil];
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        
        // fetch logged-in user
        NSString *userEmail = [self persistentStoreMetadataTextForKey:@"userEmail"];
        NSLog(@"model setup with userEmail: %@", userEmail);
        if (userEmail != nil) {
            _userEmail = [userEmail copy];
        }
    }
    return self;
}

- (void)logMessage:(NSString *)message
{
#ifdef LOG_TABLE
    NSLog(@"logging message: %@", message);
    DebugLogEntry *entry = (DebugLogEntry *)[self insertNewObjectForEntityForName:@"DebugLogEntry"];
    entry.timestamp = [NSDate date];
    entry.text = message;
#endif
}

- (void)saveState
{
    NSLog(@"saving model state");
    [self saveManagedContext];
    
    NSData *encodedClient = [NSKeyedArchiver archivedDataWithRootObject:self];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:encodedClient forKey:@"MobilityModel"];
    [userDefaults synchronize];
}

- (void)setUserEmail:(NSString *)userEmail
{
    _userEmail = [userEmail copy];
    [self setPersistentStoreMetadataText:userEmail forKey:@"userEmail"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMobilityModelUserChangedNotification object:self];
}


#pragma mark - Property Accessors (Core Data)

/**
 *  persistentStoreURL
 */
- (NSURL *)persistentStoreURL {
    if (_persistentStoreURL == nil) {
        NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [documentDirectories firstObject];
        NSString *path = [documentDirectory stringByAppendingPathComponent:@"MobilityModel.data"];
        _persistentStoreURL = [NSURL fileURLWithPath:path];
    }
    
    return _persistentStoreURL;
}

/**
 *  managedObjectContext
 */
- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext == nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setUndoManager:nil];
        [_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    
    return _managedObjectContext;
}

/**
 *  managedObjectModel
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel == nil) {
        _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    }
    
    return _managedObjectModel;
}

/**
 *  persistentStoreCoordinator
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator == nil) {
        NSError *error = nil;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self.persistentStoreURL options:nil error:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            NSLog(@"Error opening persistent store, deleting persistent store\n%@\n%@", error, [error userInfo]);
            [self deletePersistentStore];
            _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
            if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self.persistentStoreURL options:nil error:&error]) {
                NSLog(@"Error opening persistent store after reset. abort.");
                abort();
            }
            
        }
    }
    
    return _persistentStoreCoordinator;
}

- (NSString *)persistentStoreMetadataTextForKey:(NSString *)key
{
    NSPersistentStore *store = [self.persistentStoreCoordinator persistentStoreForURL:self.persistentStoreURL];
    NSDictionary *metadata = [self.persistentStoreCoordinator metadataForPersistentStore:store];
    return metadata[key];
}

- (void)setPersistentStoreMetadataText:(NSString *)text forKey:(NSString *)key
{
    NSPersistentStore *store = [self.persistentStoreCoordinator persistentStoreForURL:self.persistentStoreURL];
    NSMutableDictionary *metadata = [[self.persistentStoreCoordinator metadataForPersistentStore:store] mutableCopy];
    if (text) {
        metadata[key] = text;
    }
    else {
        [metadata removeObjectForKey:key];
    }
    [self.persistentStoreCoordinator setMetadata:metadata forPersistentStore:store];
}


#pragma mark - Model

- (MobilityActivity *)uniqueActivityWithMotionActivity:(CMMotionActivity *)motionActivity
{
    MobilityActivity *existingActivity = (MobilityActivity *)[self fetchObjectWithEntityName:@"MobilityActivity" uniqueTimestamp:motionActivity.startDate];
    if (existingActivity) return existingActivity;
    
    MobilityActivity *newActivity = (MobilityActivity *)[self insertNewObjectForEntityForName:@"MobilityActivity"];
    newActivity.userEmail = self.userEmail;
    newActivity.timestamp = motionActivity.startDate;
    newActivity.confidence = motionActivity.confidence;
    newActivity.stationary = motionActivity.stationary;
    newActivity.walking = motionActivity.walking;
    newActivity.running = motionActivity.running;
    newActivity.automotive = motionActivity.automotive;
    if ([motionActivity respondsToSelector:@selector(cycling)]) {
        newActivity.cycling = (BOOL)[motionActivity performSelector:@selector(cycling)];
    }
    newActivity.unknown = motionActivity.unknown;
    
    return newActivity;
}

- (MobilityLocation *)uniqueLocationWithCLLocation:(CLLocation *)clLocation
{
    MobilityLocation *existingLocation = (MobilityLocation *)[self fetchObjectWithEntityName:@"MobilityLocation" uniqueTimestamp:clLocation.timestamp];
    if (existingLocation) return existingLocation;
    
    MobilityLocation *newLocation = (MobilityLocation *)[self insertNewObjectForEntityForName:@"MobilityLocation"];
    newLocation.userEmail = self.userEmail;
    newLocation.timestamp = clLocation.timestamp;
    newLocation.latitude = clLocation.coordinate.latitude;
    newLocation.longitude = clLocation.coordinate.longitude;
    newLocation.altitude = clLocation.altitude;
    newLocation.bearing = clLocation.course;
    newLocation.speed = clLocation.speed;
    newLocation.horizontalAccuracy = clLocation.horizontalAccuracy;
    newLocation.verticalAccuracy = clLocation.verticalAccuracy;
    
    return newLocation;
}

- (NSArray *)oldestPendingActivitiesWithLimit:(NSInteger)fetchLimit
{
    return [self fetchPendingObjectsWithEntityName:@"MobilityActivity" fetchLimit:fetchLimit];
}

- (NSArray *)oldestPendingLocationsWithLimit:(NSInteger)fetchLimit
{
    return [self fetchPendingObjectsWithEntityName:@"MobilityLocation" fetchLimit:fetchLimit];
}

- (NSArray *)fetchPendingObjectsWithEntityName:(NSString *)entityName fetchLimit:(NSInteger)limit
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"submitted == NO && userEmail == %@", self.userEmail];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:entityName inManagedObjectContext:self.managedObjectContext]];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setSortDescriptors:@[sort]];
    [fetchRequest setFetchLimit:limit];
    
    NSError *error = nil;
    NSArray *fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error) {
        NSLog(@"error fetching pending objects for entity: %@", entityName);
    }
    
    return fetchedObjects;
}

- (BOOL)hasObjectWithEntityName:(NSString *)entityName timestamp:(NSDate *)timestamp
{
    NSManagedObject *existingObject = [self fetchObjectWithEntityName:entityName uniqueTimestamp:timestamp];
    return (existingObject != nil);
}

- (NSManagedObject *)fetchObjectWithEntityName:(NSString *)entityName uniqueTimestamp:(NSDate *)timestamp
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"timestamp == %@", timestamp];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:entityName inManagedObjectContext:self.managedObjectContext]];
    [fetchRequest setPredicate:predicate];
    
    NSError *error = nil;
    NSArray *fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error) {
        NSLog(@"error fetching entity: %@, timestamp: %@", entityName, timestamp);
    }
    
    if (fetchedObjects.count > 0) {
        if (fetchedObjects.count > 1) {
            NSLog(@"found more than one %@ with timestamp %@", entityName, timestamp);
        }
        return fetchedObjects.firstObject;
    }
    else {
        return nil;
    }
}

- (NSManagedObject *)insertNewObjectForEntityForName:(NSString *)entityName
{
    return [NSEntityDescription insertNewObjectForEntityForName:entityName
                                         inManagedObjectContext:self.managedObjectContext];
}

- (NSFetchedResultsController *)fetchedActivitesController
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userEmail == %@", self.userEmail];
    return [self fetchedResultsControllerWithEntityName:@"MobilityActivity" predicate:predicate cacheName:@"MobilityActivities"];
}

- (NSFetchedResultsController *)fetchedLocationsController
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userEmail == %@", self.userEmail];
    return [self fetchedResultsControllerWithEntityName:@"MobilityLocation" predicate:predicate cacheName:@"MobilityLocations"];
}

- (NSFetchedResultsController *)fetchedLogEntriesController
{
    return [self fetchedResultsControllerWithEntityName:@"DebugLogEntry" predicate:nil cacheName:@"DebugLogEntries"];
}

- (NSFetchedResultsController *)fetchedResultsControllerWithEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate cacheName:(NSString *)cacheName
{
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:self.managedObjectContext];
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setSortDescriptors:@[descriptor]];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setFetchBatchSize:100];
    
    // Build a fetch results controller based on the above fetch request.
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                               managedObjectContext:self.managedObjectContext
                                                                                                 sectionNameKeyPath:nil
                                                                                                          cacheName:cacheName];
    
    
    NSError *error = nil;
    BOOL success = [fetchedResultsController performFetch:&error];
    if (success == NO) {
        // Not sure if we should return the 'dead' controller or just return 'nil'...
        // [fetchedResultsController setDelegate:nil];
        // [fetchedResultsController release];
        // fetchedResultsController = nil;
    }
    
    return fetchedResultsController;
}


/**
 *  saveManagedContext
 */
- (void)saveManagedContext
{
    NSError *error = nil;
    [self.managedObjectContext save:&error];
    if (error) {
        NSLog(@"Error saving context: %@", [error localizedDescription]);
    }
}

/**
 *  deletePersistentStore
 */
- (void)deletePersistentStore
{
    NSLog(@"Deleting persistent store.");
    self.managedObjectContext = nil;
    self.managedObjectModel = nil;
    self.persistentStoreCoordinator = nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtURL:self.persistentStoreURL error:nil];
    
    self.persistentStoreURL = nil;
}

@end
