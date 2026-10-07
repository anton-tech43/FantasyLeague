import React from 'react';
import {AbsoluteFill,Composition,registerRoot} from 'remotion';
import {loadFont} from '@remotion/google-fonts/PlusJakartaSans';
const {fontFamily}=loadFont('normal',{weights:['500','600','700','800'],subsets:['latin']});
const Cover=()=> <AbsoluteFill style={{background:'#2D1B2E',fontFamily,color:'#F5F0F0'}}>
<AbsoluteFill style={{opacity:.2,backgroundImage:'linear-gradient(#3D2B3E 1px, transparent 1px),linear-gradient(90deg,#3D2B3E 1px, transparent 1px)',backgroundSize:'60px 60px'}}/>
<AbsoluteFill style={{background:'radial-gradient(ellipse at 50% 45%, transparent 40%, #1B1020 100%)'}}/>
<div style={{position:'absolute',left:64,top:48,fontSize:42,fontWeight:800,letterSpacing:-1.5}}>Goal<span style={{color:'#E8397D'}}>Digger</span></div>
<div style={{position:'absolute',left:64,top:166,width:690,fontSize:72,fontWeight:800,lineHeight:1.06,letterSpacing:-3}}>Football, finally<br/>in <span style={{color:'#E8397D'}}>plain English.</span></div>
<div style={{position:'absolute',left:68,top:358,width:620,fontSize:27,lineHeight:1.45,fontWeight:500}}>The app for people who live with<br/>someone who lives for football.</div>
<div style={{position:'absolute',left:68,top:507,fontSize:21,lineHeight:1.75,fontWeight:600}}>Easy match insights. Ready-made talking points.<br/>Enough context to join the conversation.</div>
<div style={{position:'absolute',left:68,top:639,fontSize:17,fontWeight:700,letterSpacing:2,color:'#9B8FA0'}}>AVAILABLE ON iPHONE</div>
<div style={{position:'absolute',left:779,top:132,width:413,height:440,background:'#FAF0F4',borderRadius:26,padding:'34px 32px',boxSizing:'border-box',color:'#2C2C2C',boxShadow:'0 20px 60px rgba(0,0,0,.28)',transform:'rotate(3deg)'}}>
<div style={{fontSize:16,letterSpacing:2,fontWeight:800}}>WORTH KNOWING</div>
<div style={{fontSize:32,lineHeight:1.2,fontWeight:800,letterSpacing:-.7,marginTop:23}}>Their best striker<br/>might miss the match.</div>
<div style={{fontSize:21,lineHeight:1.4,marginTop:16}}>Less firepower up front.<br/>More pacing round the sofa.</div>
<div style={{height:1,background:'#2C2C2C',opacity:.15,marginTop:25}}/>
<div style={{fontSize:16,letterSpacing:2,fontWeight:800,marginTop:22}}>ASK HIM</div>
<div style={{fontSize:23,lineHeight:1.3,fontWeight:700,marginTop:12}}>“Who's starting if their<br/>striker's still injured?”</div>
</div>
<div style={{position:'absolute',left:790,top:600,fontSize:15,color:'#9B8FA0'}}>A little context. A much better question.</div>
</AbsoluteFill>;
registerRoot(()=> <Composition id="Cover" component={Cover} width={1280} height={720} fps={1} durationInFrames={1}/>);
