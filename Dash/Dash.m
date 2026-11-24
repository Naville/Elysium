
//clang -shared -undefined dynamic_lookup -fobjc-arc -o /Applications/Dash.app/Contents/MacOS/libDash.dylib Dash.m ../fishhook/fishhook.c
//optool install -c load -p @executable_path/libDash.dylib -t /Applications/Dash.app/Contents/MacOS/Dash
//codesign --remove-signature /Applications/Dash.app/Contents/MacOS/Dash
//Fucking Stupid License Model
//10/10 will definitely not purchase again
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#include <objc/runtime.h>
#include "../fishhook/fishhook.h"
#include <dlfcn.h>
#include <string.h>
#include <mach-o/dyld.h>
static NSData* pubKey = nil;
static __typeof__(&SecItemImport) orig_SecItemImport = NULL;

static BOOL GenerateKeyPair(SecKeyRef *outPub, SecKeyRef *outPriv) {
    NSDictionary *params = @{
        (id)kSecAttrKeyType       : (id)kSecAttrKeyTypeRSA,
        (id)kSecAttrKeySizeInBits : @1024,
        (id)kSecAttrIsPermanent   : @NO,
    };
    CFErrorRef err = NULL;
    SecKeyRef priv = SecKeyCreateRandomKey((__bridge CFDictionaryRef)params, &err);
    if (!priv) {
        NSLog(@"[!] SecKeyCreateRandomKey: %@", (__bridge NSError *)err);
        if (err) CFRelease(err);
        return NO;
    }
    *outPriv = priv;
    *outPub = SecKeyCopyPublicKey(priv);
    return *outPub != NULL;
}

static NSData *PublicKeyPEM(SecKeyRef pubKey) {
    CFDataRef out = NULL;
    OSStatus st = SecItemExport(pubKey, kSecFormatOpenSSL, kSecItemPemArmour,
                                NULL, &out);
    if (st != errSecSuccess || !out) {
        NSLog(@"[!] SecItemExport status=%d", st);
        if (out) CFRelease(out);
        return nil;
    }
    return (__bridge_transfer NSData *)out;
}

static NSData *PrivateKeyPEM(SecKeyRef privKey) {
    CFDataRef out = NULL;
    OSStatus st = SecItemExport(privKey, kSecFormatOpenSSL, kSecItemPemArmour,
                                NULL, &out);
    if (st != errSecSuccess || !out) {
        NSLog(@"[!] SecItemExport(private) status=%d", st);
        if (out) CFRelease(out);
        return nil;
    }
    return (__bridge_transfer NSData *)out;
}

static SecKeyRef ImportKey(NSData *pemData) {
    SecExternalFormat fmt = kSecFormatOpenSSL;           // 未加密 OpenSSL PEM 私钥
    SecExternalItemType type = kSecItemTypePrivateKey;
    SecItemImportExportKeyParameters kp = {0};
    kp.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;

    CFArrayRef outItems = NULL;
    OSStatus st = SecItemImport((__bridge CFDataRef)pemData, NULL,
                                &fmt, &type, 0,
                                &kp, NULL, &outItems);
    if (st != errSecSuccess || !outItems || CFArrayGetCount(outItems) == 0) {
        NSLog(@"[!] SecItemImport status=%d", st);
        if (outItems) CFRelease(outItems);
        return NULL;
    }
    SecKeyRef key = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(outItems, 0));
    CFRelease(outItems);
    return key;
}

static NSData *SignData(SecKeyRef privKey, NSData *message) {
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(message.bytes, (CC_LONG)message.length, digest);

    NSMutableData *em = [NSMutableData dataWithLength:128];   // 1024-bit 模数块长
    uint8_t *p = (uint8_t *)em.mutableBytes;
    p[0] = 0x00; p[1] = 0x01;
    memset(p + 2, 0xFF, 128 - 3 - CC_SHA1_DIGEST_LENGTH);
    p[128 - 1 - CC_SHA1_DIGEST_LENGTH] = 0x00;
    memcpy(p + 128 - CC_SHA1_DIGEST_LENGTH, digest, CC_SHA1_DIGEST_LENGTH);

    CFErrorRef err = NULL;
    CFDataRef sig = SecKeyCreateSignature(privKey,
                                          kSecKeyAlgorithmRSASignatureRaw,
                                          (__bridge CFDataRef)em, &err);
    if (!sig) {
        NSLog(@"[!] SecKeyCreateSignature(Raw): %@", (__bridge NSError *)err);
        if (err) CFRelease(err);
        return nil;
    }
    return (__bridge_transfer NSData *)sig;
}
static NSData *CanonicalLicenseForm(NSDictionary *license) {
    NSMutableArray *keys = [[license allKeys] mutableCopy];
    [keys removeObject:@"Signature"];
    [keys sortUsingSelector:@selector(compare:)];
    NSMutableData *acc = [NSMutableData data];
    for (NSString *k in keys) {
        NSString *v = [license[k] description];
        [acc appendData:[v dataUsingEncoding:NSUTF8StringEncoding]];
    }
    return acc;
}
static NSDictionary *MakeLicensePlist(NSString *email, NSString *subscriptionID,
                                      NSInteger dashVersion,
                                      NSTimeInterval issuedAt, NSTimeInterval validUntil,
                                      SecKeyRef privKey) {
    NSDictionary *fields = @{
        @"Email"          : email,
        @"SubscriptionID" : subscriptionID,
        @"Timestamp"      : [NSString stringWithFormat:@"%.0f", issuedAt],
        @"ValidUntil"     : [NSString stringWithFormat:@"%.0f", validUntil],
        @"Version"        : [NSString stringWithFormat:@"%ld", (long)dashVersion],
    };
    NSData *sig = SignData(privKey, CanonicalLicenseForm(fields));
    NSCParameterAssert(sig.length == 128);
    NSMutableDictionary *plist = [fields mutableCopy];
    plist[@"Signature"] = sig;
    return plist;
}
// 只对 Dash 主二进制发起的 SecItemImport 换公钥(Sparkle 等框架也会导入密钥/证书,不能误伤)
static BOOL RetAddrInMainBinary(void *retAddr) {
    static const char *mainPath = NULL;
    Dl_info info;
    if (retAddr == NULL || dladdr(retAddr, &info) == 0 || info.dli_fname == NULL) {
        return NO;
    }
    if (mainPath == NULL) {
        const char *name = _dyld_get_image_name(0);
        mainPath = (name != NULL) ? name : "";
    }
    return strcmp(info.dli_fname, mainPath) == 0;
}

static OSStatus hooked_SecItemImport(
    CFDataRef importedData,
    CFStringRef fileNameOrExtension,
    SecExternalFormat *inputFormat,
    SecExternalItemType *itemType,
    SecItemImportExportFlags flags,
    const SecItemImportExportKeyParameters *keyParams,
    SecKeychainRef importKeychain,
    CFArrayRef *outItems)
{
    fprintf(stderr, "[hook] SecItemImport: dataLength=%ld\n",
            importedData ? (long)CFDataGetLength(importedData) : 0L);

    if (orig_SecItemImport == NULL) {
        fprintf(stderr, "[hook] Original SecItemImport is unavailable\n");
        return errSecUnimplemented;
    }

    // Dash 导入 Kapeli 公钥(276B OpenSSL PEM)时,换成我们 key.dat 对应的公钥 PEM。
    // 原版验证只有"结果==kCFBooleanTrue"和 BlockedLicenses 签名黑名单,没有对公钥本身的自检。
    if (pubKey != nil && importedData != NULL &&
        CFDataGetLength(importedData) < 512 &&
        RetAddrInMainBinary(__builtin_return_address(0))) {
        fprintf(stderr, "[hook] Swapping pubkey: %ld -> %lu bytes\n",
                (long)CFDataGetLength(importedData), (unsigned long)pubKey.length);
        importedData = (__bridge CFDataRef)pubKey;
    }

    OSStatus status = orig_SecItemImport(
        importedData,
        fileNameOrExtension,
        inputFormat,
        itemType,
        flags,
        keyParams,
        importKeychain,
        outItems
    );

    fprintf(stderr, "[hook] SecItemImport returned %d\n", (int)status);

    // 仅在成功且确实返回了数组时访问结果。
    if (status == errSecSuccess && outItems != NULL && *outItems != NULL) {
        fprintf(stderr, "[hook] Imported item count: %ld\n",
                (long)CFArrayGetCount(*outItems));
    }

    return status;
}

// 联网激活 no-op:activateWithSubscriptionID: 是唯一的订阅验证出口,四个调用点
// (初始化 block、30 分钟定时器、恢复购买、手动激活)全部经过这里
static void blocked_activateWithSubscriptionID(id self, SEL _cmd, id subscriptionID, BOOL shouldAlert) {
    NSLog(@"[+][libDash] blocked activateWithSubscriptionID:%@ shouldAlert:%d",
          subscriptionID, (int)shouldAlert);
}

__attribute__((constructor))
static void fool() {
    NSLog(@"[+][libDash] Inj3ct3d");
    NSFileManager *FM = [NSFileManager defaultManager];
    NSURL *plistPath = [NSURL fileURLWithPath:[objc_getClass("DHInApp") performSelector:@selector(licenseFile)]];
    NSURL* keyPath = [[plistPath URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"key.dat"];
    SecKeyRef pub = NULL, priv = NULL;

    if ([FM fileExistsAtPath:keyPath.path]) {
        priv = ImportKey([NSData dataWithContentsOfURL:keyPath]);
        if (priv) {
            pub = SecKeyCopyPublicKey(priv);
        }
        if (!pub) {
            NSLog(@"[!][libDash] Failed to restore key pair from key.dat, regenerating");
            if (priv) { CFRelease(priv); priv = NULL; }
        }
    }

    if (!pub) {
        if (!GenerateKeyPair(&pub, &priv)) {
            NSLog(@"[!][libDash] GenerateKeyPair failed");
            return;
        }
        NSData *privPEM = PrivateKeyPEM(priv);
        if (privPEM == nil || ![privPEM writeToURL:keyPath atomically:YES]) {
            NSLog(@"[!][libDash] Failed to persist private key");
            CFRelease(pub);
            CFRelease(priv);
            return;
        }
    }

    pubKey = PublicKeyPEM(pub);
    if (pubKey == nil) {
        NSLog(@"[!][libDash] Failed to Serialize PublicKey to String");
        CFRelease(pub);
        CFRelease(priv);
        return;
    }
    NSLog(@"[+][libDash] Public Key: %@", pubKey);
    struct rebinding binding = {
            .name        = "SecItemImport",
            .replacement = (void *)hooked_SecItemImport,
            .replaced    = (void **)&orig_SecItemImport,
    };

    int rc = rebind_symbols(&binding, 1);
    if (rc != 0) {
        fprintf(stderr, "[hook] rebind_symbols failed: %d\n", rc);
    }

    // 换掉联网激活实现;失败(比如未来版本改了选择子名)则退回空 SubscriptionID 方案
    BOOL swizzled = NO;
    Method activate = class_getInstanceMethod(objc_getClass("DHInApp"),
                                              sel_registerName("activateWithSubscriptionID:shouldAlert:"));
    if (activate != NULL) {
        method_setImplementation(activate, (IMP)blocked_activateWithSubscriptionID);
        swizzled = YES;
        NSLog(@"[+][libDash] activateWithSubscriptionID: neutralized");
    } else {
        NSLog(@"[!][libDash] activateWithSubscriptionID: not found, falling back to empty SubscriptionID");
    }

    if (![FM fileExistsAtPath:plistPath.path]) {
        NSDictionary *plist = MakeLicensePlist(@"example@example.com",
                                        swizzled ? @"d4c3b2a1-9e8f-4a7b-8c6d-5e4f3a2b1c0d" : @"",
                                        8,
                                        [[NSDate date] timeIntervalSince1970],
                                        [[NSDate dateWithTimeIntervalSinceNow:630720000.0] timeIntervalSince1970],   // +20 年
                                        priv);
        [plist writeToURL:plistPath atomically:YES];
    }
    CFRelease(pub);
    CFRelease(priv);
}
