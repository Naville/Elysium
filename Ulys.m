
//clang -fobjc-arc -framework Foundation -mmacosx-version-min=10.6 -shared -undefined dynamic_lookup -o /Applications/UlyssesMac.app/Contents/MacOS/libUlys.dylib Ulys.m
//Fucking Stupid License Model
//10/10 will definitely not purchase again
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
@interface ULStorePageStaticText
- (id)initWithText:(id)arg1 style:(unsigned long long)arg2 tint:(unsigned long long)arg3 key:(id)arg4;
@end

static BOOL yes(id obj){
  return true;
}
static NSDate* expDate(id obj){
  return [NSDate dateWithTimeIntervalSinceNow:60*60*24*365*20];
}
static unsigned long long type(id obj){
  return 2;
}
static id Label(id obj){
  return [(ULStorePageStaticText*)[objc_getClass("ULStorePageStaticText") alloc] initWithText:@"Cracked By Naville.\nGGEZ.\nFuck You Subscription Model" style:0x2 tint:0x0 key:@"DurationRemaining"];
}
__attribute__((constructor))
static void fool() {
  Method m1 = class_getInstanceMethod(NSClassFromString(@"ULProductActivation"),NSSelectorFromString(@"isValid"));
  Method m2 = class_getInstanceMethod(NSClassFromString(@"ULProductActivation"),NSSelectorFromString(@"expirationDate"));
  Method m3 = class_getInstanceMethod(NSClassFromString(@"ULProductActivation"),NSSelectorFromString(@"type"));
  Method m4 = class_getInstanceMethod(NSClassFromString(@"ULStorePreferencesPageDescriptor"),NSSelectorFromString(@"informativeLabelForKey:expirationDate:"));
  method_setImplementation(m1, (IMP)yes);
  method_setImplementation(m2, (IMP)expDate);
  method_setImplementation(m3, (IMP)type);
  method_setImplementation(m4, (IMP)Label);

}
