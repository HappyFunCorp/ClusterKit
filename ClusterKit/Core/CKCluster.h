// CKCluster.h
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

#import <Foundation/Foundation.h>
#import <MapKit/MKAnnotation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Compute the square euclidean distance in MapKit projection.

 @param from Distance from point.
 @param to Distance to point.
 @return Euclidean distance in MapKit projection.
 */
double CKDistance(CLLocationCoordinate2D from, CLLocationCoordinate2D to);

@class CKCluster;

#pragma - CKAnnotation protocol

/**
 The CKAnnotation protocol is used to provide clusterized place information to a map. To use this protocol, you adopt it in any custom objects that store or represent a place data. Annotation objects do not provide the visual representation of the place but typically coordinate and parent cluster.
 @discussion An object that adopts this protocol must implement the coordinate and cluster properties. The other methods of this protocol are optional.
 */
@protocol CKAnnotation <MKAnnotation>

/**
 The cluster that the annotation is related to.
 */
@property (nonatomic, weak, nullable) CKCluster *cluster;

@end

#pragma - Cluster definitions

/**
 CKCluster protocol that create a kind of CKCluster at the given coordinate.
 */
@protocol CKCluster <NSObject>

/**
 Instantiates a cluster at the given coordinate.

 @param coordinate The cluster coordinate.
 @return The newly-initialized cluster.
 */+ (__kindof CKCluster *)clusterWithCoordinate:(CLLocationCoordinate2D)coordinate;

@end

/**
 The CKCluster object represents a group of annotation.
 */
@interface CKCluster : NSObject <CKCluster, MKAnnotation, NSFastEnumeration>

/**
 Cluster coordinate.
 */
@property (nonatomic) CLLocationCoordinate2D coordinate;

/**
 The number of annotations in the cluster.
 */
@property (nonatomic, readonly) NSUInteger count;

/**
 The first annotation in the cluster.
 If the cluster is empty, returns nil.
 */
@property (nonatomic, readonly, nullable) id<CKAnnotation> firstAnnotation;

/**
 The last annotation in the cluster.
 If the cluster is empty, returns nil.
 */
@property (nonatomic, readonly, nullable) id<CKAnnotation> lastAnnotation;

- (NSArray<id<CKAnnotation>> *)annotations;

/**
 Adds a given annotation to the cluster, if it is not already a member.

 @param annotation The annotation to add.
 */
- (void)addAnnotation:(id<CKAnnotation>)annotation;

/**
 Removes a given annotation from the cluster.

 @param annotation The annotation to remove.
 */
- (void)removeAnnotation:(id<CKAnnotation>)annotation;

/**
 Returns the annotation at the given index.
 If index is beyond the end of the array (that is, if index is greater than or equal to the value returned by count), an NSRangeException is raised.

 @param index An annotation index within the bounds of the array.
 @return The annotation located at index.
 */
- (id<CKAnnotation>)annotationAtIndex:(NSUInteger)index;

/**
 Returns a Boolean value that indicates whether a given annotation is present in the cluster.
 Starting at index 0, each annotation of the cluster is passed as an argument to an isEqual: message sent to the given annotation until a match is found or the end of the cluster is reached. Annotations are considered equal if isEqual: (declared in the NSObject protocol) returns YES.

 @param annotation An annotation.
 @return YES if the gievn annotation is present in the cluster, otherwise NO.
 */
- (BOOL)containsAnnotation:(id<CKAnnotation>)annotation;

/**
 Returns the annotation at the specified index.
 This method has the same behavior as the annotationAtIndex: method.
 If index is beyond the end of the cluster (that is, if index is greater than or equal to the value returned by count), an NSRangeException is raised.
 You shouldn’t need to call this method directly. Instead, this method is called when accessing an annotation by index using subscripting.

 `id<CKAnnotation> value = cluster[3]; // equivalent to [cluster annotationAtIndex:3]`

 @param index An index within the bounds of the cluster.
 @return The annotation located at index.
 */
- (id<CKAnnotation>)objectAtIndexedSubscript:(NSUInteger)index;

- (void)copyClusterValues:(CKCluster *)cluster;

@end

/**
 Cluster with centroid coordinate.
 */
@interface CKCentroidCluster : CKCluster

@end

/**
 Cluster with coordinate at the nearest annotation from centroid.
 */
@interface CKNearestCentroidCluster : CKCentroidCluster

@end

/**
 Cluster with coordinate at the bottom annotion.
 */
@interface CKBottomCluster : CKCluster

@end

NS_ASSUME_NONNULL_END
