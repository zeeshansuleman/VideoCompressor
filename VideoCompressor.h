//
//  VideoCompressor.h
//  teemoApp
//
//  Created by Muhammad Zeeshan on 12/05/2017.
//  Copyright © 2017 Logicon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@interface VideoCompressor : NSObject
@property(nonatomic,strong,nullable) NSMutableDictionary* videoSettings;
- (void)exportAsynchronouslyWithCompletionHandler:(NSString *)outputUrl inputurl:(NSString*)inputUrl completion:(void (^)(BOOL success))completionBlock;
@end
