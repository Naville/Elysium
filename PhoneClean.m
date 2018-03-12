//clang -shared -undefined dynamic_lookup -o /Applications/PhoneClean.app/Contents/MacOS/libPC.dylib -arch i386 PhoneClean.m
//optool install -c load -p @executable_path/libPC.dylib -t /Applications/PhoneClean.app/Contents/MacOS/PhoneClean
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
static long long foo1(id obj){
  return LLONG_MAX;
}
static BOOL foo2(id obj){
  [[NSNotificationCenter defaultCenter] postNotificationName:@"register_succeed" object:0x0 userInfo:0x0];
  return YES;
}
static void foo3(id obj){
}
__attribute__((constructor))
static void fool() {
  Method m1 = class_getInstanceMethod(NSClassFromString(@"IMBSoftWareInfo"),NSSelectorFromString(@"verifyActivateSoftware:"));
  Method m2 = class_getInstanceMethod(NSClassFromString(@"IMBSoftWareInfo"),NSSelectorFromString(@"isRegistered"));
  Method m3 = class_getInstanceMethod(NSClassFromString(@"IMBSoftWareInfo"),NSSelectorFromString(@"RegisteredStatus"));
  method_setImplementation(m1, (IMP)foo2);
  method_setImplementation(m2, (IMP)foo2);
  method_setImplementation(m3, (IMP)foo2);
}
