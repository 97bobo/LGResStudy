//
//  DLGHttpClient.m
//  LGDicDemo
//
//  Created by 刘亚军 on 2018/4/2.
//  Copyright © 2018年 刘亚军. All rights reserved.
//

#import "DLGHttpClient.h"
#import "DLGHttpResponseProtocol.h"
#import <UIKit/UIKit.h>
#import "DLGCommon.h"
#import "DLGWordModel.h"
#import <MJExtension/MJExtension.h>

static CGFloat timeoutInterval = 15;
@interface DLGHttpClient ()
@property (nonatomic,assign) id<DLGHttpResponseProtocol> responder;
@end
@implementation DLGHttpClient
- (instancetype)initWithResponder:(id<DLGHttpResponseProtocol>)responder{
    if (self = [super init]) {
        self.responder = responder;
    }
    return self;
}
- (void)get:(NSString *)urlStr parameters:(NSDictionary *)parameters{
    NSString *paramsStr = @"";
    NSArray *keyArr = [parameters allKeys];
    for (NSString *key in keyArr) {
        if (paramsStr.length > 0) {
            paramsStr = [paramsStr stringByAppendingFormat:@"&%@=%@",key,[parameters objectForKey:key]];
        }else{
            paramsStr = [paramsStr stringByAppendingFormat:@"%@=%@",key,[parameters objectForKey:key]];
        }
    }
    urlStr = [NSString stringWithFormat:@"%@?%@",urlStr,paramsStr];
    DLG_Log(urlStr);
    NSURL *requestUrl = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestUrl];
    request.timeoutInterval = timeoutInterval;
    [self request:request];
}
- (void)post:(NSString *)urlStr parameters:(NSDictionary *)parameters{
    DLG_Log(urlStr);
    if (![NSJSONSerialization isValidJSONObject:parameters]) {
        DLG_Log(@"格式不正确，不能被序列化");
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.responder respondsToSelector:@selector(failure:)]) {
                [self.responder failure:[NSError errorWithDomain:@"DLGErrorDamain" code:10000 userInfo:@{NSLocalizedDescriptionKey:@"格式不正确，不能被序列化"}]];
            }
        });
        return;
    }
    NSURL *requestUrl = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestUrl];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.timeoutInterval = timeoutInterval;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:NULL];
    DLG_Log([[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
    [self request:request];
}
- (void)request:(NSURLRequest *) request{
     __weak typeof(self) weakSelf = self;
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        if (error) {
            DLG_Log(error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([weakSelf.responder respondsToSelector:@selector(failure:)]) {
                    [weakSelf.responder failure:error];
                }
            });
        }else{
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            DLGWordModel *wordModel = [DLGWordModel mj_objectWithKeyValues:dic];
            NSMutableArray *senArr = [NSMutableArray array];
            for (CxCollectionModel *cxModel in wordModel.cxCollection) {
                for (MeanCollectionModel *meanModel in cxModel.meanCollection) {
                    if (!DLG_IsEmpty(meanModel.senCollection)) {
                        [senArr addObjectsFromArray:meanModel.senCollection];
                    }
                }
            }
            if (senArr.count > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([weakSelf.responder respondsToSelector:@selector(success:)]) {
                        [weakSelf.responder success:wordModel];
                    }
                });
            }else{
                DLG_Log(@"查询失败");
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([weakSelf.responder respondsToSelector:@selector(failure:)]) {
                        [weakSelf.responder failure:[NSError errorWithDomain:@"DLGErrorDamain" code:10010 userInfo:@{NSLocalizedDescriptionKey:@"查询失败"}]];
                    }
                });
            }
        }
    }];
    [dataTask resume];
}
@end
