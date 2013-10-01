//
//  ViewController.m
//  AudioSessionToy
//
//  Created by Pieter Scholtz on 2013/10/01.
//
//

@import MediaPlayer;
@import AVFoundation;

#import "ViewController.h"

NSString *loopFilename = @"Synthesizer Bass 07.caf"; // @"80s Pop Synthesizer 01.caf"; //

typedef NS_ENUM(NSInteger, PickerComponents)
{
  PickerComponentCategory = 0,
  PickerComponentMode     = 1
};

@interface ViewController ()
@property (strong, nonatomic) NSArray *dataSource;
@property (readonly, nonatomic) NSArray *categories;
@property (readonly, nonatomic) NSArray *modes;
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@end

@implementation ViewController

- (void)viewDidLoad
{
  self.dataSource = @[self.categories, self.modes];

  [self selectCategory:self.categories.firstObject];
  [self selectMode:self.modes.firstObject];

  self.toolbarItems = @[[[UIBarButtonItem alloc] initWithCustomView:({
    CGRect volumeViewFrame = self.navigationController.toolbar.bounds;
    volumeViewFrame.size.width -= 30;
    MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:volumeViewFrame];
    [volumeView sizeToFit];
    volumeView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    volumeView;
  })]];
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
  return self.dataSource.count;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
  return [self.dataSource[component] count];
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
  NSString *name = self.dataSource[component][row];

  if ([name hasPrefix:@"AVAudioSessionCategory"])
    return [name stringByReplacingOccurrencesOfString:@"AVAudioSessionCategory" withString:@""];

  if ([name hasPrefix:@"AVAudioSessionMode"])
    return [name stringByReplacingOccurrencesOfString:@"AVAudioSessionMode" withString:@""];

  return name;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
  NSError *error;
  NSString *name = self.dataSource[component][row];
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];

  switch ((PickerComponents)component)
  {
    case PickerComponentCategory:
    {
      if ([audioSession setCategory:name error:&error] == NO)
      {
        [self showAlertWithTitle:error.localizedDescription
                         message:[NSString stringWithFormat:@"Unable to select category = '%@'", name]];
        // Default to first category
        [self selectCategory:self.categories.firstObject];
      }
      else if ((self.audioPlayer.isPlaying == NO)
               && (self.audioSessionActiveSwitch.on == YES))
      {
        // This is to ensure that playback is started when changing from a category that doesn't support playback, e.g. 'Record' to one that does, e.g. 'Playback', etc.
        [self startPlayback];
      }
      // Changing the category will force a change to the mode in many cases, so this is to ensure the UI reflects audio session state
      [self selectMode:audioSession.mode];
    } break;
      
    case PickerComponentMode:
    {
      if ([audioSession setMode:name error:&error] == NO)
      {
        [self showAlertWithTitle:error.localizedDescription
                         message:[NSString stringWithFormat:@"Mode = '%@' not supported for category = '%@'", name, audioSession.category]];
        // Default to first mode
        [self selectMode:self.modes.firstObject];
      }
    } break;
  }

}

#pragma mark - ViewController

- (NSArray *)categories
{
  static NSArray *_categories = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _categories = @[AVAudioSessionCategoryAmbient,
                    AVAudioSessionCategorySoloAmbient,
                    AVAudioSessionCategoryPlayback,
                    AVAudioSessionCategoryRecord,
                    AVAudioSessionCategoryPlayAndRecord,
                    AVAudioSessionCategoryAudioProcessing,
                    AVAudioSessionCategoryMultiRoute];
  });
  return _categories;
}

- (NSArray *)modes
{
  static NSArray *_modes = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _modes = ({
      NSMutableArray *supportedModes = [@[AVAudioSessionModeDefault,
                                          AVAudioSessionModeVoiceChat,
                                          AVAudioSessionModeGameChat,
                                          AVAudioSessionModeVideoRecording,
                                          AVAudioSessionModeMeasurement,
                                          AVAudioSessionModeMoviePlayback]
                                        mutableCopy];
      if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending)
        [supportedModes addObject:AVAudioSessionModeVideoChat];
      [supportedModes copy];
    });
  });
  return _modes;
}

- (void)selectCategory:(NSString *)category
{
  NSUInteger categoryIndex = [self.modes indexOfObject:category];
  if (categoryIndex != NSNotFound)
  {
    [self.pickerView selectRow:categoryIndex inComponent:PickerComponentCategory animated:YES];
    [self pickerView:self.pickerView didSelectRow:categoryIndex inComponent:PickerComponentCategory];
  }
}

- (void)selectMode:(NSString *)mode
{
  NSUInteger modeIndex = [self.modes indexOfObject:mode];
  if (modeIndex != NSNotFound)
  {
    [self.pickerView selectRow:modeIndex inComponent:PickerComponentMode animated:YES];
    [self pickerView:self.pickerView didSelectRow:modeIndex inComponent:PickerComponentMode];
  }
}

- (void)startPlayback
{
  NSError *error;
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  
  NSURL *loopURL = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:loopFilename];
  AVAudioPlayer *loopPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:loopURL error:&error];
  if (loopPlayer == nil)
  {
    [self showAlertWithTitle:error.localizedDescription
                     message:[NSString stringWithFormat:@"Error playing audio from file '%@'", loopFilename]];
    return;
  }
  loopPlayer.numberOfLoops = -1;
  if ([loopPlayer play] == NO)
  {
    [self showAlertWithTitle:@"Failed to play audio"
                     message:[NSString stringWithFormat:@"Playback not supported with category = '%@' and mode = '%@'", audioSession.category, audioSession.mode]];
    return;
  }
  self.audioPlayer = loopPlayer;
}

- (IBAction)audioSessionActiveValueChanged:(UISwitch *)audioSessionActiveSwitch
{
  if ((audioSessionActiveSwitch.on == NO)
      && (self.audioPlayer != nil)
      && (self.audioPlayer.isPlaying == YES))
  {
    [self.audioPlayer stop];
    self.audioPlayer = nil;
  }

  NSError *error;
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  if ([audioSession setActive:audioSessionActiveSwitch.on error:&error] == NO)
  {
    [self showAlertWithTitle:error.localizedDescription
                     message:audioSessionActiveSwitch.on
                               ? @"Failed to Activate Audio Session"
                               : @"Failed to Deactivate Audio Session"];
    audioSessionActiveSwitch.on ^= YES; // Invert the value of the switch
  }
  
  if (audioSessionActiveSwitch.on == YES)
  {
    self.title = @"Audio Session Active";
    [self startPlayback];
  }
  else
  {
    self.title = @"Audio Session Inactive";
  }

}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
  [[[UIAlertView alloc] initWithTitle:title
                              message:message
                             delegate:nil
                    cancelButtonTitle:@"OK"
                    otherButtonTitles:nil]
   show];
}


@end
