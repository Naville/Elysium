
//$THEOS/bin/logos.pl /PATH/OF/THIS/FILE > /PATH/OF/NEW/FILE
//clang -shared -undefined dynamic_lookup -o libThunder.dylib /PATH/OF/NEW/FILE
//Inject and profit
%config(generator=internal)
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>

%group Builtin
%hook NSFileManager
-(BOOL)fileExistsAtPath:(NSString*)K{
    if([[K stringByReplacingOccurrencesOfString:@"/Applications/Thunder.app/Contents/PlugIns/" withString:@""] length]==32){
    NSLog(@"You are so 1970");
    return YES;
  }
  else{
    return %orig;
  }

}
%end
%hook XLHostTaskController
- (BOOL)taskCanTryHighSpeed:(long long)arg1{
  return YES;
}
%end
%hook LocalTask
-(BOOL)isValidLixianTask{
  return YES;
}
%end

%hook UserController
-(BOOL)isLogined{
  return YES;
}
-(BOOL)isPlatinum{
  return YES;
}
-(BOOL)isDiamond{
  return YES;
}
%end
%end


%group Plugin
%hook VipServiceHelper
- (BOOL)canUseVipAcclerate{
  return YES;
}
- (BOOL)isVip{
  return YES;
}
%end
%end

static void CB(const struct mach_header * mh,intptr_t ptr){
  if(objc_getClass("DkHelper")!=NULL){
    %init(Plugin);
  }
}
%ctor{
  %init(Builtin);
  _dyld_register_func_for_add_image(&CB);
}
