//
//  ViewController.m
//  XDXAudioQueuePlayer
//
//  Created by 小东邪 on 2019/6/27.
//  Copyright © 2019 小东邪. All rights reserved.
//

#import "ViewController.h"
#import "XDXAudioFileHandler.h"
#import "XDXAudioQueuePlayer.h"
#import <AVFoundation/AVFoundation.h>
#import "XDXQueueProcess.h"

#define kXDXReadAudioPacketsNum 4096

@interface ViewController ()

@property (nonatomic, assign) BOOL isStopPlay;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // This is only for the testPCM.caf file.
    AudioStreamBasicDescription audioFormat = {
        .mSampleRate         = 44100,
        .mFormatID           = kAudioFormatLinearPCM,
        .mChannelsPerFrame   = 1,
        .mFormatFlags        = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
        .mBitsPerChannel     = 16,
        .mBytesPerPacket     = 2,
        .mBytesPerFrame      = 2,
        .mFramesPerPacket    = 1,
    };
    
    // Configure Audio Queue Player
    [[XDXAudioQueuePlayer getInstance] configureAudioPlayerWithAudioFormat:&audioFormat bufferSize:kXDXReadAudioPacketsNum * audioFormat.mBytesPerPacket];
    
    // Configure Audio File
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"testPCM" ofType:@"caf"];
    XDXAudioFileHandler *fileHandler = [XDXAudioFileHandler getInstance];
    [fileHandler configurePlayFilePath:filePath];
}

#pragma mark - Button Action
- (IBAction)startPlayDidClicked:(id)sender {
    // Put audio data from audio file into audio data queue
    [self putAudioDataIntoDataQueue];
    [[XDXAudioQueuePlayer getInstance] startAudioPlayer];
}

- (IBAction)stopPlayDidClicked:(id)sender {
    [[XDXAudioQueuePlayer getInstance] stopAudioPlayer];
    self.isStopPlay = YES;
}

#pragma mark - Other
- (void)putAudioDataIntoDataQueue {
    AudioStreamPacketDescription *packetDesc = NULL;
    __block UInt32 readBytes;
    
    // Note: our send audio rate should > play audio rate
    [NSTimer scheduledTimerWithTimeInterval:0.09 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (self.isStopPlay) {
            self.isStopPlay = NO;
            [timer invalidate];
            [[XDXAudioFileHandler getInstance] resetFileForPlay];
            XDXCustomQueueProcess *audioBufferQueue =  [XDXAudioQueuePlayer getInstance]->_audioBufferQueue;
            audioBufferQueue->ResetFreeQueue(audioBufferQueue->m_work_queue, audioBufferQueue->m_free_queue);
            return;
        }
        
        void *audioData = malloc([XDXAudioQueuePlayer audioBufferSize]);
        readBytes = [[XDXAudioFileHandler getInstance] readAudioFromFileBytesWithAudioDataRef:audioData
                                                                                   packetDesc:packetDesc
                                                                               readPacketsNum:kXDXReadAudioPacketsNum];
        
        if (readBytes > 0) {
            [self addBufferToWorkQueueWithAudioData:audioData size:readBytes userData:packetDesc];
        }else {
            [timer invalidate];
        }
        
    }];
}

- (void)addBufferToWorkQueueWithAudioData:(void *)data  size:(int)size userData:(void *)userData {
    XDXCustomQueueProcess *audioBufferQueue =  [XDXAudioQueuePlayer getInstance]->_audioBufferQueue;
    
    XDXCustomQueueNode *node = audioBufferQueue->DeQueue(audioBufferQueue->m_free_queue);
    if (node == NULL) {
        NSLog(@"XDXCustomQueueProcess addBufferToWorkQueueWithSampleBuffer : Data in , the node is NULL !");
        return;
    }
    node->data = data;
    node->size = size;
    node->userData = userData;
    audioBufferQueue->EnQueue(audioBufferQueue->m_work_queue, node);
    
    NSLog(@"XDXCustomQueueProcess addBufferToWorkQueueWithSampleBuffer : Data in ,  work size = %d, free size = %d !",audioBufferQueue->m_work_queue->size, audioBufferQueue->m_free_queue->size);
}

@end
