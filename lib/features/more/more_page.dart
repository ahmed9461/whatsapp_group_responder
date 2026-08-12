import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../ai/ai_chat_page.dart';
import '../approvals/approvals_page.dart';
import '../groups/groups_page.dart';
import '../settings/settings_page.dart';
import '../statistics/statistics_page.dart';

class MorePage extends StatelessWidget{const MorePage({super.key,required this.controller});final AppController controller;@override Widget build(BuildContext context){final items=<({IconData icon,String title,String subtitle,Widget page})>[(icon:Icons.groups_rounded,title:'المجموعات',subtitle:'المجموعات المعتمدة وحالة الردود',page:GroupsPage(controller:controller)),(icon:Icons.approval_rounded,title:'الموافقات',subtitle:'طلبات اعتماد المجموعات الجديدة',page:ApprovalsPage(controller:controller)),(icon:Icons.bar_chart_rounded,title:'الإحصائيات',subtitle:'الاستخدام والردود الأكثر نشاطًا',page:StatisticsPage(controller:controller)),(icon:Icons.auto_awesome_rounded,title:'الذكاء الاصطناعي',subtitle:'محادثة DeepSeek مع تنسيق Markdown',page:AiChatPage(controller:controller)),(icon:Icons.settings_rounded,title:'الإعدادات',subtitle:'الخادم والمظهر والجلسة',page:SettingsPage(controller:controller))];return Scaffold(backgroundColor:Colors.transparent,appBar:AppBar(title:const Text('المزيد'),backgroundColor:Colors.transparent),body:ListView.separated(padding:const EdgeInsets.all(16),itemCount:items.length,separatorBuilder:(_,_)=>const SizedBox(height:10),itemBuilder:(context,index){final e=items[index];return Card(child:ListTile(leading:CircleAvatar(child:Icon(e.icon)),title:Text(e.title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(e.subtitle),trailing:const Icon(Icons.chevron_left_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>e.page))));}));}}
