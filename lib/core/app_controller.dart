import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'api/api_client.dart';
import 'models.dart';
import 'storage/preferences_store.dart';
import 'storage/secure_store.dart';

class AppController extends ChangeNotifier {
  final secureStore=SecureStore(); final preferences=PreferencesStore(); late ApiClient api;
  bool isLinked=false,busy=false; String? error; ThemeMode themeMode=ThemeMode.system; String serverUrl='https://vmi3452413.tailc13979.ts.net/api/v1';
  Map<String,dynamic> status={}; ApiStatistics statistics=ApiStatistics.empty; Map<String,dynamic> settings={}; ApiWhatsAppStatus whatsappStatus=ApiWhatsAppStatus.empty;
  List<ApiCommand> commands=[]; List<ApiGroup> groups=[]; List<ApiApproval> approvals=[]; List<ApiScheduledCampaign> scheduledCampaigns=[]; List<ApiBroadcast> broadcasts=[];
  StreamSubscription<Map<String,dynamic>>? _events; Timer? _eventReconnect,_fallbackRefresh; bool _liveRefreshRunning=false,_liveRefreshQueued=false;
  List<ApiGroup> get approvedGroups=>groups.where((g)=>g.approved).toList();
  Future<void> initialize()async{serverUrl=await preferences.getServerUrl();themeMode=switch(await preferences.getThemeMode()){'light'=>ThemeMode.light,'dark'=>ThemeMode.dark,_=>ThemeMode.system};api=ApiClient(secureStore:secureStore,baseUrl:serverUrl);isLinked=(await secureStore.refreshToken)!=null;if(isLinked){await refreshAll(silent:true);_startLiveUpdates();}notifyListeners();}
  Future<String> ensureDeviceInstanceId()async{final x=await secureStore.deviceInstanceId;if(x!=null&&x.length>=12)return x;final r=Random.secure();const c='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';final v='android-${List.generate(32,(_)=>c[r.nextInt(c.length)]).join()}';await secureStore.saveDeviceInstanceId(v);return v;}
  Future<void> setServerUrl(String v)async{serverUrl=v.trim();await preferences.setServerUrl(serverUrl);api.setBaseUrl(serverUrl);notifyListeners();}
  Future<void> completeLink(SessionTokens t)async{await secureStore.saveSession(accessToken:t.accessToken,refreshToken:t.refreshToken);isLinked=true;await refreshAll();_startLiveUpdates();notifyListeners();}
  Future<void> unlinkLocal()async{await secureStore.clearProjectSession();await _events?.cancel();_eventReconnect?.cancel();_fallbackRefresh?.cancel();isLinked=false;commands=[];groups=[];approvals=[];scheduledCampaigns=[];broadcasts=[];status={};statistics=ApiStatistics.empty;settings={};whatsappStatus=ApiWhatsAppStatus.empty;notifyListeners();}
  Future<void> refreshAll({bool silent=false})async{if(!silent){busy=true;error=null;notifyListeners();}final errs=<Object>[];try{await Future.wait<void>([_capture(()async=>status=await api.getStatus(),errs),_capture(()async=>commands=await api.getCommands(),errs),_capture(()async=>groups=await api.getGroups(),errs),_capture(()async=>approvals=await api.getApprovals(),errs),_capture(()async=>statistics=ApiStatistics.fromJson(await api.getStatistics()),errs),_capture(()async=>settings=await api.getSettings(),errs),_capture(()async=>whatsappStatus=ApiWhatsAppStatus.fromJson(await api.getWhatsAppStatus()),errs),_capture(()async=>scheduledCampaigns=await api.getScheduledCampaigns(),errs),_capture(()async=>broadcasts=await api.getBroadcasts(),errs)]);isLinked=(await secureStore.refreshToken)!=null;error=errs.isEmpty?null:'${errs.first}';}finally{if(!silent)busy=false;notifyListeners();}}
  Future<void> _capture(Future<void> Function() op,List<Object> errs)async{try{await op();}catch(e){errs.add(e);}}
  Future<void> refreshCommands()async{commands=await api.getCommands();notifyListeners();} Future<void> refreshGroups()async{groups=await api.getGroups();notifyListeners();} Future<void> refreshApprovals()async{approvals=await api.getApprovals();notifyListeners();} Future<void> refreshStats()async{statistics=ApiStatistics.fromJson(await api.getStatistics());notifyListeners();} Future<void> refreshWhatsApp()async{whatsappStatus=ApiWhatsAppStatus.fromJson(await api.getWhatsAppStatus());notifyListeners();} Future<void> refreshScheduled()async{scheduledCampaigns=await api.getScheduledCampaigns();notifyListeners();} Future<void> refreshBroadcasts()async{broadcasts=await api.getBroadcasts();notifyListeners();}
  Future<void> setThemeMode(ThemeMode m)async{themeMode=m;await preferences.setThemeMode(m.name);notifyListeners();}
  void _startLiveUpdates(){_startEvents();_fallbackRefresh?.cancel();_fallbackRefresh=Timer.periodic(const Duration(seconds:30),(_){if(isLinked)unawaited(_refreshFromLiveSignal());});} void _startEvents(){_events?.cancel();_eventReconnect?.cancel();_events=api.events().listen((_)=>unawaited(_refreshFromLiveSignal()),onDone:_scheduleEventReconnect,onError:(_)=>_scheduleEventReconnect());}
  Future<void> _refreshFromLiveSignal()async{if(!isLinked)return;if(_liveRefreshRunning){_liveRefreshQueued=true;return;}_liveRefreshRunning=true;try{do{_liveRefreshQueued=false;await refreshAll(silent:true);}while(_liveRefreshQueued&&isLinked);}finally{_liveRefreshRunning=false;}}
  void _scheduleEventReconnect(){_eventReconnect?.cancel();if(!isLinked)return;_eventReconnect=Timer(const Duration(seconds:5),_startEvents);} @override void dispose(){_events?.cancel();_eventReconnect?.cancel();_fallbackRefresh?.cancel();api.close();super.dispose();}
}
