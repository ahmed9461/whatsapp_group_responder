import 'package:flutter/material.dart';
import '../../core/models.dart';

class GroupSelector extends StatelessWidget {
  const GroupSelector({super.key,required this.groups,required this.mode,required this.selectedIds,required this.onModeChanged,required this.onSelectionChanged,this.allLabel='جميع المجموعات المعتمدة'});
  final List<ApiGroup> groups; final String mode; final Set<int> selectedIds; final ValueChanged<String> onModeChanged; final ValueChanged<Set<int>> onSelectionChanged; final String allLabel;
  @override Widget build(BuildContext context){final approved=groups.where((g)=>g.approved).toList();return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    SegmentedButton<String>(segments:[ButtonSegment(value:'all',icon:const Icon(Icons.public_rounded),label:Text(allLabel)),const ButtonSegment(value:'selected',icon:Icon(Icons.checklist_rounded),label:Text('مجموعات محددة'))],selected:{mode},onSelectionChanged:(v)=>onModeChanged(v.first)),const SizedBox(height:12),
    if(mode=='all')Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[const Icon(Icons.verified_user_outlined),const SizedBox(width:12),Expanded(child:Text('سيتم استخدام كل المجموعات المعتمدة فقط (${approved.length}). المجموعات المعلقة أو المرفوضة لا تدخل في الاستهداف.'))])))
    else if(approved.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('لا توجد مجموعات معتمدة للاختيار.')))
    else ...[Row(children:[Text('المحدد: ${selectedIds.length}'),const Spacer(),TextButton(onPressed:()=>onSelectionChanged(approved.map((e)=>e.id).toSet()),child:const Text('تحديد الكل')),TextButton(onPressed:()=>onSelectionChanged(<int>{}),child:const Text('مسح'))]),const SizedBox(height:4),...approved.map((g)=>Card(margin:const EdgeInsets.only(bottom:6),child:CheckboxListTile(value:selectedIds.contains(g.id),title:Text(g.name),subtitle:g.memberCount==null?null:Text('${g.memberCount} عضو'),secondary:const Icon(Icons.groups_rounded),onChanged:(v){final next={...selectedIds};if(v==true){next.add(g.id);}else{next.remove(g.id);}onSelectionChanged(next);})))],
  ]);}
}
