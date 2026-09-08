<?php
// Isolated SQLite memory fixture: real Eloquent relation and GET serializer.
require __DIR__.'/../../../BACKEND UBER AVIONES/vendor/autoload.php';
use Illuminate\Database\Capsule\Manager as Capsule;
use App\Modelos\ChecklistOperacion;
use App\Servicios\Sobrecargo\CrewOperationWorkflowService;
$c=new Capsule;
$c->addConnection(['driver'=>'sqlite','database'=>':memory:']);
$c->setAsGlobal(); $c->bootEloquent();
$c->schema()->create('checklists', function($t){$t->id();$t->string('type');$t->string('status');$t->timestamp('submitted_at')->nullable();$t->timestamps();});
$c->schema()->create('checklist_items', function($t){$t->id();$t->integer('checklist_id');$t->string('code');$t->string('category');$t->string('label');$t->string('status');$t->boolean('is_required')->default(true);$t->boolean('is_critical')->default(false);$t->string('notes')->nullable();$t->boolean('is_completed')->default(false);$t->timestamp('completed_at')->nullable();$t->integer('completed_by')->nullable();$t->text('evidence_files')->nullable();$t->timestamps();if (!in_array('--without-index', $_SERVER['argv'], true)) $t->index(['checklist_id','status'],'idx_checklist_item_status');});
$service=new CrewOperationWorkflowService;
$serialize=new ReflectionMethod($service,'serializeChecklist');
foreach(['service'=>['Faltantes registrados','Catering sobrante registrado'],'operation'=>['Ruta revisada','Aeronave revisada'],'cabin'=>['Limpieza de cabina','Asientos y cinturones','Equipaje asegurado','Baño revisado']] as $category=>$labels){
 $cl=ChecklistOperacion::create(['type'=>'preflight','status'=>'pending']);
 // Insert the requested order; the database query may return another order.
 foreach($labels as $i=>$label) $cl->items()->create(['code'=>'item'.$i,'category'=>$category,'label'=>$label,'status'=>$i===0?'pending':'completed']);
 $snapshot=function($ordered=false)use($cl,$service,$serialize){$fresh=$cl->fresh();if($ordered)$fresh->load(['items'=>fn($q)=>$q->orderBy('id')]);else $fresh->load('items');$p=$serialize->invoke($service,$fresh);return collect($p['items'])->map(fn($i)=>['id'=>$i['id'],'section'=>$i['category'],'status'=>$i['status']])->all();};
 $before=$snapshot();
 $first=$cl->items()->orderBy('id')->first();
 $first->update(['status'=>'completed','notes'=>'audit','is_completed'=>true,'completed_at'=>date('Y-m-d H:i:s'),'completed_by'=>1]);
 echo json_encode(['fixture'=>$category,'before_get'=>$before,'after_put_order'=>$snapshot(true),'after_get'=>$snapshot(),'refresh_get'=>$snapshot()],JSON_UNESCAPED_UNICODE).PHP_EOL;
}
echo 'relation SQL: '.ChecklistOperacion::first()->items()->toSql().PHP_EOL;
