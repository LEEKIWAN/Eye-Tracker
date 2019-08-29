//
//  ViewController.m
//  Eye Tracker
//
//  Created by kiwan on 16/08/2019.
//  Copyright © 2019 kiwan. All rights reserved.
//

#import <ARKit/ARKit.h>
#import "ViewController.h"


@interface ViewController () <ARSCNViewDelegate, ARSessionDelegate>

@property (weak, nonatomic) IBOutlet ARSCNView *sceneView;

@property (weak, nonatomic) IBOutlet UIView *eyePositionIndicatorView;
@property (weak, nonatomic) IBOutlet UIView *eyePositionIndicatorCenterView;

@property (strong, nonatomic) SCNNode *faceNode;
@property (strong, nonatomic) SCNNode *eyeLeftNode;
@property (strong, nonatomic) SCNNode *eyeRightNode;

@property (strong, nonatomic) SCNNode *virtualPhoneNode;
@property (strong, nonatomic) SCNNode *virtualScreenNode;

@property (strong, nonatomic) SCNNode *lookAtTargetEyeLNode;
@property (strong, nonatomic) SCNNode *lookAtTargetEyeRNode;


@property (nonatomic) CGSize phoneScreenSize;       //It's the physical screen size in meters.
@property (nonatomic) CGSize phoneScreenPointSize;


@property (weak, nonatomic) IBOutlet UILabel *lookAtPositionLabelX;
@property (weak, nonatomic) IBOutlet UILabel *lookAtPositionLabelY;
@property (weak, nonatomic) IBOutlet UILabel *distanceLabel;
@property (weak, nonatomic) IBOutlet UILabel *timerLabel;

@property (nonatomic) NSTimer *timer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    [self setInitValue];
    [self setInitUI];
    [self setScenegraph];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    ARFaceTrackingConfiguration *configuration = [[ARFaceTrackingConfiguration alloc] init];
    configuration.lightEstimationEnabled = YES;
    
    [self.sceneView.session runWithConfiguration:configuration options:ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.sceneView.session pause];
}



#pragma mark - Initialize
- (void)setInitUI {
    _eyePositionIndicatorCenterView.layer.cornerRadius = _eyePositionIndicatorCenterView.frame.size.height / 2;
    _eyePositionIndicatorView.layer.cornerRadius = _eyePositionIndicatorView.frame.size.height / 2;
}

- (void)setInitValue {
    self.sceneView.delegate = self;
    self.sceneView.session.delegate = self;
    
    self.faceNode = [SCNNode node];
    
    SCNNode *leftNode = [SCNNode node];
    leftNode.geometry = [SCNCone coneWithTopRadius:0.005 bottomRadius:0 height:0.2];
    leftNode.eulerAngles = SCNVector3Make(-M_PI / 2, 0, 0);
    leftNode.position = SCNVector3Make(0, 0, 0.1);
    
    SCNNode *parentLeftNode = [SCNNode node];
    [parentLeftNode addChildNode:leftNode];
    
    self.eyeLeftNode = parentLeftNode;
    
    SCNNode *rightNode = [SCNNode node];
    rightNode.geometry = [SCNCone coneWithTopRadius:0.005 bottomRadius:0 height:0.2];;
    rightNode.eulerAngles = SCNVector3Make(-M_PI / 2, 0, 0);
    rightNode.position = SCNVector3Make(0.0, 0.0, 0.1);
    
    SCNNode *parentRightNode = [SCNNode node];
    [parentRightNode addChildNode:rightNode];
    
    self.eyeRightNode = parentRightNode;
    
    self.virtualPhoneNode = [SCNNode node];
    
    SCNPlane *screenGeometry = [SCNPlane planeWithWidth:1 height:1];
    screenGeometry.firstMaterial.doubleSided = YES;
    screenGeometry.firstMaterial.diffuse.contents = UIColor.greenColor;
    
    self.virtualScreenNode = [SCNNode nodeWithGeometry:screenGeometry];
    
    self.lookAtTargetEyeLNode = [SCNNode node];
    self.lookAtTargetEyeRNode = [SCNNode node];
    
    self.phoneScreenSize = CGSizeMake(0.0623908297, 0.135096943231532);
    self.phoneScreenPointSize = CGSizeMake(375, 812);
    
}

- (void)setScenegraph {
    [self.faceNode addChildNode:self.eyeLeftNode];
    [self.faceNode addChildNode:self.eyeRightNode];
    
    [self.sceneView.scene.rootNode addChildNode:self.faceNode];
    
    
    [self.virtualPhoneNode addChildNode:self.virtualScreenNode];
    [self.sceneView.scene.rootNode addChildNode:self.virtualPhoneNode];
    
    [self.eyeLeftNode addChildNode:self.lookAtTargetEyeLNode];
    [self.eyeRightNode addChildNode:self.lookAtTargetEyeRNode];
    
    self.lookAtTargetEyeLNode.position = SCNVector3Make(0, 0, 2);
    self.lookAtTargetEyeRNode.position = SCNVector3Make(0, 0, 2);
}

#pragma mark - ARSCNViewDelegate
- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time {
    self.virtualPhoneNode.transform = self.sceneView.pointOfView.transform;
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    self.faceNode.transform = node.transform;
    
    [self updateWithFaceAnchor:(ARFaceAnchor *)anchor];
    
    [self updateTimerFaceDisappear];
}


- (void)updateWithFaceAnchor:(ARFaceAnchor *)anchor {
    self.eyeRightNode.simdTransform = anchor.rightEyeTransform;
    self.eyeLeftNode.simdTransform = anchor.leftEyeTransform;
    
    __block CGPoint eyeLeftLookAt;
    __block CGPoint eyeRightLookAt;
    
    
    NSDictionary<ARBlendShapeLocation, NSNumber*> *face = anchor.blendShapes;
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray<SCNHitTestResult *> *phoneScreenEyeRHitTestResults = [self.virtualPhoneNode hitTestWithSegmentFromPoint:self.lookAtTargetEyeRNode.worldPosition toPoint:self.eyeRightNode.worldPosition options:nil];
        NSArray<SCNHitTestResult *> *phoneScreenEyeLHitTestResults = [self.virtualPhoneNode hitTestWithSegmentFromPoint:self.lookAtTargetEyeLNode.worldPosition toPoint:self.eyeLeftNode.worldPosition options:nil];
        
        for(SCNHitTestResult *result in phoneScreenEyeRHitTestResults) {
            CGFloat x = result.localCoordinates.x / ( self.phoneScreenSize.width / 2) * self.phoneScreenPointSize.width;
            CGFloat y = result.localCoordinates.y / ( self.phoneScreenSize.height / 2) * self.phoneScreenPointSize.height;
            
            NSLog(@"%f , %f", x, y );
            eyeRightLookAt = CGPointMake(x, y);
        }
        
        for(SCNHitTestResult *result in phoneScreenEyeLHitTestResults) {
            CGFloat x = result.localCoordinates.x / ( self.phoneScreenSize.width / 2) * self.phoneScreenPointSize.width;
            CGFloat y = result.localCoordinates.y / ( self.phoneScreenSize.height / 2) * self.phoneScreenPointSize.height;
            
            eyeLeftLookAt = CGPointMake(x, y);
        }
        
        CGFloat eyeLookAtPositionX = (eyeRightLookAt.x + eyeLeftLookAt.x) / 2;
        CGFloat eyeLookAtPositionY = (eyeRightLookAt.y + eyeLeftLookAt.y) / 2;

        self.eyePositionIndicatorView.transform = CGAffineTransformMakeTranslation(eyeLookAtPositionX, -eyeLookAtPositionY);
        
        
        self.lookAtPositionLabelX.text = [NSString stringWithFormat:@"%.0f", round(eyeLookAtPositionX + self.phoneScreenPointSize.width / 2)];
        self.lookAtPositionLabelY.text = [NSString stringWithFormat:@"%.0f", round(eyeLookAtPositionY + self.phoneScreenPointSize.height / 2)];
        
        
        SCNVector3 leftNodeVector = self.eyeLeftNode.worldPosition;
        SCNVector3 rightNodeVector = self.eyeRightNode.worldPosition;
        
        CGFloat distanceL = [self getDistanceBy:leftNodeVector];
        CGFloat distanceR = [self getDistanceBy:rightNodeVector];
        
        CGFloat distance = roundf((distanceR + distanceL) / 2 * 100);
        
        self.distanceLabel.text = [NSString stringWithFormat:@"%.0fcm", distance];

        
        
    });
    
}


- (CGFloat)getDistanceBy:(SCNVector3)vector {
    return sqrtf(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z);
}


- (void)updateTimerFaceDisappear {
    if(self.timer != nil) {
        [self.timer invalidate];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timerLabel.text = @"3";
    });
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
}

- (void)timerFired:(NSTimer *)timer {
    dispatch_async(dispatch_get_main_queue(), ^{
        int value = self.timerLabel.text.intValue - 1;
        
        self.timerLabel.text = [NSString stringWithFormat:@"%d", value];
        
        if(value == 0) {
            [self.timer invalidate];

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Face is Disappeared" message:nil preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *confirmButton = [UIAlertAction actionWithTitle:@"확인" style:UIAlertActionStyleDefault handler:nil];
            [alertController addAction:confirmButton];
            [self presentViewController:alertController animated:YES completion:nil];
        }
    });
    
}


@end
