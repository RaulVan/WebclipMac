//
//  CMSHelper.m
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

#import "CMSHelper.h"
#import <Security/Security.h>

// 错误域
NSString * const CMSHelperErrorDomain = @"CMSHelperErrorDomain";

// 错误代码
typedef NS_ENUM(NSInteger, CMSHelperErrorCode) {
    CMSHelperErrorCodeIdentityLoadFailed = 1000,
    CMSHelperErrorCodeEncoderCreationFailed,
    CMSHelperErrorCodeFailedToAddSigner,
    CMSHelperErrorCodeFailedToUpdateContent,
    CMSHelperErrorCodeFailedToEncodeContent,
    CMSHelperErrorCodeCertificateImportFailed,
    CMSHelperErrorCodeIdentityCreationFailed,
    CMSHelperErrorCodeInvalidPassword,
    CMSHelperErrorCodeInvalidData
};

@implementation CMSHelper

// 从P12数据获取SecIdentity
+ (SecIdentityRef)getIdentityFromP12Data:(NSData *)p12Data 
                                password:(NSString *)password 
                                   error:(NSError **)error {
    
    // 导入选项
    NSDictionary *options = @{
        (__bridge NSString *)kSecImportExportPassphrase: password
    };
    
    // 导入p12数据
    CFArrayRef items = NULL;
    OSStatus importStatus = SecPKCS12Import((__bridge CFDataRef)p12Data, 
                                          (__bridge CFDictionaryRef)options, 
                                          &items);
    
    // 密码错误
    if (importStatus == errSecAuthFailed) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeInvalidPassword
                                     userInfo:@{NSLocalizedDescriptionKey: @"证书密码不正确"}];
        }
        return NULL;
    }
    
    // 其他导入错误
    if (importStatus != errSecSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeCertificateImportFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: [NSString stringWithFormat:@"导入证书失败 (代码: %d)", (int)importStatus]
                                     }];
        }
        return NULL;
    }
    
    // 确保数组不为空
    if (items == NULL || CFArrayGetCount(items) == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeIdentityCreationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"证书导入结果为空"}];
        }
        return NULL;
    }
    
    // 获取导入的身份信息
    NSDictionary *firstItem = CFArrayGetValueAtIndex(items, 0);
    SecIdentityRef identity = (__bridge SecIdentityRef)(firstItem[(__bridge NSString *)kSecImportItemIdentity]);
    
    if (identity == NULL) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeIdentityCreationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"无法创建身份标识"}];
        }
        CFRelease(items);
        return NULL;
    }
    
    // 增加引用计数，因为items即将被释放
    CFRetain(identity);
    CFRelease(items);
    
    return identity;
}

// 使用CMS API签名数据
+ (NSData *)signDataWithCMS:(NSData *)data 
                   identity:(SecIdentityRef)identity 
                      error:(NSError **)error {
    
    CMSEncoderRef encoder = NULL;
    
    // 创建CMS编码器
    OSStatus status = CMSEncoderCreate(&encoder);
    if (status != errSecSuccess || encoder == NULL) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeEncoderCreationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"无法创建CMS签名编码器"}];
        }
        return nil;
    }
    
    // 添加签名者身份
    status = CMSEncoderAddSigners(encoder, identity);
    if (status != errSecSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeFailedToAddSigner
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: [NSString stringWithFormat:@"添加签名者失败 (代码: %d)", (int)status]
                                     }];
        }
        CFRelease(encoder);
        return nil;
    }
    
    // 设置签名内容
    status = CMSEncoderUpdateContent(encoder, [data bytes], [data length]);
    if (status != errSecSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeFailedToUpdateContent
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: [NSString stringWithFormat:@"更新签名内容失败 (代码: %d)", (int)status]
                                     }];
        }
        CFRelease(encoder);
        return nil;
    }
    
    // 生成签名数据
    CFDataRef signedData = NULL;
    status = CMSEncoderCopyEncodedContent(encoder, &signedData);
    if (status != errSecSuccess || signedData == NULL) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeFailedToEncodeContent
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: [NSString stringWithFormat:@"编码签名内容失败 (代码: %d)", (int)status]
                                     }];
        }
        CFRelease(encoder);
        return nil;
    }
    
    // 转换为NSData
    NSData *result = (__bridge_transfer NSData *)signedData;
    CFRelease(encoder);
    
    return result;
}

// 公开的签名方法
+ (NSData *)signData:(NSData *)data 
        withP12Data:(NSData *)p12Data 
           password:(NSString *)password 
              error:(NSError **)error {
    
    // 参数验证
    if (data == nil || data.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeInvalidData
                                     userInfo:@{NSLocalizedDescriptionKey: @"无效的数据"}];
        }
        return nil;
    }
    
    if (p12Data == nil || p12Data.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CMSHelperErrorDomain
                                         code:CMSHelperErrorCodeInvalidData
                                     userInfo:@{NSLocalizedDescriptionKey: @"无效的证书数据"}];
        }
        return nil;
    }
    
    // 步骤1: 从P12数据获取SecIdentity
    SecIdentityRef identity = [self getIdentityFromP12Data:p12Data password:password error:error];
    if (identity == NULL) {
        return nil; // 错误已经在getIdentityFromP12Data中设置
    }
    
    // 步骤2: 使用SecCMSEncoder对数据进行签名
    NSData *signedData = [self signDataWithCMS:data identity:identity error:error];
    
    // 释放身份引用
    CFRelease(identity);
    
    return signedData;
}

// 简化的签名方法，内部处理错误并打印到控制台
+ (NSData *)signData:(NSData *)data 
        withP12Data:(NSData *)p12Data 
           password:(NSString *)password {
    NSError *error = nil;
    NSData *result = [self signData:data withP12Data:p12Data password:password error:&error];
    
    // 如果有错误，打印到控制台以便调试
    if (error != nil) {
        NSLog(@"CMSHelper签名失败: %@ (代码: %ld)", error.localizedDescription, (long)error.code);
    }
    
    return result;
}

// 简化的CMS签名方法，内部处理错误并打印到控制台
+ (NSData *)signDataWithCMS:(NSData *)data 
                   identity:(SecIdentityRef)identity {
    NSError *error = nil;
    NSData *result = [self signDataWithCMS:data identity:identity error:&error];
    
    // 如果有错误，打印到控制台以便调试
    if (error != nil) {
        NSLog(@"CMSHelper CMS签名失败: %@ (代码: %ld)", error.localizedDescription, (long)error.code);
    }
    
    return result;
}

// 检查签名功能是否可用
+ (BOOL)isSigningAvailable {
    CMSEncoderRef encoder = NULL;
    OSStatus result = CMSEncoderCreate(&encoder);
    
    // 如果可以创建编码器，则释放它
    if (result == errSecSuccess && encoder != NULL) {
        CFRelease(encoder);
        return YES;
    }
    
    return NO;
}

@end 
