//
//  MobilityViewController.m
//  Mobility
//
//  Created by Charles Forkish on 12/15/14.
//  Copyright (c) 2014 Open mHealth. All rights reserved.
//

#import "MobilityViewController.h"
#import "ActivityLogger.h"

@interface MobilityViewController ()

@property (nonatomic, strong) ActivityLogger *logger;

@end

@implementation MobilityViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Mobility";
    
    self.logger = [ActivityLogger sharedLogger];
    
    __weak typeof(self) weakSelf = self;
    self.logger.newLogEntryBlock = ^(MobilityLogEntry *logEntry) {
        NSLog(@"new log entry: %@", logEntry);
        [weakSelf.tableView reloadData];
    };
    
    UIBarButtonItem *startButton = [[UIBarButtonItem alloc] initWithTitle:@"Start" style:UIBarButtonItemStylePlain target:self.logger action:@selector(startLogging)];
    self.navigationItem.rightBarButtonItem = startButton;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.logger.logEntries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"mobilityCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    cell.textLabel.text = [NSString stringWithFormat:@"Entry %d", (int)indexPath.row];
    
    return cell;
}

@end
