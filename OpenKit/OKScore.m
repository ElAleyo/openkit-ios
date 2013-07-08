//
//  OKScore.m
//  OKClient
//
//  Created by Suneet Shah on 1/3/13.
//  Copyright (c) 2013 OpenKit. All rights reserved.
//

#import "OKScore.h"
#import "OKUserUtilities.h"
#import "OKUser.h"
#import "OKManager.h"
#import "OKNetworker.h"
#import "OKDefines.h"
#import "OKGameCenterUtilities.h"
#import "OKMacros.h"

@implementation OKScore

@synthesize OKLeaderboardID, OKScoreID, scoreValue, user, scoreRank, metadata, displayString, gamecenterLeaderboardID;
- (id)initFromJSON:(NSDictionary*)jsonDict
{
    self = [super init];
    if (self) {
        // Initialization code here.
        
        self.OKLeaderboardID = [[jsonDict objectForKey:@"leaderboard_id"] integerValue];
        self.OKScoreID = [[jsonDict objectForKey:@"id"] integerValue];
        self.scoreValue = [[jsonDict objectForKey:@"value"] longLongValue];
        self.scoreRank = [[jsonDict objectForKey:@"rank"] integerValue];
        self.user = [OKUserUtilities createOKUserWithJSONData:[jsonDict objectForKey:@"user"]];
        
        if([jsonDict objectForKey:@"display_string"] != nil && [jsonDict objectForKey:@"display_string"] != [NSNull null])
            self.displayString = [jsonDict objectForKey:@"display_string"];
        
        if([jsonDict objectForKey:@"metadata"] != nil && [jsonDict objectForKey:@"metadata"] != [NSNull null])
            self.metadata = [[jsonDict objectForKey:@"metadata"] integerValue];
    }
    
    return self;
}

-(id)initWithOKLeaderboardID:(int)okLeaderboardID withGameCenterLeaderboardID:(NSString*)gcID
{
    self = [super init];
    if(self) {
        self.OKLeaderboardID = okLeaderboardID;
        self.gamecenterLeaderboardID = gcID;
    }
    
    return self;
}

-(NSDictionary*)getScoreParamDict
{
    OKUser *currentUser = [[OKManager sharedManager] currentUser];
    
    NSMutableDictionary *paramDict = [[NSMutableDictionary alloc] initWithCapacity:3];
    
    [paramDict setValue:[NSNumber numberWithLongLong:scoreValue] forKey:@"value"];
    [paramDict setValue:[NSNumber numberWithInt:OKLeaderboardID] forKey:@"leaderboard_id"];
    [paramDict setValue:[NSNumber numberWithInt:metadata] forKey:@"metadata"];
    [paramDict setValue:displayString forKey:@"display_string"];
    [paramDict setValue:[currentUser OKUserID] forKey:@"user_id"];
    
    return paramDict;
}

-(void)submitScoreWithCompletionHandler:(void (^)(NSError *error))completionHandler
{
    //Can only submit scores for the currently logged in user
    [self setUser:[OKUser currentUser]];
    
    if (!user) {
        NSError *noUserError = [[NSError alloc] initWithDomain:OKErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:@"No user is logged into openkit. To submit a score, there must be a currently logged in user" forKey:NSLocalizedDescriptionKey]];
        completionHandler(noUserError);
    }
    
    //Create a request and send it to OpenKit
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                             [self getScoreParamDict], @"score", nil];
    
    [OKNetworker postToPath:@"/scores" parameters:params
                    handler:^(id responseObject, NSError *error)
     {
         if(!error) {
             OKLog(@"Successfully posted score to OpenKit");
             //OKLog(@"Response: %@", responseObject);
         }else{
             OKLog(@"Failed to post score to OpenKit");
             OKLog(@"Error: %@", error);
         }
         completionHandler(error);
     }];
}

-(void)submitScoreToGameCenter
{
    if(self.gamecenterLeaderboardID && [OKGameCenterUtilities isPlayerAuthenticatedWithGameCenter]) {
        
        GKScore *scoreReporter = [[GKScore alloc] initWithCategory:[self gamecenterLeaderboardID]];
        scoreReporter.value = [self scoreValue];
        scoreReporter.context = [self metadata];
        
        [scoreReporter reportScoreWithCompletionHandler:^(NSError *error) {
            if(error) {
                OKLog(@"Error submitting score to GameCenter: %@",error);
            }
            else {
                OKLog(@"Gamecenter score submitted successfully");
            }
        }];
        
    } else {
        //TODO handle the fact that GC is not available
        OKLog(@"Not submitting score to GameCenter, GC not available");
    }
}

//TODO add completion handlers for both
-(void)submitScoreToOpenKitAndGameCenter
{
    if(self.gamecenterLeaderboardID && [OKGameCenterUtilities isPlayerAuthenticatedWithGameCenter]) {
        [self submitScoreToGameCenter];
    }
    
    [self submitScoreWithCompletionHandler:^(NSError *error) {
        //do something
    }];
}

-(void)submitScoreToOpenKitAndGameCenterWithCompletionHandler:(void (^)(NSError *error))completionHandler
{
    OKLog(@"Submitting score to OpenKit and GC");
    
    if(self.gamecenterLeaderboardID && [OKGameCenterUtilities isPlayerAuthenticatedWithGameCenter]) {
        [self submitScoreToGameCenter];
    }
    
   [self submitScoreWithCompletionHandler:completionHandler];
}

/** OKScoreProtocol Implementation **/
-(NSString*)scoreDisplayString {
    if([self displayString])
        return displayString;
    else
        return [NSString stringWithFormat:@"%lld",[self scoreValue]];
}
-(NSString*)userDisplayString {
    return [[self user] userNick];
}

-(NSString*)rankDisplayString {
    return [NSString stringWithFormat:@"%d", [self scoreRank]];
}

-(void)setRank:(NSInteger)rank {
    [self setScoreRank:rank];
}

@end
