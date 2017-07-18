//
//  VideoCompressor.m
//  teemoApp
//
//  Created by Muhammad Zeeshan on 12/05/2017.
//  Copyright © 2017 Logicon. All rights reserved.
//

#import "VideoCompressor.h"
#import <stdlib.h>
#import "teemoApp-Swift.h"

@implementation VideoCompressor
- (void)exportAsynchronouslyWithCompletionHandler:(NSString *)outputUrl inputurl:(NSString*)inputUrl
                                       completion:(void (^)(BOOL success))completionBlock{
    NSError *error = nil;
    AVAssetWriter *videoWriter = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:outputUrl] fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(videoWriter);
    AVAsset *avAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:inputUrl] options:nil];
    AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput
                                            assetWriterInputWithMediaType:AVMediaTypeVideo
                                            outputSettings:_videoSettings];
    NSParameterAssert(videoWriterInput);
    NSParameterAssert([videoWriter canAddInput:videoWriterInput]);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    [videoWriter addInput:videoWriterInput];
    NSError *aerror = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:avAsset error:&aerror];
    AVAssetTrack *videoTrack = [[avAsset tracksWithMediaType:AVMediaTypeVideo]objectAtIndex:0];
    NSLog(@"%f",CMTimeGetSeconds(videoTrack.timeRange.duration));
    
    videoWriterInput.transform = [videoTrack preferredTransform];
    NSDictionary *videoOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    AVAssetReaderTrackOutput *asset_reader_output = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:videoOptions];
    [reader addOutput:asset_reader_output];
    //audio setup
    AVAssetWriterInput* audioWriterInput = [AVAssetWriterInput
                                            assetWriterInputWithMediaType:AVMediaTypeAudio
                                            outputSettings:nil];
    AVAssetReader *audioReader = [AVAssetReader assetReaderWithAsset:avAsset error:&error];
    AVAssetTrack* audioTrack = [[avAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    AVAssetReaderOutput *readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:nil];
    
    [audioReader addOutput:readerOutput];
    NSParameterAssert(audioWriterInput);
    NSParameterAssert([videoWriter canAddInput:audioWriterInput]);
    audioWriterInput.expectsMediaDataInRealTime = NO;
    [videoWriter addInput:audioWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    [reader startReading];
    dispatch_queue_t _processingQueue = dispatch_queue_create("assetAudioWriterQueue", NULL);
    [videoWriterInput requestMediaDataWhenReadyOnQueue:_processingQueue usingBlock:
     ^{
         while ([videoWriterInput isReadyForMoreMediaData]) {
             CMSampleBufferRef sampleBuffer;
             if ([reader status] == AVAssetReaderStatusReading &&
                 (sampleBuffer = [asset_reader_output copyNextSampleBuffer])) {
                 CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                 NSLog(@"buffer time:%f",CMTimeGetSeconds(pts)/CMTimeGetSeconds(videoTrack.timeRange.duration));
                 double progress = CMTimeGetSeconds(pts)/CMTimeGetSeconds(videoTrack.timeRange.duration);
                 [Utility updateProgressWithValue:progress];
                 BOOL result = [videoWriterInput appendSampleBuffer:sampleBuffer];
                 CFRelease(sampleBuffer);
                 if (!result) {
                     [reader cancelReading];
                     break;
                 }
             }
             else {
                 [videoWriterInput markAsFinished];
                 switch ([reader status]) {
                     case AVAssetReaderStatusFailed:
                         [videoWriter cancelWriting];
                         completionBlock(NO);
                         break;
                     case AVAssetReaderStatusReading:
                         completionBlock(NO);
                         break;
                     case AVAssetReaderStatusCancelled:
                         completionBlock(NO);
                         break;
                     case AVAssetReaderStatusUnknown:
                         completionBlock(NO);
                         break;
                     case AVAssetReaderStatusCompleted:
                         [audioReader startReading];
                         [videoWriter startSessionAtSourceTime:kCMTimeZero];
                         dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
                         [audioWriterInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^
                          {
                              while (audioWriterInput.readyForMoreMediaData) {
                                  CMSampleBufferRef nextBuffer;
                                  if ([audioReader status] == AVAssetReaderStatusReading &&
                                      (nextBuffer = [readerOutput copyNextSampleBuffer])) {
                                      if (nextBuffer) {
                                          [audioWriterInput appendSampleBuffer:nextBuffer];
                                      }
                                  }else{
                                      [audioWriterInput markAsFinished];
                                      switch ([audioReader status]) {
                                          case AVAssetReaderStatusFailed:
                                              [videoWriter cancelWriting];
                                              completionBlock(NO);
                                              break;
                                          case AVAssetReaderStatusReading:
                                              break;
                                          case AVAssetReaderStatusCancelled:
                                              completionBlock(NO);
                                              break;
                                          case AVAssetReaderStatusUnknown:
                                              completionBlock(NO);
                                              break;
                                          case AVAssetReaderStatusCompleted:
                                              [videoWriter finishWritingWithCompletionHandler:^{
                                                  NSLog(@"completed");
                                                  completionBlock(YES);
                                              }];
                                              break;
                                      }
                                  }
                              }
                          }];
                         break;
                 }
                 break;
             }
         }
     }
     ];
    NSLog(@"Write Ended");
}
@end
