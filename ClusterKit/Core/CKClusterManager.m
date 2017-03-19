// CKClusterManager.m
//
// Copyright © 2017 Hulab. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "CKClusterManager.h"
#import "CKQuadTree.h"
#import "CKMap.h"

const double kCKMarginFactorWorld = -1;

BOOL CLLocationCoordinateEqual(CLLocationCoordinate2D coordinate1, CLLocationCoordinate2D coordinate2) {
    return (fabs(coordinate1.latitude - coordinate2.latitude) <= DBL_EPSILON &&
            fabs(coordinate1.longitude - coordinate2.longitude) <= DBL_EPSILON);
}

@interface CKClusterManager () <CKAnnotationTreeDelegate>
@property (nonatomic,strong) id<CKAnnotationTree> tree;
@property (nonatomic,strong) CKCluster *selectedCluster;
@property (nonatomic) MKMapRect visibleMapRect;
@end

@implementation CKClusterManager {
    NSMutableArray<CKCluster *> *_clusters;
    dispatch_queue_t _queue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.algorithm = [CKClusterAlgorithm new];
        self.maxZoomLevel = 20;
        self.marginFactor = kCKMarginFactorWorld;
        self.animationDuration = .5;
        self.animationOptions = UIViewAnimationOptionCurveEaseOut;
        _clusters = [NSMutableArray new];

        _queue = dispatch_queue_create("com.hulab.cluster", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)setMap:(id<CKMap>)map {
    _map = map;
    _visibleMapRect = map.visibleMapRect;
}

- (void)updateClustersIfNeeded {
    if (!self.map) return;

    MKMapRect visibleMapRect = self.map.visibleMapRect;

    // Zoom update
    if (fabs(self.visibleMapRect.size.width - visibleMapRect.size.width) > 0.1f) {
        [self updateMapRect:visibleMapRect animated:(self.animationDuration > 0)];

    } else if (self.marginFactor != kCKMarginFactorWorld) {

        // Translation update
        if(fabs(self.visibleMapRect.origin.x - visibleMapRect.origin.x) > self.visibleMapRect.size.width * self.marginFactor / 2||
           fabs(self.visibleMapRect.origin.y - visibleMapRect.origin.y) > self.visibleMapRect.size.height* self.marginFactor / 2 ) {
            [self updateMapRect:visibleMapRect animated:NO];
        }
    }
}

- (void)updateClusters {
    if (!self.map) return;

    MKMapRect visibleMapRect = self.map.visibleMapRect;

    BOOL animated = (self.animationDuration > 0) && fabs(self.visibleMapRect.size.width - visibleMapRect.size.width) > 0.1f;
    [self updateMapRect:visibleMapRect animated:animated];
}

- (NSArray<CKCluster *> *)clusters {
    if (self.selectedCluster) {
        return [_clusters arrayByAddingObject:self.selectedCluster];
    }
    return _clusters.copy;
}

#pragma mark Manage Annotations

- (void)setAnnotations:(NSArray<id<CKAnnotation>> *)annotations {
    self.tree = [[CKQuadTree alloc] initWithAnnotations:annotations];
    self.tree.delegate = self;
    [self updateClusters];
}

- (NSArray<id<CKAnnotation>> *)annotations {
    return self.tree ? self.tree.annotations : @[];
}

- (void)addAnnotation:(id<CKAnnotation>)annotation {
    self.annotations = [self.annotations arrayByAddingObject:annotation];
}

- (void)addAnnotations:(NSArray<id<CKAnnotation>> *)annotations {
    self.annotations = [self.annotations arrayByAddingObjectsFromArray:annotations];
}

- (void)removeAnnotation:(id<CKAnnotation>)annotation {
    NSMutableArray *annotations = [self.annotations mutableCopy];
    [annotations removeObject:annotation];
    self.annotations = annotations;
}

- (void)removeAnnotations:(NSArray<id<CKAnnotation>> *)annotations {
    NSMutableArray *_annotations = [self.annotations mutableCopy];
    [_annotations removeObjectsInArray:annotations];
    self.annotations = _annotations;
}

- (void)selectAnnotation:(nullable id<CKAnnotation>)annotation animated:(BOOL)animated {
    CKCluster *cluster = nil;

    if (annotation) {
        if (!annotation.cluster || annotation.cluster.count > 1) {
            cluster = [self.algorithm clusterWithCoordinate:annotation.coordinate];
            [cluster addAnnotation:annotation];
            [self.map addCluster:cluster];
        } else {
            cluster = annotation.cluster;
        }
    }
    [self setSelectedCluster:cluster animated:animated];
}

- (void)deselectAnnotation:(id<CKAnnotation>)annotation animated:(BOOL)animated {
    if (annotation == self.selectedAnnotation) {
        [self selectAnnotation:nil animated:animated];
    }
}

- (id<CKAnnotation>)selectedAnnotation {
    return self.selectedCluster.firstAnnotation;
}

- (void)setSelectedCluster:(CKCluster *)selectedCluster animated:(BOOL)animated {
    if (_selectedCluster && selectedCluster != _selectedCluster) {
        [_clusters addObject:_selectedCluster];
        [self.map deselectCluster:_selectedCluster animated:animated];
    }
    if (selectedCluster) {
        [_clusters removeObject:selectedCluster];
        [self.map selectCluster:selectedCluster animated:animated];
    }
    _selectedCluster = selectedCluster;
}

#pragma mark - Private

- (void)updateMapRect:(MKMapRect)visibleMapRect animated:(BOOL)animated {
    
    if (! self.tree || MKMapRectIsNull(visibleMapRect) || MKMapRectIsEmpty(visibleMapRect)) {
        return;
    }
    
    NSMutableArray <CKCluster *>* clusters = [NSMutableArray new];
    
    if (MKMapRectSpans180thMeridian(visibleMapRect)) {
        MKMapRect outsideMapRect = MKMapRectRemainder(visibleMapRect);
        MKMapRect insideMapRect = MKMapRectIntersection(visibleMapRect, MKMapRectWorld);
        [clusters addObjectsFromArray:[self createClustersInRect:outsideMapRect existingClusters:_clusters]];
        [clusters addObjectsFromArray:[self createClustersInRect:insideMapRect existingClusters:_clusters]];
    } else {
        [clusters addObjectsFromArray:[self createClustersInRect:visibleMapRect existingClusters:_clusters]];
    }

    _clusters = clusters;
    _visibleMapRect = visibleMapRect;
}

- (NSMutableArray <CKCluster *>*)createClustersInRect:(MKMapRect)rect existingClusters:(NSArray <CKCluster *>*)existingClusters {
    MKMapRect clusterMapRect = MKMapRectWorld;
    if (self.marginFactor != kCKMarginFactorWorld) {
        clusterMapRect = MKMapRectInset(rect,
                                        self.marginFactor * rect.size.width,
                                        self.marginFactor * rect.size.height);
    }
    
    double zoom = self.map.zoom;
    CKClusterAlgorithm *algorithm = (zoom < self.maxZoomLevel)? self.algorithm : [CKClusterAlgorithm new];
    NSArray *clusters = [algorithm clustersInRect:rect zoom:zoom tree:self.tree];
    NSMutableArray *toReplace = clusters.mutableCopy;
    NSMutableArray *toRemove = existingClusters.mutableCopy;
    
    [clusters enumerateObjectsUsingBlock:^(CKCluster *newCluster, NSUInteger idx, BOOL * _Nonnull stop) {
        if (self.highlightedAnnotation && [newCluster containsAnnotation:self.highlightedAnnotation]) {
            for (CKCluster *oldCluster in _clusters) {
                if ([oldCluster containsAnnotation:self.highlightedAnnotation]) {
                    [toRemove removeObject: oldCluster];
                    [oldCluster copyClusterValues:newCluster];
                    toReplace[idx] = oldCluster;
                    break;
                }
            }
            [self.delegate clusterManager:self highlighted:newCluster];
        } else {
            [self.map addCluster:newCluster];
        }
        
    }];
    
    for (CKCluster *cluster in toRemove) {
        [self.map removeCluster:cluster];
    }
    
    return toReplace;
}

#pragma mark <KPAnnotationTreeDelegate>

- (BOOL)annotationTree:(id<CKAnnotationTree>)annotationTree shouldExtractAnnotation:(id<CKAnnotation>)annotation {
    if (annotation == self.selectedAnnotation) {
        return NO;
    }
    if ([self.delegate respondsToSelector:@selector(clusterManager:shouldClusterAnnotation:)]) {
        return [self.delegate clusterManager:self shouldClusterAnnotation:annotation];
    }
    return YES;
}

@end
