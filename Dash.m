
//clang -shared -undefined dynamic_lookup -o /Applications/Dash.app/Contents/MacOS/libDash.dylib Dash.m
//optool install -c load -p @executable_path/libDash.dylib -t /Applications/Dash.app/Contents/MacOS/Dash
//codesign --remove-signature /Applications/Dash.app/Contents/MacOS/Dash
//Fucking Stupid License Model
//10/10 will definitely not purchase again
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
static NSString* foo(id obj){
  return @"com.barebones.textwrangler";
}
__attribute__((constructor))
static void fool() {
  Method m = class_getInstanceMethod(NSClassFromString(@"DHInApp"),NSSelectorFromString(@"displayString"));
  method_setImplementation(m, (IMP)foo);
  if(m!=NULL){
    NSLog(@"Ball\' in");
  }
}
