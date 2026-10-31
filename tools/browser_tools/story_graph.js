/* Deterministic, cycle-safe left-to-right layout. Edges only represent authored links. */
function storyLayout(scenes,metadata={}){
 const nodes=[],edges=[],byId=new Map(),incoming=new Set();
 for(const [id,scene] of Object.entries(scenes)){
  const node={key:id,id,label:scene.title||id,kind:'scene',trigger:metadata[id]?.trigger||'',group:metadata[id]?.group||''};nodes.push(node);byId.set(id,node);
 }
 for(const [id,scene] of Object.entries(scenes)){
  if(scene.next&&byId.has(scene.next)){edges.push({from:id,to:scene.next});incoming.add(scene.next);}
  (scene.choices||[]).forEach((choice,index)=>{
   const key=id+'::choice:'+index,target=Object.prototype.hasOwnProperty.call(choice,'next')?choice.next:scene.next;
   nodes.push({key,id,index,label:choice.text,kind:'choice',ending:!target});byId.set(key,nodes[nodes.length-1]);
   edges.push({from:id,to:key});incoming.add(key);
   if(target&&byId.has(target)){edges.push({from:key,to:target});incoming.add(target);}
  });
 }
 // Chronology links explain separate runtime triggers. They never become next.
 for(const id of Object.keys(scenes))for(const prior of metadata[id]?.after||[]){
  if(byId.has(prior)&&!edges.some(e=>e.from===prior&&e.to===id)){
   edges.push({from:prior,to:id,kind:'chronology',step:(scenes[prior].choices||[]).length?2:1});incoming.add(id);
  }
 }
 const children=new Map();for(const edge of edges){if(!children.has(edge.from))children.set(edge.from,[]);children.get(edge.from).push(edge);}
 const visited=new Set(),columns=new Map();
 function walk(root){const queue=[[root,0]];for(let n=0;n<queue.length;n++){const [key,depth]=queue[n];if(visited.has(key))continue;visited.add(key);const node=byId.get(key);node.depth=depth;node.x=24+depth*310;const row=columns.get(depth)||0;node.y=24+row*154;columns.set(depth,row+1);for(const edge of children.get(key)||[])queue.push([edge.to,depth+(edge.step||1)]);}}
 for(const node of nodes)if(!incoming.has(node.key)&&node.kind==='scene')walk(node.key);
 for(const node of nodes)if(!visited.has(node.key))walk(node.key);
 return {nodes,edges,width:Math.max(600,...nodes.map(n=>n.x+286)),height:Math.max(300,...nodes.map(n=>n.y+146))};
}
function storySelection(scenes,metadata,category,group=''){
 return Object.fromEntries(Object.entries(scenes).filter(([id])=>{
  const m=metadata[id]||{};return (m.category===category||(m.categories||[]).includes(category))&&(!group||m.group===group);
 }).sort(([a],[b])=>(metadata[a]?.order||0)-(metadata[b]?.order||0)));
}
if(typeof module!=='undefined')module.exports={storyLayout,storySelection};
