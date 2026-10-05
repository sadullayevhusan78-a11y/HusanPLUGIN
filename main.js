const {entrypoints}=require("uxp");
const app=require("aftereffects");

const $=id=>document.getElementById(id);
const status=$("status"),bar=$("bar"),progressText=$("progressText"),progressWrap=$("progressWrap");

function setStatus(m){status.textContent=m}
function progress(v,m){
  progressWrap.style.display="block";
  bar.style.width=Math.max(0,Math.min(100,v))+"%";
  progressText.textContent=m;
}
function safe(fn){
  return ()=>{
    try{fn()}
    catch(e){setStatus(e.message||String(e))}
  };
}
function activeComp(){
  const x=app.project&&app.project.activeItem;
  if(!x||x.typeName!=="Composition") throw new Error("Open a composition first.");
  return x;
}
function selectedLayers(c){
  if(!c.selectedLayers||!c.selectedLayers.length) throw new Error("Select a layer first.");
  return c.selectedLayers;
}
function selectedVideoPath(c){
  for(const l of selectedLayers(c)){
    const s=l.source;
    if(s&&s.typeName==="Footage"&&s.file){
      return s.file.nativePath||s.file.fsName||String(s.file);
    }
  }
  throw new Error("Select a video footage layer.");
}
function centerLayer(l,c){
  const p=l.property("Transform").property("Position");
  if(p)p.setValue([c.width/2,c.height/2]);
}
function createReels(){
  const c=app.project.items.addComp("REELS_1080x1920",1080,1920,1,30,30);
  c.openInViewer();
  setStatus("Created 1080 × 1920 Reels comp.");
}
function centerSelected(){
  const c=activeComp();
  app.beginUndoGroup("Husan Center");
  try{selectedLayers(c).forEach(l=>centerLayer(l,c));setStatus("Centered selected layers.")}
  finally{app.endUndoGroup()}
}
function fitSelected(){
  const c=activeComp();
  app.beginUndoGroup("Husan Fit");
  try{
    selectedLayers(c).forEach(l=>{
      if(!l.width||!l.height)return;
      const s=Math.min(c.width*.92/l.width*100,c.height*.92/l.height*100);
      l.property("Transform").property("Scale").setValue([s,s]);
      centerLayer(l,c);
    });
    setStatus("Selected layers fitted.");
  }finally{app.endUndoGroup()}
}
function addText(){
  const c=activeComp();
  app.beginUndoGroup("Husan Text");
  try{
    const l=c.layers.addText("YOUR TEXT");
    l.name="HUSAN_SUBTITLE";
    centerLayer(l,c);
    setStatus("Subtitle layer added.");
  }finally{app.endUndoGroup()}
}
function punchMotion(){
  const c=activeComp(),ls=selectedLayers(c);
  app.beginUndoGroup("Husan Punch");
  try{
    ls.forEach(l=>{
      const p=l.property("Transform").property("Scale");
      const t=Math.max(0,c.time);
      const base=p.value[0]||100;
      p.setValueAtTime(t,base);
      p.setValueAtTime(t+0.18,base+6);
      p.setValueAtTime(t+0.42,base);
    });
    setStatus("Punch-in motion added.");
  }finally{app.endUndoGroup()}
}
function microShake(){
  const c=activeComp(),ls=selectedLayers(c);
  app.beginUndoGroup("Husan Micro Shake");
  try{
    ls.forEach(l=>{
      const p=l.property("Transform").property("Position");
      const t=Math.max(0,c.time),v=p.value;
      p.setValueAtTime(t,[v[0],v[1]]);
      p.setValueAtTime(t+0.08,[v[0]+3,v[1]-2]);
      p.setValueAtTime(t+0.16,[v[0]-3,v[1]+2]);
      p.setValueAtTime(t+0.24,[v[0],v[1]]);
    });
    setStatus("Micro shake added.");
  }finally{app.endUndoGroup()}
}
function smoothFade(){
  const c=activeComp(),ls=selectedLayers(c);
  app.beginUndoGroup("Husan Fade");
  try{
    ls.forEach(l=>{
      const o=l.property("Transform").property("Opacity");
      const t=Math.max(0,c.time);
      o.setValueAtTime(t,0);
      o.setValueAtTime(t+0.28,100);
    });
    setStatus("Smooth fade added.");
  }finally{app.endUndoGroup()}
}
async function health(){
  try{
    const r=await fetch("http://localhost:8765/health");
    if(!r.ok)throw new Error();
    setStatus("Local engine: online ✓");
  }catch(e){setStatus("Local engine: offline — run the installer/server.")}
}
async function autoEdit(){
  let c,input;
  try{
    c=activeComp();
    input=selectedVideoPath(c);
  }catch(e){setStatus(e.message||String(e));return}

  progress(2,"Analyzing video…");
  try{
    const r=await fetch("http://localhost:8765/auto-edit",{
      method:"POST",
      headers:{"Content-Type":"application/json"},
      body:JSON.stringify({
        input_path:input,
        captions:$("captions").value==="on",
        mode:$("cut").value,
        format:$("format").value
      })
    });
    if(!r.ok)throw new Error(await r.text());

    const reader=r.body&&r.body.getReader?r.body.getReader():null;
    if(!reader){
      const x=await r.json();
      if(x.output_path)importResult(c,x.output_path);
      return;
    }

    const d=new TextDecoder();
    let b="";
    while(true){
      const q=await reader.read();
      if(q.done)break;
      b+=d.decode(q.value,{stream:true});
      const ls=b.split("\n");
      b=ls.pop();
      for(const line of ls){
        if(!line.trim())continue;
        const e=JSON.parse(line);
        if(e.progress!=null)progress(e.progress,e.message||"Editing…");
        if(e.output_path)importResult(c,e.output_path);
        if(e.error)throw new Error(e.error);
      }
    }
  }catch(e){
    progressWrap.style.display="none";
    setStatus(e.message||String(e));
  }
}
function importResult(c,path){
  const item=app.project.importFile({file:path});
  const l=c.layers.add(item);
  l.name="HUSAN_AUTO_REELS";
  l.property("Transform").property("Position").setValue([c.width/2,c.height/2]);
  const s=Math.max(c.width/item.width*100,c.height/item.height*100);
  l.property("Transform").property("Scale").setValue([s,s]);
  setStatus("✓ Auto montage imported.");
  progress(100,"Finished — ready to preview.");
}

$("autoEdit").addEventListener("click",autoEdit);
$("punch").addEventListener("click",safe(punchMotion));
$("shake").addEventListener("click",safe(microShake));
$("fade").addEventListener("click",safe(smoothFade));
$("createReels").addEventListener("click",safe(createReels));
$("centerSelected").addEventListener("click",safe(centerSelected));
$("fitSelected").addEventListener("click",safe(fitSelected));
$("addText").addEventListener("click",safe(addText));

health();
entrypoints.setup({
  panels:{
    reelsMasterPanel:{
      create(){health()},
      show(){health()}
    }
  }
});
