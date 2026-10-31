'use strict';
const token=location.hash.slice(1), app=document.querySelector('#app'), status=document.querySelector('#status');
let artSavedLayout=null;
let catalog, page='', dirty=false, pending=0, map=null, art=null, balance={}, selectedUnit='', saveState=null;
const $=id=>document.getElementById(id), clone=x=>JSON.parse(JSON.stringify(x)), esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function message(s){status.textContent=s;status.title=s;}
async function api(action,body={}){
 pending++;app.inert=true;$('busy').textContent='正在'+({catalog:'读取工程',map:'加载地图',art:'读取图层',save_map:'保存模板',validate:'校验路线'}[action]||'处理')+'…';
 try{const response=await fetch('/api',{method:'POST',headers:{'Content-Type':'application/json','X-Tool-Token':token},body:JSON.stringify({action,...body})});const result=await response.json();if(result.error)throw Error(result.error);return result;}
 finally{pending--;app.inert=pending>0;if(!pending)$('busy').textContent='本机 · V0.5 开发工程';}
}
function run(fn){return (...a)=>Promise.resolve().then(()=>fn(...a)).catch(e=>message('未完成：'+e.message));}
$('shutdown').onclick=run(async()=>{if(dirty&&!confirm('当前有未保存修改，仍然关闭服务？'))return;await api('shutdown');dirty=false;app.innerHTML='<section class="card"><h2>开发服务已关闭</h2><p>重新运行 RoomEditor 启动文件即可再次打开。</p></section>';document.querySelectorAll('header button').forEach(b=>b.disabled=true);message('本机开发服务已退出');});
function button(id,fn){$(id).onclick=run(fn);}
function options(rows,selected=''){return rows.map(([value,label])=>`<option value="${esc(value)}" ${value===selected?'selected':''}>${esc(label)}</option>`).join('');}
function changed(){dirty=true;message('有未保存修改 · Ctrl+S 保存');}
function confirmBox(text,action){const d=document.createElement('dialog');d.innerHTML=`<h2>确认操作</h2><p style="white-space:pre-wrap">${esc(text)}</p><button id="cancel">取消</button><button id="confirm">确认</button>`;document.body.append(d);d.querySelector('#cancel').onclick=()=>d.close();d.querySelector('#confirm').onclick=run(async()=>{await action();d.close();});d.addEventListener('close',()=>d.remove());d.showModal();d.querySelector('#cancel').focus();}
class View {
 constructor(canvas,draw){this.el=canvas;this.ctx=canvas.getContext('2d');this.scale=1;this.offset=[0,0];this.paint=draw;this.images=new Map();this.pan=null;
  this.resize=new ResizeObserver(()=>this.draw());this.resize.observe(canvas.parentNode);
  canvas.onwheel=e=>{e.preventDefault();const p=this.pixel(e),q=this.world(e),next=Math.max(.08,Math.min(14,this.scale*(e.deltaY<0?1.12:1/1.12)));this.scale=next;this.offset=[p[0]-q[0]*next,p[1]-q[1]*next];this.draw();};
  canvas.addEventListener('pointerdown',e=>{if(e.button===1||e.button===2){e.preventDefault();this.pan={p:this.pixel(e),o:[...this.offset]};canvas.setPointerCapture(e.pointerId);}});
  canvas.addEventListener('pointermove',e=>{if(this.pan){let p=this.pixel(e);this.offset=[this.pan.o[0]+p[0]-this.pan.p[0],this.pan.o[1]+p[1]-this.pan.p[1]];this.draw();}});
  canvas.addEventListener('pointerup',()=>this.pan=null);canvas.oncontextmenu=e=>e.preventDefault();
 }
 pixel(e){const r=this.el.getBoundingClientRect();return[e.clientX-r.left,e.clientY-r.top];}
 world(e){return this.pixel(e).map((v,i)=>(v-this.offset[i])/this.scale);}
 fit(rect){const r=this.el.parentNode.getBoundingClientRect();this.scale=Math.min((r.width-45)/rect[2],(r.height-45)/rect[3]);this.offset=[r.width/2-(rect[0]+rect[2]/2)*this.scale,r.height/2-(rect[1]+rect[3]/2)*this.scale];this.draw();}
 image(path,rect,original=false,crop=[]){if(!path)return;const key=path+(original?'#original':'');let image=this.images.get(key);if(!image){image=new Image();image.onload=()=>this.draw();image.src='/asset?path='+encodeURIComponent(path)+'&token='+encodeURIComponent(token)+(original?'&original=1':'');this.images.set(key,image);if(this.images.size>96)this.images.delete(this.images.keys().next().value);}if(image.complete&&image.naturalWidth){if(crop.length===4)this.ctx.drawImage(image,...crop,...rect);else this.ctx.drawImage(image,...rect);}}
 draw(){if(this.scheduled)return;this.scheduled=requestAnimationFrame(()=>{this.scheduled=null;this.render();});}
 render(){if(!this.el.isConnected)return;const r=this.el.parentNode.getBoundingClientRect(),d=devicePixelRatio||1;this.el.width=Math.max(1,Math.round(r.width*d));this.el.height=Math.max(1,Math.round(r.height*d));const c=this.ctx;c.scale(d,d);c.translate(...this.offset);c.scale(this.scale,this.scale);c.imageSmoothingEnabled=true;this.paint(c,this);}
 destroy(){cancelAnimationFrame(this.scheduled);this.resize.disconnect();this.images.clear();}
}
let view;
function polygon(c,points,color,scale,fill=false){if(!points.length)return;c.beginPath();points.forEach((p,i)=>i?c.lineTo(...p):c.moveTo(...p));c.closePath();c.strokeStyle=color;c.lineWidth=2/scale;if(fill){c.fillStyle=color+'20';c.fill();}c.stroke();}
function rectPoints(r){return[[r[0],r[1]],[r[0]+r[2],r[1]],[r[0]+r[2],r[1]+r[3]],[r[0],r[1]+r[3]]];}
function distance(a,b){return Math.hypot(a[0]-b[0],a[1]-b[1]);}
async function show(next){if(pending)return;if(dirty){if(!confirm('当前修改尚未保存，放弃修改并切换页面？'))return;if(page==='map')map=null;if(page==='art'&&artSavedLayout)art.layout=clone(artSavedLayout);}dirty=false;view?.destroy();view=null;drag=null;paintDrag=null;page=next;document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('active',b.dataset.page===next));
 if(next==='story')await storyPage();if(next==='map')await mapPage();if(next==='art')await artPage();if(next==='units')unitsPage();if(next==='console')consolePage();
}
document.querySelectorAll('nav button').forEach(b=>b.onclick=run(()=>show(b.dataset.page)));
let mapUndo=[],mapRedo=[],selectedShape='',mapMode='collision',drag=null,visibility={};
function checkpoint(){mapUndo.push(clone(map));if(mapUndo.length>80)mapUndo.shift();mapRedo=[];}
function shapeWorld(shape){return shape.key==='room_bounds'?rectPoints(map.bounds):shape.polygon.map(p=>[p[0]+shape.origin[0],p[1]+shape.origin[1]]);}
function assignShape(shape,points){const doc=map.document;if(shape.key==='room_bounds'){
 let xs=points.map(p=>p[0]),ys=points.map(p=>p[1]);map.bounds=[Math.min(...xs),Math.min(...ys),Math.max(...xs)-Math.min(...xs),Math.max(...ys)-Math.min(...ys)];doc.room_bounds_override=[...map.bounds];return;}
 shape.polygon=points.map(p=>[p[0]-shape.origin[0],p[1]-shape.origin[1]]);let overrides=doc.scene_collision_overrides??={};let [type,id]=shape.key.split(':');
 if(type==='object')(overrides.objects??={})[id]=clone(shape.polygon);
 if(type==='placed')(overrides.placed??={})[id]=clone(shape.polygon);
 if(type==='service_building')overrides.service_building=clone(shape.polygon);
 if(type==='water'){if(!overrides.water)overrides.water=clone(map.scene.surface_water_polygons_px||[]);overrides.water[+id]=clone(shape.polygon);}
}
function drawMap(c,v){if(!map)return;const doc=map.document,scene=map.scene,W=doc.grid.size[0]*36,H=doc.grid.size[1]*36,f=scene.floor_rect_px||[0,0,W,H],sx=W/f[2],sy=H/f[3],root='res://assets/room_illustrated/'+doc.scene_art+'/';
 for(const plane of scene.planes||[]){let layer=plane.layer||'background';if(visibility[layer]===false)continue;let r=plane.rect_px||[0,0,...scene.canvas];v.image(plane.path.startsWith('res://')?plane.path:root+plane.path,[(r[0]-f[0])*sx,(r[1]-f[1])*sy,r[2]*sx,r[3]*sy]);}
 for(const object of scene.objects||[]){if(visibility[object.layer||'objects']===false)continue;const path=object.texture.startsWith('res://')?object.texture:root+object.texture;let image=v.images.get(path),width=object.render_width_px||36,height=image?.naturalWidth?width*image.naturalHeight/image.naturalWidth:width;const p=object.position_px||[0,0];v.image(path,[p[0]-width/2,p[1]-height,width,height]);}
 if(scene.service_building&&visibility.buildings!==false){const b=scene.service_building,p=b.position_px||[0,0],path=root+b.texture,img=v.images.get(path),w=b.width_px||180,h=img?.naturalWidth?w*img.naturalHeight/img.naturalWidth:w;v.image(path,[p[0]-w/2,p[1]-h,w,h]);}
 const painted=new Set();
 for(const row of [...(map.placed||[])].sort((a,b)=>a.rect[1]+a.rect[3]-b.rect[1]-b.rect[3])){
  const entry=(doc.layers[row.layer]||[]).find(x=>x.id===row.id);if(!entry)continue;painted.add(entry.id);
  const layer=entry.asset_id.startsWith('light:')?'lights':entry.asset_id.startsWith('service:')?'buildings':'objects';if(visibility[layer]===false)continue;
  const r=[...row.rect];r[0]+=(entry.at[0]-row.at[0])*36;r[1]+=(entry.at[1]-row.at[1])*36;v.image(row.path,r,false,row.crop||[]);
 }
 for(const entry of doc.layers.entities||[]){if(painted.has(entry.id)||!entry.asset_id.startsWith('light:')||visibility.lights===false)continue;
  const [,kind,size]=entry.asset_id.split(':'),dims=size.split('x').map(Number),path='res://assets/room_mode/lights/'+kind+'_'+size+'.png',img=v.images.get(path),w=dims[0]*36,h=img?.naturalWidth?w*img.naturalHeight/img.naturalWidth:w;
  v.image(path,[entry.at[0]*36,entry.at[1]*36+dims[1]*36-h,w,h]);
 }
 if(visibility.doors!==false)for(const [side,gate] of Object.entries(scene.gates||{})){let r=gate.rect_px,origin=scene.gate_origin||[11,5],port=doc.ports.find(p=>p.side===side);let dx=port?(port.at[0]-origin[0])*36:0,dy=port?(port.at[1]-origin[1])*36:0;if(side==='north'||side==='south')dy=0;else dx=0;v.image(root+gate.path,[(r[0]-f[0])*sx+dx,(r[1]-f[1])*sy+dy,r[2]*sx,r[3]*sy]);}
 if(visibility.grid){c.strokeStyle='#ffffff19';c.lineWidth=1/v.scale;for(let x=0;x<=W;x+=36){c.beginPath();c.moveTo(x,0);c.lineTo(x,H);c.stroke();}for(let y=0;y<=H;y+=36){c.beginPath();c.moveTo(0,y);c.lineTo(W,y);c.stroke();}}
 if(visibility.collision!==false)for(const shape of map.shapes){let points=shapeWorld(shape),selected=shape.key===selectedShape;polygon(c,points,selected?'#f6edb3':shape.key==='room_bounds'?'#fd7753':shape.key.startsWith('water')?'#74bbfa':'#ddbb63',v.scale,selected);if(selected)for(const p of points){c.fillStyle='#e6db8c';c.fillRect(p[0]-4/v.scale,p[1]-4/v.scale,8/v.scale,8/v.scale);}}
 if(visibility.spawns!==false){for(const marker of doc.layers.markers||[])drawMarker(c,v,marker,'#ffda82');for(const entry of doc.layers.entities||[])drawMarker(c,v,entry,'#b2c8ff');}
 if(visibility.doors!==false)for(const port of doc.ports){const p=port.at.map(n=>n*36);c.strokeStyle='#67efcf';c.lineWidth=2/v.scale;c.strokeRect(...p,36,36);}
}
function drawMarker(c,v,marker,color){const p=marker.at.map(n=>n*36+18);c.fillStyle=color;c.beginPath();c.arc(...p,6/v.scale,0,Math.PI*2);c.fill();c.font=`${12/v.scale}px sans-serif`;c.fillText(marker.asset_id.startsWith('camp:')?({'camp:shop':'商铺','camp:contracts':'工会','camp:player':'出生点','camp:prepare':'准备台','camp:training':'训练场','camp:warehouse':'仓库','camp:iris':'女神灯坛','camp:relations':'酒馆','camp:result':'记事台','camp:dummy':'稻草人'}[marker.asset_id]||marker.asset_id):marker.id,p[0]+9/v.scale,p[1]);}
async function mapPage(){app.innerHTML=`<aside class="sidebar"><h2>房间模板</h2><select id="chapter">${options([['','全部章节'],['awakening_woods','苏醒林地'],['chapter_2','失名星城'],['shared','通用 / 营地']])}</select><select id="template"></select><button id="load">载入 / 重新载入</button><button id="import">导入 JSON…</button><input type="file" id="file" accept=".json" hidden><h3>编辑工具</h3><select id="mode">${options([['collision','碰撞顶点 / 整体移动'],['rectangle','绘制矩形碰撞'],['markers','出生点 / 营地交互点'],['ports','四向门'],['light','放置 / 移动光源']])}</select><select id="targets"></select><button id="clearShape">清空选中碰撞</button><button id="restoreShape">恢复原始碰撞</button><button id="addWater">新增水面碰撞</button><div id="lightTools"><select id="lightKind">${options(Object.entries(catalog.lights))}</select><select id="lightSize">${options([['1x1','1×1'],['2x2','2×2'],['1x2','1×2'],['2x1','2×1']])}</select></div><h3>图层显示</h3><div id="layers"></div><p class="hint">滚轮缩放，中键 / 右键平移。拖动顶点精修；拖动轮廓内部平移。Shift 点击插入顶点，Alt 点击删除顶点。门和交互点按36像素格拖动。标记模式可点击新增刷怪点，右键删除；营地固定点仅拖动。光源模式右键删除光源。</p></aside><section class="workspace"><div class="toolbar"><button id="save">存入模板池</button><button id="export">导出 JSON</button><button id="validate">验证（仅参考）</button><button id="playtest">游戏验证</button><label><input type="checkbox" id="enemies">生成模板敌人</label><button id="undo">撤销</button><button id="redo">重做</button><button id="fit">适应窗口</button></div><div class="viewport"><canvas id="canvas"></canvas></div><div id="validation"></div></section>`;
 const filter=()=>{$('template').innerHTML=options(catalog.templates.filter(t=>!$('chapter').value||(t.chapter||'shared')===$('chapter').value).map(t=>[t.id,t.name]),map?.document.id||'');};filter();$('chapter').onchange=filter;
 view=new View($('canvas'),drawMap);
 button('load',async()=>{if(dirty&&!confirm('放弃当前未保存修改？'))return;await loadMap({id:$('template').value});});
 $('mode').value=mapMode;$('mode').onchange=()=>{mapMode=$('mode').value;};
 button('save',saveMap);button('validate',async()=>{const r=await api('validate',{document:map.document});$('validation').textContent=r.errors.length?'验证提示（仍可保存）：\n'+r.errors.join('\n'):'验证通过';});
 button('playtest',async()=>message((await api('playtest',{document:map.document,enemies:$('enemies').checked})).message));
 button('export',()=>download(map.document,map.document.id+'.json'));button('import',()=>$('file').click());$('file').onchange=run(async()=>{const value=JSON.parse(await $('file').files[0].text());await loadMap({document:value});dirty=true;});
 button('fit',fitMap);button('undo',()=>mapHistory(false));button('redo',()=>mapHistory(true));
 button('clearShape',()=>{const shape=map.shapes.find(s=>s.key===selectedShape);if(shape&&shape.key!=='room_bounds'){checkpoint();assignShape(shape,[]);changed();view.draw();}});
 button('restoreShape',async()=>{checkpoint();let d=map.document,o=d.scene_collision_overrides||{},[type,id]=selectedShape.split(':');if(type==='room_bounds')delete d.room_bounds_override;else if(type==='object')delete(o.objects||{})[id];else if(type==='placed')delete(o.placed||{})[id];else if(type==='service_building')delete o.service_building;else if(type==='water')delete o.water;await refreshMap();changed();});
 button('addWater',async()=>{checkpoint();const o=map.document.scene_collision_overrides??={};o.water??=clone(map.scene.surface_water_polygons_px||[]);o.water.push([[36,36],[108,36],[108,108],[36,108]]);selectedShape='water:'+(o.water.length-1);await refreshMap();changed();});
 $('targets').onchange=()=>{selectedShape=$('targets').value;view.draw();};
 bindMapPointer();if(map){mapControls();fitMap();}else await loadMap({id:catalog.templates[0].id});
}
async function loadMap(body){map=await api('map',body);view.images.clear();dirty=false;mapUndo=[];mapRedo=[];selectedShape='room_bounds';mapControls();fitMap();message('已读取 '+map.document.name+' · 不会自动覆盖保存');}
async function refreshMap(){map=await api('map',{document:map.document});mapControls();view.draw();}
function fitMap(){if(!map)return;let s=map.scene,f=s.floor_rect_px||[0,0,...map.document.grid.size.map(x=>x*36)],sc=map.document.grid.size.map((x,i)=>x*36/f[i+2]);view.fit([-f[0]*sc[0],-f[1]*sc[1],(s.canvas?.[0]||f[2])*sc[0],(s.canvas?.[1]||f[3])*sc[1]]);}
function mapControls(){if(!$('targets'))return;$('targets').innerHTML=options(map.shapes.map(s=>[s.key,s.label]),selectedShape);$('layers').innerHTML='';for(const layer of [...new Set(['background','walls','water_bridge','objects','buildings','lights','doors','spawns','collision','grid',...(map.scene.planes||[]).map(p=>p.layer)])].filter(Boolean)){
 const label=document.createElement('label');label.innerHTML=`<input type="checkbox" ${visibility[layer]!==false&&(layer!=='grid'||visibility.grid)?'checked':''}>${esc(layer)}`;if(layer==='grid'&&visibility.grid===undefined)label.firstChild.checked=false;label.firstChild.onchange=e=>{visibility[layer]=e.target.checked;view.draw();};$('layers').append(label);
}}
function mapHistory(redo){const from=redo?mapRedo:mapUndo,to=redo?mapUndo:mapRedo;if(!from.length)return;to.push(clone(map));map=from.pop();mapControls();changed();view.draw();}
async function saveMap(){if(!map)return;const result=await api('save_map',{document:map.document,revision:map.document.revision});map.document=result.document;dirty=false;message(result.message+(result.errors?.length?' · 有 '+result.errors.length+' 项验证提示':''));}
function pointInside(p,points){let inside=false;for(let i=0,j=points.length-1;i<points.length;j=i++){const a=points[i],b=points[j];if(((a[1]>p[1])!==(b[1]>p[1]))&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])inside=!inside;}return inside;}
function bindMapPointer(){const canvas=$('canvas');canvas.addEventListener('pointerdown',e=>{if(!map||pending||e.button!==0)return;const p=view.world(e);checkpoint();canvas.setPointerCapture(e.pointerId);
 if(mapMode==='collision'||mapMode==='rectangle'){
  let shape=map.shapes.find(s=>s.key===selectedShape);if(!shape)return;let points=shapeWorld(shape),index=points.findIndex(q=>distance(p,q)<10/view.scale);
  if(e.altKey&&index>=0&&shape.key!=='room_bounds'){points.splice(index,1);assignShape(shape,points);changed();view.draw();return;}
  if(e.shiftKey&&shape.key!=='room_bounds'){let best=0,d=Infinity;for(let i=0;i<points.length;i++){let q=points[i],r=points[(i+1)%points.length],m=[(q[0]+r[0])/2,(q[1]+r[1])/2];if(distance(m,p)<d){d=distance(m,p);best=i+1;}}points.splice(best,0,p);assignShape(shape,points);changed();view.draw();return;}
  if(mapMode==='rectangle'){drag={kind:'rect',shape,start:p};return;}
  if(index>=0){drag={kind:'vertex',shape,index,points,start:p};return;}
  let hit=[...map.shapes].reverse().find(s=>s.key!=='room_bounds'&&pointInside(p,shapeWorld(s)));if(hit){selectedShape=hit.key;shape=hit;points=shapeWorld(shape);$('targets').value=selectedShape;drag={kind:'shape',shape,points,start:p};view.draw();return;}
 }else if(mapMode==='markers'||mapMode==='ports'||mapMode==='light'){
  let entries=mapMode==='ports'?map.document.ports:mapMode==='light'?map.document.layers.entities.filter(x=>x.asset_id.startsWith('light:')):map.document.layers.markers;
  let entry=entries.find(x=>distance(p,x.at.map(n=>n*36+18))<24/view.scale);
  if(!entry&&mapMode==='light'){entry={id:'browser_light_'+Date.now(),asset_id:'light:'+$('lightKind').value+':'+$('lightSize').value,at:p.map(n=>Math.floor(n/36))};map.document.layers.entities.push(entry);changed();}
  if(!entry&&mapMode==='markers'){entry={id:'browser_spawn_'+Date.now(),asset_id:'spawn',at:p.map((n,i)=>Math.max(0,Math.min(map.document.grid.size[i]-1,Math.floor(n/36))))};map.document.layers.markers.push(entry);changed();}if(entry)drag={kind:'marker',entry};
 } });
 canvas.addEventListener('pointermove',e=>{if(!drag||e.buttons!==1)return;const p=view.world(e);if(drag.kind==='vertex'){let points=clone(drag.points);points[drag.index]=p;if(drag.shape.key==='room_bounds'){const opposite=drag.points[(drag.index+2)%4];points=rectPoints([Math.min(p[0],opposite[0]),Math.min(p[1],opposite[1]),Math.abs(p[0]-opposite[0]),Math.abs(p[1]-opposite[1])]);}assignShape(drag.shape,points);}
  if(drag.kind==='rect')assignShape(drag.shape,rectPoints([Math.min(drag.start[0],p[0]),Math.min(drag.start[1],p[1]),Math.abs(p[0]-drag.start[0]),Math.abs(p[1]-drag.start[1])]));
  if(drag.kind==='shape')assignShape(drag.shape,drag.points.map(q=>q.map((n,i)=>n+p[i]-drag.start[i])));
  if(drag.kind==='marker'){const grid=map.document.grid.size;drag.entry.at=p.map((n,i)=>Math.max(0,Math.min(grid[i]-1,Math.floor(n/36))));if(mapMode==='ports'){const a=drag.entry.at,side=drag.entry.side;if(side==='north'||side==='south')drag.entry.at=[Math.max(2,Math.min(grid[0]-3,a[0])),side==='north'?0:grid[1]-1];else drag.entry.at=[side==='west'?0:grid[0]-1,Math.max(2,Math.min(grid[1]-3,a[1]))];}}
  changed();view.draw();});canvas.addEventListener('pointerup',()=>{drag=null;view.draw();});
 canvas.addEventListener('contextmenu',e=>{if(!['light','markers'].includes(mapMode))return;let p=view.world(e),entries=mapMode==='light'?map.document.layers.entities:map.document.layers.markers,index=entries.findIndex(x=>(mapMode==='light'?x.asset_id.startsWith('light:'):x.asset_id==='spawn')&&distance(p,x.at.map(n=>n*36+18))<24/view.scale);if(index>=0){checkpoint();entries.splice(index,1);changed();view.draw();}});
}
function download(value,name){const a=document.createElement('a'),url=URL.createObjectURL(new Blob([JSON.stringify(value,null,2)],{type:'application/json'}));a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),500);}
function unitsPage(){balance=clone(catalog.balance);app.innerHTML=`<section class="form card"><h2>单位基础数值</h2><p>只修改基础值，难度、阶段、装备及暴怒继续按原规则计算。新启动的游戏生效。</p><select id="unit">${options(catalog.units.map(u=>[u.id,u.name]),selectedUnit)}</select><div class="fields" id="fields"></div><button id="saveUnits">保存全部数值</button><button id="resetUnit">恢复此单位默认值</button><button id="reloadUnits">重新载入</button></section>`;
 $('unit').onchange=()=>unitFields();button('saveUnits',async()=>{const saved=await api('save_units',{units:balance,revision:catalog.balance_revision});message(saved.message);catalog.balance_revision=saved.revision;catalog.balance=clone(balance);dirty=false;});button('resetUnit',()=>{delete balance[$('unit').value];changed();unitFields();});button('reloadUnits',async()=>{if(dirty&&!confirm('放弃未保存数值？'))return;catalog=await api('catalog');dirty=false;unitsPage();});unitFields();}
function unitPortrait(id){let old=$('unitPortrait');if(old)old.remove();let path='',cell=128;if(id.startsWith('boss:')){path='res://assets/boss_portraits_v09/'+id.slice(5)+'.png';cell=0;}else if(id.startsWith('enemy:')){let kind=id.slice(6);if(['moss_badger','bog_crab','ruin_sentinel','thorn_mantis','lantern_toad','dusk_acolyte'].includes(kind))path='res://assets/monsters_vnext/'+kind+'.png';else if(kind==='flyer'||kind==='bomber')path='res://assets/combat_revision_v04/monsters/'+(kind==='flyer'?'ghost':'ember')+'.png';else if(['goblin_scout','goblin_spearman','goblin_mage'].includes(kind))path='res://assets/forest_roster_v28/'+kind+'.png';else if(['bell_snail','glimmer_spider'].includes(kind))path='res://assets/content_v05/monsters/'+kind+'.png';else{let portrait={walker:'monster_skeleton',guard:'monster_skeleton2',charger:'monster_treant',caster:'monster_vampire',treant:'monster_treant'}[kind];if(portrait){path='res://assets/characters/'+portrait+'.png';cell=0;}}}if(!path)return;let canvas=document.createElement('canvas');canvas.id='unitPortrait';canvas.width=192;canvas.height=192;canvas.style.cssText='display:block;width:192px;height:192px;margin:12px auto;border-radius:12px;background:#182334';$('fields').before(canvas);let image=new Image();image.onload=()=>{if(!$('unitPortrait')||$('unit').value!==id)return;let ctx=canvas.getContext('2d');ctx.clearRect(0,0,192,192);ctx.imageSmoothingEnabled=true;if(cell)ctx.drawImage(image,0,0,cell,cell,0,0,192,192);else ctx.drawImage(image,0,0,image.width,image.height,0,0,192,192)};image.src='/asset?path='+encodeURIComponent(path)+'&token='+encodeURIComponent(token);}
function unitFields(){selectedUnit=$('unit').value;const row=catalog.units.find(u=>u.id===selectedUnit);$('fields').innerHTML='';unitPortrait(row.id);const names={hp:'基础生命',max_hp:'基础生命',attack:'基础攻击',speed:'基础移速',move_speed:'基础移速',coins:'基础金币',attack_speed:'攻速倍率',mp_regen:'MP回复/秒',dash_cooldown:'闪避冷却/秒',crit_chance:'暴击率',crit_mult:'暴击倍率',lifesteal:'命中回血',thorns:'反伤',coin_gain:'金币倍率',hp_multiplier:'生命继承倍率',attack_multiplier:'攻击继承倍率',speed_multiplier:'移速继承倍率'};for(const [key,value] of Object.entries(row.stats)){let label=document.createElement('label');label.textContent=(names[key]||key)+' · 默认 '+value;let input=document.createElement('input');input.type='number';input.min=0;input.max=10000000;input.step='.01';input.value=balance[row.id]?.[key]??value;input.oninput=()=>{const n=+input.value;if(!Number.isFinite(n)||n<0||n>10000000)return;(balance[row.id]??={})[key]=n;changed();};$('fields').append(label,input);}}
function consolePage(){app.innerHTML=`<section class="form card"><h2>物资控制台</h2><p>手动指定目标存档后才会写入。请关闭使用该存档的游戏，防止旧数据覆盖；每次发放前在工程外备份，并检查存档是否变化。</p><label>存档 JSON 路径 <input style="flex:1" id="savePath" value="${esc(catalog.save_path)}"></label><button id="loadSave">载入 / 重新载入</button><p id="saveInfo">尚未载入</p><select id="grantKind">${options([['gold','营地金库金币'],['coins','活跃出征随身金币'],['warehouse','物品 → 营地仓库（装备绑定）'],['bag','物品 → 活跃出征背包']])}</select><label>筛选物品 <input id="itemSearch"></label><select id="item" style="width:100%"></select><label>数量 <input type="number" min="1" max="1000000" step="1" value="1" id="amount"></label><button id="grant">预览并发放</button><hr><h3>传说套装 → 仓库</h3><select id="setHero">${options([['all','三角色全部套装 · 共9件'],...Object.entries(catalog.legendary_sets||{}).map(([id,set])=>[id,set.name+' · 3件'])])}</select><button id="grantSets">一键发放所选套装 · 每件1份</button></section>`;saveState=null;$('savePath').oninput=()=>{saveState=null;$('saveInfo').textContent='路径已改变，请重新载入。';};const filter=()=>$('item').innerHTML=options(catalog.items.filter(x=>(x.name+' '+x.id).toLowerCase().includes($('itemSearch').value.toLowerCase())).map(x=>[x.id,x.name+' ['+x.id+']']));filter();$('itemSearch').oninput=filter;
 button('grantSets',()=>{if(!saveState)throw Error('请先载入存档');const path=$('savePath').value,fingerprint=saveState.fingerprint,id=$('setHero').value;confirmBox(`目标：${path}\n仓库发放：${$('setHero').selectedOptions[0].text}\n每件1份；整批一次保存。`,async()=>{saveState=await api('grant',{path,fingerprint,kind:'legendary_sets',id,amount:1});$('saveInfo').textContent='套装已发放至仓库 · 备份：'+saveState.backup;message('传说套装发放完成。');});});
 button('loadSave',async()=>{saveState=await api('load_save',{path:$('savePath').value});$('saveInfo').textContent=`营地金库 ${saveState.gold} 金 · 活跃出征：${saveState.active?'有':'无'}`;message('存档已载入，尚未修改。');});
 button('grant',()=>{if(!saveState)throw Error('请先载入存档');const kind=$('grantKind').value,id=$('item').value,amount=+$('amount').value,path=$('savePath').value;if(!Number.isInteger(amount)||amount<1||amount>1000000)throw Error('数量必须为1—1000000的整数');const fingerprint=saveState.fingerprint;confirmBox(`目标：${path}\n发放至：${$('grantKind').selectedOptions[0].text}\n内容：${kind==='gold'||kind==='coins'?'金币':$('item').selectedOptions[0]?.text}\n数量：${amount}`,async()=>{saveState=await api('grant',{path,fingerprint,kind,id,amount});$('saveInfo').textContent=`营地金库 ${saveState.gold} 金 · 活跃出征：${saveState.active?'有':'无'}`;message('已发放 · 原档备份：'+saveState.backup);});});
}
let artDocument=0,artLayer=-1,artControl=-1,artMode='alpha',editCanvas=null,originalCanvas=null,artFingerprint='',strokes=[],redoStrokes=[],paintDrag=null;
async function artPage(){if(!art){art=await api('art');artSavedLayout=clone(art.layout);}app.innerHTML=`<aside class="sidebar"><h2>图层与界面</h2><select id="artDoc">${options(art.documents.map((d,i)=>[String(i),d.name]),String(artDocument))}</select><select id="artMode">${options([['alpha','透明边缘精修'],['layout','拖动文案 / 按钮']],artMode)}</select><label>画笔半径 <input id="brush" type="number" min="1" max="128" value="12"></label><label><input id="restore" type="checkbox">恢复原始透明度</label><label><input id="solo" type="checkbox">仅显示所选层</label><div class="rows" id="artLayers"></div><h3>可移动文案 / 按钮</h3><div class="rows" id="artControls"></div><label>文字字号 <input id="font" type="number" min="10" max="96"></label><button id="resetControl">恢复控件默认布局</button><p class="hint">底图只读。左键连续擦除或恢复非底图透明边缘；布局模式可拖动控件位置。不会改变图层的原尺寸、颜色和锚点。</p></aside><section class="workspace"><div class="toolbar"><button id="saveArt">保存并应用</button><button id="undoArt">撤销笔画</button><button id="redoArt">重做笔画</button><button id="fitArt">适应窗口</button></div><div class="viewport"><canvas id="canvas"></canvas></div></section>`;
 view=new View($('canvas'),drawArt);$('artDoc').onchange=run(async()=>{if(dirty&&!confirm('放弃未保存精修或布局？')){$('artDoc').value=artDocument;return;}if(dirty)art.layout=clone(artSavedLayout);artDocument=+$('artDoc').value;dirty=false;await selectArtDocument();});$('artMode').onchange=()=>{artMode=$('artMode').value;view.draw();};$('solo').onchange=()=>view.draw();button('fitArt',()=>view.fit([0,0,...art.documents[artDocument].canvas]));button('saveArt',saveArt);button('undoArt',()=>strokeHistory(false));button('redoArt',()=>strokeHistory(true));button('resetControl',()=>{const entry=art.documents[artDocument].controls[artControl];if(entry){delete art.layout[entry.id];changed();view.draw();}});$('font').onchange=()=>{const entry=art.documents[artDocument].controls[artControl];if(entry){(art.layout[entry.id]??={}).font_size=Math.max(10,Math.min(96,+$('font').value));changed();view.draw();}};
 bindArtPointer();await selectArtDocument();
}
async function selectArtDocument(){const doc=art.documents[artDocument];artLayer=-1;artControl=-1;editCanvas=null;originalCanvas=null;strokes=[];redoStrokes=[];$('artLayers').innerHTML='';doc.layers.forEach((layer,index)=>{const row=document.createElement('div'),visible=document.createElement('input'),b=document.createElement('button');visible.type='checkbox';visible.checked=layer.visible;visible.onchange=()=>{layer.visible=visible.checked;view.draw();};b.textContent=(layer.locked?'[底图] ':'')+layer.name;b.style.width='85%';b.onclick=run(()=>selectArtLayer(index));row.append(visible,b);$('artLayers').append(row);});$('artControls').innerHTML='';doc.controls.forEach((entry,index)=>{const b=document.createElement('button');b.textContent=entry.caption||entry.id;b.onclick=()=>{artControl=index;artMode='layout';$('artMode').value=artMode;$('font').value=art.layout[entry.id]?.font_size||entry.font_size;view.draw();};$('artControls').append(b);});view.fit([0,0,...doc.canvas]);message('图层已载入 · 底图只读，点击图层开始精修。');}
async function loadImage(path,original=false){const blob=await(await fetch('/asset?path='+encodeURIComponent(path)+'&token='+encodeURIComponent(token)+(original?'&original=1':''))).blob();return createImageBitmap(blob);}
async function selectArtLayer(index){if(dirty&&!confirm('请先保存；放弃当前精修再切换图层？'))return;if(dirty)art.layout=clone(artSavedLayout);dirty=false;artLayer=index;strokes=[];redoStrokes=[];const layer=art.documents[artDocument].layers[index];editCanvas=null;originalCanvas=null;if(!layer.locked){const current=await loadImage(layer.path),original=await loadImage(layer.path,true);editCanvas=document.createElement('canvas');editCanvas.width=current.width;editCanvas.height=current.height;editCanvas.getContext('2d').drawImage(current,0,0);originalCanvas=document.createElement('canvas');originalCanvas.width=current.width;originalCanvas.height=current.height;originalCanvas.getContext('2d').drawImage(original,0,0);current.close();original.close();artFingerprint=(await api('fingerprint',{path:layer.path})).fingerprint;}view.draw();message(layer.locked?'底图已保护，只能查看。':'选中 '+layer.name+' · 可擦除或恢复透明边缘。');}
function controlRect(entry){const r=[...(entry.preview_rect||entry.rect)],custom=art.layout[entry.id];if(custom?.position){r[0]+=custom.position[0]-entry.rect[0];r[1]+=custom.position[1]-entry.rect[1];}let parent=entry.parent;while(parent){const ancestor=art.documents[artDocument].controls.find(x=>x.id===parent);if(!ancestor)break;const o=art.layout[parent];if(o?.position){r[0]+=o.position[0]-ancestor.rect[0];r[1]+=o.position[1]-ancestor.rect[1];}parent=ancestor.parent;}return r;}
function drawArt(c,v){if(!art)return;const doc=art.documents[artDocument];doc.layers.forEach((layer,index)=>{if(!layer.visible&&index!==artLayer)return;if($('solo')?.checked&&index!==artLayer)return;if(index===artLayer&&editCanvas)c.drawImage(editCanvas,...layer.rect);else v.image(layer.path,layer.rect);});if(artMode==='layout')doc.controls.forEach((entry,index)=>{let r=controlRect(entry);c.strokeStyle=index===artControl?'#fae49f':'#79c7e9';c.lineWidth=2/v.scale;c.strokeRect(...r);c.fillStyle='#e5eef6';c.font=`${Math.min(24,art.layout[entry.id]?.font_size||entry.font_size)}px sans-serif`;c.textAlign='center';c.textBaseline='middle';c.fillText(entry.caption||entry.id,r[0]+r[2]/2,r[1]+r[3]/2,r[2]-5);});}
function artPoint(e){const p=view.world(e),layer=art.documents[artDocument].layers[artLayer],r=layer?.rect;return r&&editCanvas?[(p[0]-r[0])*editCanvas.width/r[2],(p[1]-r[1])*editCanvas.height/r[3]]:null;}
function brush(e){let p=artPoint(e);if(!p||!paintDrag)return;const radius=Math.max(1,Math.min(128,+$('brush').value)),c=editCanvas.getContext('2d'),start=paintDrag.last||p,count=Math.max(1,Math.ceil(distance(start,p)/Math.max(1,radius/2)));for(let n=1;n<=count;n++){const q=start.map((v,i)=>v+(p[i]-v)*n/count);c.save();c.beginPath();c.arc(...q,radius,0,Math.PI*2);c.clip();if($('restore').checked){c.clearRect(q[0]-radius,q[1]-radius,radius*2,radius*2);c.drawImage(originalCanvas,0,0);}else c.clearRect(q[0]-radius,q[1]-radius,radius*2,radius*2);c.restore();}paintDrag.last=p;changed();view.draw();}
function bindArtPointer(){const canvas=$('canvas');canvas.addEventListener('pointerdown',e=>{if(e.button!==0)return;canvas.setPointerCapture(e.pointerId);if(artMode==='alpha'&&editCanvas){strokes.push(editCanvas.getContext('2d').getImageData(0,0,editCanvas.width,editCanvas.height));while(strokes.length>8)strokes.shift();redoStrokes=[];paintDrag={};brush(e);}else if(artMode==='layout'){let p=view.world(e),controls=art.documents[artDocument].controls;for(let i=controls.length-1;i>=0;i--){let r=controlRect(controls[i]);if(p[0]>=r[0]&&p[0]<=r[0]+r[2]&&p[1]>=r[1]&&p[1]<=r[1]+r[3]){artControl=i;const entry=controls[i];paintDrag={start:p,position:[...(art.layout[entry.id]?.position||entry.rect.slice(0,2))]};$('font').value=art.layout[entry.id]?.font_size||entry.font_size;view.draw();break;}}}});canvas.addEventListener('pointermove',e=>{if(!paintDrag||e.buttons!==1)return;if(artMode==='alpha')brush(e);else{const entry=art.documents[artDocument].controls[artControl],p=view.world(e);(art.layout[entry.id]??={}).position=p.map((n,i)=>Math.round(paintDrag.position[i]+n-paintDrag.start[i]));changed();view.draw();}});canvas.addEventListener('pointerup',()=>paintDrag=null);}
function strokeHistory(redo){if(!editCanvas)return;const from=redo?redoStrokes:strokes,to=redo?strokes:redoStrokes;if(!from.length)return;const c=editCanvas.getContext('2d');to.push(c.getImageData(0,0,editCanvas.width,editCanvas.height));c.putImageData(from.pop(),0,0);changed();view.draw();}
async function saveArt(){if(editCanvas){const layer=art.documents[artDocument].layers[artLayer];const result=await api('alpha',{path:layer.path,fingerprint:artFingerprint,png:editCanvas.toDataURL('image/png')});artFingerprint=result.fingerprint;view.images.delete(layer.path);message(result.message);}const result=await api('save_layout',{layout:art.layout,revision:art.layout_revision});art.layout_revision=result.revision;artSavedLayout=clone(art.layout);dirty=false;message(result.message+' 图层精修需要等待 Godot 完成重新导入。');}
window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
window.addEventListener('keydown',e=>{const key=e.key.toLowerCase();if(!(e.ctrlKey||e.metaKey)||!['s','z'].includes(key))return;if(key==='z'&&document.activeElement?.matches('input,textarea'))return;e.preventDefault();run(async()=>{if(key==='s'){if(page==='map')await saveMap();else if(page==='art')await saveArt();else if(page==='units')$('saveUnits').click();else if(page==='story')await saveStory();}else if(page==='map')mapHistory(e.shiftKey);else if(page==='art')strokeHistory(e.shiftKey);})();});
run(async()=>{if(!token)throw Error('请通过 RoomEditor 启动文件打开本机开发工具');catalog=await api('catalog');await show('map');})();


let storyDoc=null, storyRevision='', storyKey=null, storyScenes={},storyMetadata={},storyVisible={},storyCategory='chapter1',storyGroup='';
async function storyPage(){
 const data=await api('story_catalog');storyMetadata=data.metadata||{};
 app.innerHTML=`<aside class="sidebar"><h2>剧情与分支</h2><label>角色<select id="storyHero">${options([['sylphiette','希露媞雅'],['xixifu','希希芙'],['ilyua','伊露雅']])}</select></label><label>演出<select id="storyReplay">${options([['first','首次'],['repeat','重访']])}</select></label><select id="storyId">${options(data.ids.map(id=>[id,id]))}</select><button id="storyLoad">定位节点</button><button id="storyExport">一键导出全部剧情 JSON</button><button id="storyTextExport">导出阅读稿 Markdown</button><p>从左到右查看场景、选项和后续节点。点击场景或分支，在右侧编辑。独立事件分开显示，回环保留连线。导出覆盖三角色首次／重访已保存内容。</p></aside><section class="workspace"><div class="toolbar"><button id="storyZoomOut">缩小</button><button id="storyZoomIn">放大</button><button id="storyReload">重新载入节点图</button></div><div id="storyTree" class="story-tree"></div></section><aside class="story-editor"><h2>节点编辑</h2><div id="storyOverride"></div><label>标题<input id="storyTitle"></label><h3>正文 JSON</h3><textarea id="storyLines" spellcheck="false"></textarea><h3>分支 JSON（最多3项）</h3><textarea id="storyChoices" spellcheck="false"></textarea><label>默认后续<input id="storyNext"></label><p>营地固定关系事件编辑回复与关系选择，不跳转主线节点。正文与分支中的其他原字段继续保留。</p><button id="storySave">保存节点</button><button id="storyReset">恢复此节点原稿</button></aside>`;
 const classification=document.createElement('div');classification.innerHTML=`<label>分类<select id="storyCategory">${options([['chapter1','第一章 · 苏醒林地'],['chapter2','第二章 · 失名星城'],['camp','营地'],['commissions','委托'],['records','回廊／兼容记录']],storyCategory)}</select></label><label>人物／事件组<select id="storyGroup"></select></label>`;
 $('storyId').before(classification);
 $('storyCategory').onchange=run(()=>changeStoryCategory());$('storyGroup').onchange=run(()=>changeStoryGroup());
 const note=document.createElement('p');note.className='hint';note.textContent='实线：正文／选项跳转。虚线：实际流程的先后或前置条件，不会改写next。清房与Boss节点依实际路线触发，可选节点可能跳过。';$('storyTree').before(note);
 const trigger=document.createElement('p');trigger.id='storyTrigger';trigger.className='story-trigger';$('storyOverride').after(trigger);
 button('storyLoad',()=>{const id=$('storyId').value;return selectStory(id).then(()=>document.querySelector('.story-node.selected')?.scrollIntoView({block:'nearest',inline:'center'}));});button('storySave',saveStory);
 button('storyReset',async()=>{if(!storyKey||!confirm('恢复当前节点原稿？'))return;const r=await api('save_story',{...storyKey,revision:storyRevision,scene:null});storyScenes[storyKey.id]=r.scene;displayStory(r);drawStoryTree();});
 button('storyReload',()=>reloadStoryTree());
 $('storyHero').onchange=run(()=>reloadStoryTree());$('storyReplay').onchange=run(()=>reloadStoryTree());
 button('storyExport',()=>exportStories(false));button('storyTextExport',()=>exportStories(true));
 let zoom=1;const scale=()=>{const stage=$('storyTree').firstElementChild;if(stage){stage.style.transform=`scale(${zoom})`;stage.style.transformOrigin='0 0';}};
 button('storyZoomOut',()=>{zoom=Math.max(.3,zoom-.1);scale();});button('storyZoomIn',()=>{zoom=Math.min(1.5,zoom+.1);scale();});
 for(const id of ['storyTitle','storyLines','storyChoices','storyNext'])$(id).oninput=changed;
 await reloadStoryTree();
}
async function reloadStoryTree(){
 if(dirty&&!confirm('放弃未保存的节点修改并重新载入？')){if(storyKey){$('storyHero').value=storyKey.hero;$('storyReplay').value=storyKey.replay?'repeat':'first';}return;}
 const hero=$('storyHero').value,replay=$('storyReplay').value==='repeat';
 const bundle=await api('story_bundle',{hero,replay});storyScenes=bundle.variants[hero+'|'+(replay?'repeat':'first')]||{};dirty=false;
 storyMetadata=bundle.metadata||storyMetadata;refreshStoryGroups();await showStoryCategory();
}
function refreshStoryGroups(){
 const groups=[...new Set(Object.keys(storySelection(storyScenes,storyMetadata,storyCategory)).map(id=>storyMetadata[id]?.group).filter(Boolean))];
 if(!groups.includes(storyGroup))storyGroup='';
 $('storyGroup').innerHTML=options([['','全部'],...groups.map(g=>[g,g])],storyGroup);$('storyGroup').disabled=!['camp','commissions','records'].includes(storyCategory);
}
async function showStoryCategory(){
 storyVisible=storySelection(storyScenes,storyMetadata,storyCategory,storyGroup);
 $('storyId').innerHTML=options(Object.entries(storyVisible).map(([id,s])=>[id,(s.title||id)+' ['+id+']']),storyKey?.id);
 drawStoryTree();await selectStory(storyVisible[storyKey?.id]?storyKey.id:$('storyId').value);
 if(!Object.keys(storyVisible).length)message('此分类暂无可编辑剧情');
}
async function changeStoryCategory(){
 if(dirty&&!confirm('放弃未保存修改并切换剧情分类？')){$('storyCategory').value=storyCategory;return;}
 dirty=false;storyCategory=$('storyCategory').value;storyGroup='';refreshStoryGroups();await showStoryCategory();
}
async function changeStoryGroup(){
 if(dirty&&!confirm('放弃未保存修改并切换事件组？')){$('storyGroup').value=storyGroup;return;}
 dirty=false;storyGroup=$('storyGroup').value;await showStoryCategory();
}
function drawStoryTree(){
 const host=$('storyTree');if(!host)return;host.innerHTML='';
 storyVisible=storySelection(storyScenes,storyMetadata,storyCategory,storyGroup);
 const graph=storyLayout(storyVisible,storyMetadata),stage=document.createElement('div');stage.className='story-stage';stage.style.width=graph.width+'px';stage.style.height=graph.height+'px';host.append(stage);
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('width',graph.width);svg.setAttribute('height',graph.height);svg.classList.add('story-links');stage.append(svg);
 const byKey=new Map(graph.nodes.map(n=>[n.key,n]));
 for(const edge of graph.edges){const a=byKey.get(edge.from),b=byKey.get(edge.to),path=document.createElementNS(svg.namespaceURI,'path'),x=a.x+270,y=a.y+60;path.setAttribute('d',`M${x},${y} C${x+30},${y} ${b.x-30},${b.y+60} ${b.x},${b.y+60}`);if(edge.kind==='chronology')path.classList.add('chronology');svg.append(path);}
 for(const node of graph.nodes){const button=document.createElement('button');button.className='story-node '+node.kind+(storyKey?.id===node.id?' selected':'');button.style.left=node.x+'px';button.style.top=node.y+'px';button.dataset.scene=node.id;button.title=node.label+'\n'+(node.trigger||'');const caption=document.createElement('strong');caption.textContent=node.label||'空分支';const sub=document.createElement('span');sub.textContent=node.kind==='choice'?'选项 '+(node.index+1)+(node.ending?' · 本段结束':''):node.id;button.append(caption,sub);if(node.trigger){const timing=document.createElement('small');timing.textContent=node.trigger;button.append(timing);}button.onclick=run(()=>selectStory(node.id,node.kind==='choice'?node.index:null));stage.append(button);}
}
async function selectStory(id,index=null){
 if(!id)return;if(dirty&&!confirm('放弃当前节点未保存修改？'))return;
 const key={id,hero:$('storyHero').value,replay:$('storyReplay').value==='repeat'};
 const r=await api('story_scene',key);storyKey=key;$('storyId').value=id;displayStory(r);
 document.querySelectorAll('.story-node').forEach(b=>b.classList.toggle('selected',b.dataset.scene===id));
 if(index!==null){$('storyChoices').focus();message('正在编辑 '+id+' 的第'+(index+1)+'个选项');}
}
function displayStory(r){
 storyDoc=r.scene;storyRevision=r.revision;dirty=false;
 $('storyTitle').value=storyDoc.title||'';$('storyLines').value=JSON.stringify(storyDoc.lines||[],null,2);$('storyChoices').value=JSON.stringify(storyDoc.choices||[],null,2);$('storyNext').value=storyDoc.next||'';
 $('storyOverride').textContent=storyKey.id+' · '+storyKey.hero+' · '+(storyKey.replay?'重访':'首次')+' · '+(r.overridden?'已使用编辑稿':'原稿');
 const metadata=storyMetadata[storyKey.id]||{};$('storyTrigger').textContent=(metadata.group||'')+'\n触发时机：'+(metadata.trigger||'未标注');
 const commission=storyKey.id.startsWith('commission:');$('storyChoices').disabled=commission;$('storyNext').disabled=commission;
 message('已载入节点；保存前不会改变工程。');
}
async function saveStory(){
 if(!storyKey)return;
 const scene={...clone(storyDoc),title:$('storyTitle').value,lines:JSON.parse($('storyLines').value),choices:JSON.parse($('storyChoices').value),next:$('storyNext').value.trim()};
 const r=await api('save_story',{...storyKey,revision:storyRevision,scene});storyScenes[storyKey.id]=r.scene;displayStory(r);drawStoryTree();message(r.message);
}
async function exportStories(readable){
 if(dirty)throw Error('请先保存当前节点，再导出剧情');
 const bundle=await api('story_bundle');
 if(!readable){download(bundle,'PixelRogue-story.json');message('已导出全部剧情与分支 JSON');return;}
 const parts=['# PixelRogue 剧情阅读稿',bundle.scope];
 for(const [variant,scenes] of Object.entries(bundle.variants)){
  parts.push('\n# '+variant);
  for(const [id,scene] of Object.entries(scenes)){
   parts.push('\n## '+scene.title+' ['+id+']');
   const metadata=bundle.metadata?.[id];if(metadata)parts.push('分类：'+metadata.group+'\n触发时机：'+metadata.trigger);
   for(const line of scene.lines||[])parts.push(typeof line==='string'?line:(line.who?line.who+'：':'')+line.text);
   for(const [i,choice] of (scene.choices||[]).entries()){
    parts.push('\n### 选项 '+(i+1)+'：'+choice.text+' → '+((Object.prototype.hasOwnProperty.call(choice,'next')?choice.next:scene.next)||'结束'));
    for(const line of choice.reply||[])parts.push(typeof line==='string'?line:(line.who?line.who+'：':'')+line.text);
    const effects={...choice};delete effects.text;delete effects.reply;parts.push('分支条件／后果：'+JSON.stringify(effects));
   }
   if(scene.next)parts.push('默认后续：'+scene.next);
  }
 }
 const url=URL.createObjectURL(new Blob([parts.join('\n\n')],{type:'text/markdown;charset=utf-8'})),link=document.createElement('a');link.href=url;link.download='PixelRogue-story.md';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);message('已导出剧情阅读稿');
}
