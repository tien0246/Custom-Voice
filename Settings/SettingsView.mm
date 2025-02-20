#import "SettingsView.h"
#import <AudioToolbox/AudioToolbox.h>
#import "SoundTouch.h"

extern soundtouch::SoundTouch *soundTouchPtr;

#define pitchKey @"pitchKey"
#define tempoKey @"tempoKey"
#define rateKey  @"rateKey"

static float getPitch() {
    float v = [[NSUserDefaults standardUserDefaults] floatForKey:pitchKey];
    return v == 0 ? 1.0f : v;
}

static float getTempo() {
    float v = [[NSUserDefaults standardUserDefaults] floatForKey:tempoKey];
    return v == 0 ? 1.0f : v;
}

static float getRate() {
    float v = [[NSUserDefaults standardUserDefaults] floatForKey:rateKey];
    return v == 0 ? 1.0f : v;
}

static void storePitch(float p) {
    [[NSUserDefaults standardUserDefaults] setFloat:p forKey:pitchKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static void storeTempo(float t) {
    [[NSUserDefaults standardUserDefaults] setFloat:t forKey:tempoKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static void storeRate(float r) {
    [[NSUserDefaults standardUserDefaults] setFloat:r forKey:rateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@interface SettingsView ()
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UILabel *pitchLabel;
@property (nonatomic, strong) UISlider *pitchSlider;
@property (nonatomic, strong) UILabel *pitchValueLabel;
@property (nonatomic, strong) UILabel *tempoLabel;
@property (nonatomic, strong) UISlider *tempoSlider;
@property (nonatomic, strong) UILabel *tempoValueLabel;
@property (nonatomic, strong) UILabel *rateLabel;
@property (nonatomic, strong) UISlider *rateSlider;
@property (nonatomic, strong) UILabel *rateValueLabel;
@property (nonatomic, strong) UIButton *closeBtn;
@end

@implementation SettingsView

static SettingsView *instance;

+ (void)load {
    [super load];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        instance = [[SettingsView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [instance setupGestureToShow];
    });
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        CGFloat w = frame.size.width - 60;
        CGFloat h = 300;
        self.container = [[UIView alloc] initWithFrame:CGRectMake(30, (frame.size.height - h) / 2, w, h)];
        self.container.backgroundColor = [UIColor whiteColor];
        self.container.layer.cornerRadius = 10.0;
        [self addSubview:self.container];
        self.closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        self.closeBtn.frame = CGRectMake(w - 50, 10, 40, 30);
        [self.closeBtn setTitle:@"Close" forState:UIControlStateNormal];
        [self.closeBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.closeBtn addTarget:self action:@selector(hideSettings) forControlEvents:UIControlEventTouchUpInside];
        [self.container addSubview:self.closeBtn];
        CGFloat x = 20;
        CGFloat labelWidth = 80;
        CGFloat sliderWidth = w - 100;
        CGFloat valueWidth = 60;
        CGFloat py = 60;
        CGFloat ty = 140;
        CGFloat ry = 220;
        self.pitchLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, py, labelWidth, 20)];
        self.pitchLabel.textColor = [UIColor blackColor];
        self.pitchLabel.text = @"Pitch";
        [self.container addSubview:self.pitchLabel];
        self.pitchSlider = [[UISlider alloc] initWithFrame:CGRectMake(x, py + 30, sliderWidth, 40)];
        self.pitchSlider.minimumValue = 0.5;
        self.pitchSlider.maximumValue = 2.0;
        self.pitchSlider.value = getPitch();
        self.pitchSlider.continuous = YES;
        [self.pitchSlider addTarget:self action:@selector(pitchChanging:) forControlEvents:UIControlEventValueChanged];
        [self.pitchSlider addTarget:self action:@selector(pitchChanged:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.container addSubview:self.pitchSlider];
        self.pitchValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.pitchSlider.frame) + 10, py + 30, valueWidth, 40)];
        self.pitchValueLabel.textColor = [UIColor blackColor];
        self.pitchValueLabel.textAlignment = NSTextAlignmentCenter;
        self.pitchValueLabel.text = [NSString stringWithFormat:@"%.2f", getPitch()];
        [self.container addSubview:self.pitchValueLabel];
        self.tempoLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, ty, labelWidth, 20)];
        self.tempoLabel.textColor = [UIColor blackColor];
        self.tempoLabel.text = @"Tempo";
        [self.container addSubview:self.tempoLabel];
        self.tempoSlider = [[UISlider alloc] initWithFrame:CGRectMake(x, ty + 30, sliderWidth, 40)];
        self.tempoSlider.minimumValue = 0.5;
        self.tempoSlider.maximumValue = 2.0;
        self.tempoSlider.value = getTempo();
        self.tempoSlider.continuous = YES;
        [self.tempoSlider addTarget:self action:@selector(tempoChanging:) forControlEvents:UIControlEventValueChanged];
        [self.tempoSlider addTarget:self action:@selector(tempoChanged:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.container addSubview:self.tempoSlider];
        self.tempoValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.tempoSlider.frame) + 10, ty + 30, valueWidth, 40)];
        self.tempoValueLabel.textColor = [UIColor blackColor];
        self.tempoValueLabel.textAlignment = NSTextAlignmentCenter;
        self.tempoValueLabel.text = [NSString stringWithFormat:@"%.2f", getTempo()];
        [self.container addSubview:self.tempoValueLabel];
        self.rateLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, ry, labelWidth, 20)];
        self.rateLabel.textColor = [UIColor blackColor];
        self.rateLabel.text = @"Rate";
        [self.container addSubview:self.rateLabel];
        self.rateSlider = [[UISlider alloc] initWithFrame:CGRectMake(x, ry + 30, sliderWidth, 40)];
        self.rateSlider.minimumValue = 0.5;
        self.rateSlider.maximumValue = 2.0;
        self.rateSlider.value = getRate();
        self.rateSlider.continuous = YES;
        [self.rateSlider addTarget:self action:@selector(rateChanging:) forControlEvents:UIControlEventValueChanged];
        [self.rateSlider addTarget:self action:@selector(rateChanged:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.container addSubview:self.rateSlider];
        self.rateValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.rateSlider.frame) + 10, ry + 30, valueWidth, 40)];
        self.rateValueLabel.textColor = [UIColor blackColor];
        self.rateValueLabel.textAlignment = NSTextAlignmentCenter;
        self.rateValueLabel.text = [NSString stringWithFormat:@"%.2f", getRate()];
        [self.container addSubview:self.rateValueLabel];
    }
    return self;
}

- (void)pitchChanging:(UISlider *)sender {
    self.pitchValueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
}

- (void)pitchChanged:(UISlider *)sender {
    self.pitchValueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
    storePitch(sender.value);
    if (soundTouchPtr) soundTouchPtr->setPitch(sender.value);
}

- (void)tempoChanging:(UISlider *)sender {
    self.tempoValueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
}

- (void)tempoChanged:(UISlider *)sender {
    self.tempoValueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
    storeTempo(sender.value);
    if (soundTouchPtr) soundTouchPtr->setTempo(sender.value);
}

- (void)rateChanging:(UISlider *)sender {
    self.rateValueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
}

- (void)rateChanged:(UISlider *)sender {
    self.rateValueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
    storeRate(sender.value);
    if (soundTouchPtr) soundTouchPtr->setRate(sender.value);
}

- (void)setupGestureToShow {
    UITapGestureRecognizer *showGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showSettings)];
    showGesture.numberOfTapsRequired = 2;
    showGesture.numberOfTouchesRequired = 3;
    [[UIApplication sharedApplication].keyWindow.rootViewController.view addGestureRecognizer:showGesture];
}

- (void)showSettings {
    if (!self.superview) {
        [[UIApplication sharedApplication].keyWindow addSubview:self];
    }
}

- (void)hideSettings {
    if (self.superview) {
        [self removeFromSuperview];
    }
}

@end
