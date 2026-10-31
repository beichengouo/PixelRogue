const assert=require('node:assert/strict');
const {storyLayout}=require('./story_graph');
const scenes={start:{title:'开始',choices:[{text:'前进',next:'end'},{text:'停下',next:''}]},end:{title:'结束',next:'start'},independent:{title:'独立事件'}};
const graph=storyLayout(scenes),by=new Map(graph.nodes.map(n=>[n.key,n]));
assert.equal(graph.nodes.length,5);assert.equal(graph.edges.length,4);
assert.ok(by.get('start::choice:0').x>by.get('start').x);
assert.ok(by.get('end').x>by.get('start::choice:0').x);
assert.equal(by.get('start::choice:1').id,'start');
assert.equal(by.get('start::choice:1').index,1);
assert.equal(by.get('start::choice:1').ending,true);
assert.ok(graph.nodes.every(n=>Number.isFinite(n.x)&&Number.isFinite(n.y)));
assert.equal(new Set(graph.nodes.map(n=>n.x+','+n.y)).size,graph.nodes.length);
assert.equal(storyLayout({}).nodes.length,0);
console.log('STORY_GRAPH cycles, shared targets, endings, disconnected nodes: PASS');

const fallback=storyLayout({a:{next:'b',choices:[{text:'继承默认'}]},b:{}});assert(fallback.edges.some(e=>e.from==='a::choice:0'&&e.to==='b'));
const shared=storyLayout({a:{choices:[{text:'1',next:'b'},{text:'2',next:'b'}]},b:{}});assert.equal(shared.nodes.filter(n=>n.key==='b').length,1);

const {storySelection}=require('./story_graph');
const meta={entry:{category:'chapter1',order:0,trigger:'出生房'},clear:{category:'chapter1',order:1,after:['entry'],trigger:'清房后'},boss:{category:'chapter1',order:2,after:['clear']},camp:{category:'camp'},echo:{category:'chapter1',categories:['chapter1','chapter2'],order:99,after:['boss']}};
const data={entry:{choices:[{text:'答复',next:''}]},clear:{},boss:{},camp:{},echo:{}};
const selected=storySelection(data,meta,'chapter1');assert.deepEqual(Object.keys(selected),['entry','clear','boss','echo']);
const chapter=storyLayout(selected,meta),positions=new Map(chapter.nodes.map(n=>[n.id,n.x]));
assert(positions.get('entry')<positions.get('clear'));assert(positions.get('clear')<positions.get('boss'));assert(positions.get('boss')<positions.get('echo'));
assert(chapter.edges.some(e=>e.kind==='chronology'));assert.equal(data.clear.next,undefined);
assert.equal(chapter.nodes.find(n=>n.key==='clear').trigger,'清房后');assert.deepEqual(Object.keys(storySelection(data,meta,'chapter2')),['echo']);
console.log('STORY_GRAPH category filtering, shared chapter event, chronological positions and trigger labels: PASS');
