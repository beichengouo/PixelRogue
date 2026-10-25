// Pure authoring geometry tests. No browser automation or game-state access.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(__dirname+'/app.js','utf8').split('run(async()=>{if(!token)')[0];
const elements=new Map();const element=id=>{if(!elements.has(id))elements.set(id,{textContent:'',value:'',style:{},isConnected:true});return elements.get(id);};
const context={console,URLSearchParams,location:{hash:'#isolated'},document:{querySelector:s=>element(s),getElementById:element,querySelectorAll:()=>[]},window:{addEventListener:()=>{}},confirm:()=>true};
vm.createContext(context);vm.runInContext(source,context);
const tests=`
let checks=0;function verify(x,label){if(!x)throw Error(label);checks++;}
map={document:{grid:{size:[23,13]},layers:{markers:[],entities:[]}},bounds:[0,0,828,468],shapes:[],scene:{surface_water_polygons_px:[]}};
let shape={key:'object:fixture',origin:[100,80],polygon:[[-10,-5],[10,-5],[10,0],[-10,0]]};
verify(JSON.stringify(shapeWorld(shape))==='[[90,75],[110,75],[110,80],[90,80]]','local/world collision conversion');
assignShape(shape,[[95,70],[120,70],[120,90],[95,90]]);
verify(JSON.stringify(map.document.scene_collision_overrides.objects.fixture)==='[[-5,-10],[20,-10],[20,10],[-5,10]]','saved collision keeps local origin');
let water={key:'water:0',origin:[0,0],polygon:[]};map.scene.surface_water_polygons_px=[[]];assignShape(water,[[1,2],[3,2],[3,4]]);
verify(JSON.stringify(map.document.scene_collision_overrides.water[0])==='[[1,2],[3,2],[3,4]]','water remains world-space');
assignShape({key:'room_bounds'},[[10,20],[800,20],[800,450],[10,450]]);
verify(JSON.stringify(map.document.room_bounds_override)==='[10,20,790,430]','outer boundary persists rectangle');
verify(pointInside([5,5],[[0,0],[10,0],[10,10],[0,10]])&&!pointInside([20,5],[[0,0],[10,0],[10,10],[0,10]]),'shape hit test');
art={documents:[{controls:[{id:'parent',rect:[100,200,300,300],preview_rect:[100,200,300,300],parent:''},{id:'child',rect:[10,20,50,30],preview_rect:[110,220,50,30],parent:'parent'}]}],layout:{parent:{position:[120,230]},child:{position:[15,28]}}};artDocument=0;
verify(JSON.stringify(controlRect(art.documents[0].controls[1]))==='[135,258,50,30]','dragged child follows parent without double offset');
delete art.layout.child;verify(JSON.stringify(controlRect(art.documents[0].controls[1]))==='[130,250,50,30]','reset restores local layout with moved parent');
console.log('BROWSER_GEOMETRY checks='+checks+' failures=0');
`;
vm.runInContext(tests,context);
