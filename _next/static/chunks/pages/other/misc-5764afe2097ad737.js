(self.webpackChunk_N_E=self.webpackChunk_N_E||[]).push([[461],{9704:function(e,n,s){(window.__NEXT_P=window.__NEXT_P||[]).push(["/other/misc",function(){return s(7656)}])},7656:function(e,n,s){"use strict";s.r(n),s.d(n,{__toc:function(){return c},default:function(){return h}});var t=s(5893),i=s(2673),o=s(3393),a=s(2702);s(9128);var r=s(2643),l={src:"/react-native-video//_next/static/media/AppTransportSecuritySetting.b5c387e7.png",height:90,width:964,blurDataURL:"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAABCAAAAADGa7CfAAAAEklEQVR42mP4+ubDjy/ffv0FACJAB6vdOiHaAAAAAElFTkSuQmCC",blurWidth:8,blurHeight:1};let c=[{depth:2,value:"iOS App Transport Security",id:"ios-app-transport-security"},{depth:2,value:"Audio Mixing",id:"audio-mixing"},{depth:2,value:"Android Expansion File Usage",id:"android-expansion-file-usage"},{depth:2,value:"Load files with the RN Asset System",id:"load-files-with-the-rn-asset-system"},{depth:2,value:"Play in background on iOS",id:"play-in-background-on-ios"}];function _createMdxContent(e){let n=Object.assign({h1:"h1",h2:"h2",ul:"ul",li:"li",p:"p",img:"img",a:"a",strong:"strong",pre:"pre",code:"code",span:"span"},(0,r.a)(),e.components);return(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(n.h1,{children:"Miscellaneous"}),"\n",(0,t.jsx)(n.h2,{id:"ios-app-transport-security",children:"iOS App Transport Security"}),"\n",(0,t.jsxs)(n.ul,{children:["\n",(0,t.jsx)(n.li,{children:"By default, iOS will only load encrypted (https) urls. If you want to load content from an unencrypted (http) source, you will need to modify your Info.plist file and add the following entry:"}),"\n"]}),"\n",(0,t.jsx)(n.p,{children:(0,t.jsx)(n.img,{alt:"App Transport Security",placeholder:"blur",src:l})}),"\n",(0,t.jsxs)(n.p,{children:["For more detailed info check this ",(0,t.jsx)(n.a,{href:"https://cocoacasts.com/how-to-add-app-transport-security-exception-domains",children:"article"})]}),"\n\n",(0,t.jsx)(n.h2,{id:"audio-mixing",children:"Audio Mixing"}),"\n",(0,t.jsx)(n.p,{children:"At some point in the future, react-native-video will include an Audio Manager for configuring how videos mix with other apps playing sounds on the device."}),"\n",(0,t.jsx)(n.p,{children:"On iOS, if you would like to allow other apps to play music over your video component, make the following change:"}),"\n",(0,t.jsx)(n.p,{children:(0,t.jsx)(n.strong,{children:"AppDelegate.m"})}),"\n",(0,t.jsx)(n.pre,{"data-language":"objective-c","data-theme":"default",children:(0,t.jsxs)(n.code,{"data-language":"objective-c","data-theme":"default",children:[(0,t.jsxs)(n.span,{className:"line",children:[(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:"#import"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-string-expression)"},children:"<AVFoundation/AVFoundation.h>"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"  "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-comment)"},children:"// import"})]}),"\n",(0,t.jsx)(n.span,{className:"line",children:" "}),"\n",(0,t.jsxs)(n.span,{className:"line",children:[(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:"-"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" ("}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:"BOOL"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:")application:(UIApplication "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:"*"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:")application didFinishLaunchingWithOptions:("}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-constant)"},children:"NSDictionary"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:"*"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:")launchOptions"})]}),"\n",(0,t.jsx)(n.span,{className:"line",children:(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"{"})}),"\n",(0,t.jsx)(n.span,{className:"line",children:(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"  ..."})}),"\n",(0,t.jsxs)(n.span,{className:"line",children:[(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"  [[AVAudioSession "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-function)"},children:"sharedInstance"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"] "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-function)"},children:"setCategory"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-punctuation)"},children:":"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-function)"},children:"AVAudioSessionCategoryAmbient error"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-punctuation)"},children:":"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-constant)"},children:"nil"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"];  "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-comment)"},children:"// allow"})]}),"\n",(0,t.jsx)(n.span,{className:"line",children:(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"  ..."})}),"\n",(0,t.jsx)(n.span,{className:"line",children:(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"}"})})]})}),"\n",(0,t.jsxs)(n.p,{children:["You can also use the ",(0,t.jsx)(n.a,{href:"#ignoresilentswitch",children:"ignoreSilentSwitch"})," prop."]}),"\n\n",(0,t.jsx)(n.h2,{id:"android-expansion-file-usage",children:"Android Expansion File Usage"}),"\n",(0,t.jsx)(n.p,{children:"Expansions files allow you to ship assets that exceed the 100MB apk size limit and don't need to be updated each time you push an app update."}),"\n",(0,t.jsx)(n.p,{children:"This only supports mp4 files and they must not be compressed. Example command line for preventing compression:"}),"\n",(0,t.jsx)(n.pre,{"data-language":"bash","data-theme":"default",children:(0,t.jsx)(n.code,{"data-language":"bash","data-theme":"default",children:(0,t.jsxs)(n.span,{className:"line",children:[(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-function)"},children:"zip"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-string)"},children:"-r"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-string)"},children:"-n"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-string)"},children:".mp4"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-string)"},children:"*.mp4"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-string)"},children:"player.video.example.com"})]})})}),"\n",(0,t.jsx)(n.pre,{"data-language":"javascript","data-theme":"default",children:(0,t.jsxs)(n.code,{"data-language":"javascript","data-theme":"default",children:[(0,t.jsx)(n.span,{className:"line",children:(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-comment)"},children:"// Within your render function, assuming you have a file called"})}),"\n",(0,t.jsx)(n.span,{className:"line",children:(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-comment)"},children:'// "background.mp4" in your expansion file. Just add your main and (if applicable) patch version'})}),"\n",(0,t.jsxs)(n.span,{className:"line",children:[(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"<"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-constant)"},children:"Video"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-function)"},children:"source"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:"="}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"{{uri"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:":"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-string-expression)"},children:'"background"'}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-punctuation)"},children:","}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" mainVer"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:":"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-constant)"},children:"1"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-punctuation)"},children:","}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" patchVer"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:":"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:" "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-constant)"},children:"0"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"}} "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-comment)"},children:"// Looks for .mp4 file (background.mp4) in the given expansion version."})]}),"\n",(0,t.jsxs)(n.span,{className:"line",children:[(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"       "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-function)"},children:"resizeMode"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:"="}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-string-expression)"},children:'"cover"'}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"           "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-comment)"},children:"// Fill the whole screen at aspect ratio."})]}),"\n",(0,t.jsxs)(n.span,{className:"line",children:[(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"       "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-function)"},children:"style"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:"="}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"{"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-constant)"},children:"styles"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:".backgroundVideo} />"})]})]})}),"\n",(0,t.jsx)(n.h2,{id:"load-files-with-the-rn-asset-system",children:"Load files with the RN Asset System"}),"\n",(0,t.jsxs)(n.p,{children:["The asset system ",(0,t.jsxs)(n.a,{href:"http://www.reactnative.com/react-native-v0-14-0-released/",children:["introduced in RN ",(0,t.jsx)(n.code,{children:"0.14"})]})," allows loading image resources shared across iOS and Android without touching native code. As of RN ",(0,t.jsx)(n.code,{children:"0.31"})," ",(0,t.jsx)(n.a,{href:"https://github.com/facebook/react-native/commit/91ff6868a554c4930fd5fda6ba8044dbd56c8374",children:"the same is true"})," of mp4 video assets for Android. As of ",(0,t.jsxs)(n.a,{href:"https://github.com/facebook/react-native/releases/tag/v0.33.0",children:["RN ",(0,t.jsx)(n.code,{children:"0.33"})]})," iOS is also supported. Requires ",(0,t.jsx)(n.code,{children:"react-native-video@0.9.0"}),"."]}),"\n",(0,t.jsx)(n.pre,{"data-language":"javascript","data-theme":"default",children:(0,t.jsxs)(n.code,{"data-language":"javascript","data-theme":"default",children:[(0,t.jsxs)(n.span,{className:"line",children:[(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"<"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-constant)"},children:"Video"})]}),"\n",(0,t.jsxs)(n.span,{className:"line",children:[(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"  "}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-function)"},children:"source"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-keyword)"},children:"="}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"{"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-function)"},children:"require"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"("}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-token-string-expression)"},children:"'../assets/video/turntable.mp4'"}),(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:")}"})]}),"\n",(0,t.jsx)(n.span,{className:"line",children:(0,t.jsx)(n.span,{style:{color:"var(--shiki-color-text)"},children:"/>"})})]})}),"\n",(0,t.jsx)(n.h2,{id:"play-in-background-on-ios",children:"Play in background on iOS"}),"\n",(0,t.jsxs)(n.p,{children:["To enable audio to play in background on iOS the audio session needs to be set to ",(0,t.jsx)(n.code,{children:"AVAudioSessionCategoryPlayback"}),". See [Apple documentation][3] for additional details. (NOTE: there is now a ticket to ",(0,t.jsx)(n.a,{href:"https://github.com/react-native-community/react-native-video/issues/310",children:"expose this as a prop"})," )"]})]})}let d={MDXContent:function(){let e=arguments.length>0&&void 0!==arguments[0]?arguments[0]:{},{wrapper:n}=Object.assign({},(0,r.a)(),e.components);return n?(0,t.jsx)(n,{...e,children:(0,t.jsx)(_createMdxContent,{...e})}):_createMdxContent(e)},pageOpts:{filePath:"pages/other/misc.md",route:"/other/misc",timestamp:1718260732e3,pageMap:[{kind:"Meta",data:{index:"Introduction",installation:"Installation",component:"API",other:"Other",separator_versions:{type:"separator",title:""},updating:"Updating",changelog:{title:"Changelog",newWindow:!0,href:"https://github.com/TheWidlarzGroup/react-native-video/blob/master/CHANGELOG.md"},separator_community:{type:"separator",title:""},projects:"Useful projects"}},{kind:"Folder",name:"component",route:"/component",children:[{kind:"Meta",data:{props:"Properties",drm:"DRM",ads:"Ads",events:"Events",methods:"Methods"}},{kind:"MdxPage",name:"ads",route:"/component/ads"},{kind:"MdxPage",name:"drm",route:"/component/drm"},{kind:"MdxPage",name:"events",route:"/component/events"},{kind:"MdxPage",name:"methods",route:"/component/methods"},{kind:"MdxPage",name:"props",route:"/component/props"}]},{kind:"MdxPage",name:"index",route:"/"},{kind:"MdxPage",name:"installation",route:"/installation"},{kind:"Folder",name:"other",route:"/other",children:[{kind:"Meta",data:{caching:"Caching",misc:"Misc",debug:"Debugging","new-arch":"New Architecture"}},{kind:"MdxPage",name:"caching",route:"/other/caching"},{kind:"MdxPage",name:"debug",route:"/other/debug"},{kind:"MdxPage",name:"misc",route:"/other/misc"},{kind:"MdxPage",name:"new-arch",route:"/other/new-arch"}]},{kind:"MdxPage",name:"projects",route:"/projects"},{kind:"MdxPage",name:"updating",route:"/updating"}],flexsearch:{codeblocks:!0},title:"Miscellaneous",headings:c},pageNextRoute:"/other/misc",nextraLayout:o.ZP,themeConfig:a.Z};var h=(0,i.j)(d)},2702:function(e,n,s){"use strict";var t=s(5893);s(7294),n.Z={head:(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)("meta",{name:"language",content:"en"}),(0,t.jsx)("meta",{name:"viewport",content:"width=device-width,initial-scale=1"}),(0,t.jsx)("meta",{name:"description",content:"Video component for React Native"}),(0,t.jsx)("meta",{name:"og:title",content:"React Native Video"}),(0,t.jsx)("meta",{name:"og:description",content:"A Video component for React Native"}),(0,t.jsx)("meta",{name:"og:image",content:"https://react-native-video.github.io/react-native-video/thumbnail.jpg"}),(0,t.jsx)("meta",{name:"twitter:card",content:"summary_large_image"}),(0,t.jsx)("meta",{name:"twitter:title",content:"React Native Video"}),(0,t.jsx)("meta",{name:"twitter:description",content:"A Video component for React Native"}),(0,t.jsx)("meta",{name:"twitter:image",content:"https://react-native-video.github.io/react-native-video/thumbnail.jpg"}),(0,t.jsx)("meta",{name:"twitter:image:alt",content:"React Native Video"}),(0,t.jsx)("link",{rel:"preconnect",href:"https://fonts.googleapis.com"}),(0,t.jsx)("link",{rel:"preconnect",href:"https://fonts.gstatic.com",crossOrigin:!0}),(0,t.jsx)("link",{href:"https://fonts.googleapis.com/css2?family=Orbitron:wght@400..900&display=swap",rel:"stylesheet"})]}),logo:(0,t.jsxs)("span",{children:["\uD83C\uDFAC ",(0,t.jsx)("strong",{children:"Video component"})," for React Native"]}),faviconGlyph:"\uD83C\uDFAC",project:{link:"https://github.com/TheWidlarzGroup/react-native-video"},docsRepositoryBase:"https://github.com/TheWidlarzGroup/react-native-video/tree/master/docs/",footer:{text:(0,t.jsxs)("span",{children:["Built with love ❤️ by ",(0,t.jsx)("strong",{children:"React Native Community"})]})},useNextSeoProps:()=>({titleTemplate:"%s – Video"})}},5789:function(){}},function(e){e.O(0,[774,890,888,179],function(){return e(e.s=9704)}),_N_E=e.O()}]);