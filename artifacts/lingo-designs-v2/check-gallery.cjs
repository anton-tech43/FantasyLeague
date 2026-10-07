const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(require('path').join(__dirname,'questions.html'),'utf8');
const code=html.split('<script>')[1].split('</script>')[0];
const sandbox={document:{addEventListener(){},querySelectorAll(){return []},getElementById(){return {textContent:''}}},localStorage:{getItem(){return null},setItem(){}},console};
vm.createContext(sandbox);vm.runInContext(code,sandbox);
vm.runInContext(`
function test(ok,msg){if(!ok)throw Error(msg)}
test(questions.length===7,'seven real questions');
for(let id=1;id<=20;id++){
 const s=states[id-1];
 test(!submitState(s),'cannot submit without selection');
 for(let i=0;i<7;i++){
  test(s.index===i,'advances once');
  let html=questionView(s,id);
  test((html.match(/data-choice=/g)||[]).length===2,'exactly two choices');
  s.selected=i%3===0?1-correctIndex(i):correctIndex(i);
  test(submitState(s),'records answer');
  test(!submitState(s),'blocks duplicate grading');
  const before=s.answers.length;
  revealView(s,true);revealView(s,false);resultView(s,true);
  test(s.answers.length===before,'previews do not mutate game');
  test(revealView(s,null).includes(esc(questions[i].sayIt)),'correct reply follows current question');
  s.view='home';s.view='reveal';
  test(s.index===i,'pause preserves index');
  test(nextState(s),'next requires answered');
 }
 test(s.view==='result'&&s.answers.length===7,'completes full round');
 test(s.answers.filter(Boolean).length===4,'accurate score');
 test(resultView(s,false).includes('4<small> / 7'),'result matches played round');
 resetState(s);test(s.index===0&&s.answers.length===0&&s.selected===null,'restart resets round');
}
console.log('PASS: 20 layouts × 7 questions; scoring, duplicate protection, preview isolation, pause and restart.');
`,sandbox);
assert.equal((html.match(/class="concept" data-id=/g)||[]).length,20);
