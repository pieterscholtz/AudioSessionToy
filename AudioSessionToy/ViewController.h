//
//  ViewController.h
//  AudioSessionToy
//
//  Created by Pieter Scholtz on 2013/10/01.
//
//

@import UIKit;

@interface ViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate>
@property (weak, nonatomic) IBOutlet UIPickerView *pickerView;
@property (weak, nonatomic) IBOutlet UISwitch *audioSessionActiveSwitch;
@end
