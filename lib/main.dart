import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const primary = Color(0xFF5963A6);

class Person {
  String id, name;
  Person(this.id, this.name);
  Map<String,dynamic> toJson()=>{'id':id,'name':name};
  factory Person.fromJson(Map<String,dynamic> x)=>Person('${x['id']}','${x['name']}');
}
class Record {
  String id, personId, kind, note;
  double amount;
  DateTime date, createdAt;
  Record({required this.id,required this.personId,required this.kind,required this.amount,required this.date,required this.createdAt,this.note='' });
  Map<String,dynamic> toJson()=>{'id':id,'personId':personId,'kind':kind,'amount':amount,'date':date.toIso8601String(),'createdAt':createdAt.toIso8601String(),'note':note};
  factory Record.fromJson(Map<String,dynamic> x)=>Record(id:'${x['id']}',personId:'${x['personId']}',kind:'${x['kind']}',amount:(x['amount'] as num).toDouble(),date:DateTime.parse(x['date']),createdAt:DateTime.parse(x['createdAt']),note:'${x['note']??''}');
}
class Store {
  List<Person> people=[]; List<Record> records=[];
  Future load() async { final p=await SharedPreferences.getInstance(); final a=p.getString('people'),b=p.getString('records'); if(a!=null) people=(jsonDecode(a) as List).map((x)=>Person.fromJson(Map<String,dynamic>.from(x))).toList(); if(b!=null) records=(jsonDecode(b) as List).map((x)=>Record.fromJson(Map<String,dynamic>.from(x))).toList(); }
  Future save() async { final p=await SharedPreferences.getInstance(); await p.setString('people',jsonEncode(people.map((x)=>x.toJson()).toList())); await p.setString('records',jsonEncode(records.map((x)=>x.toJson()).toList())); }
  List<Record> of(String id)=>records.where((r)=>r.personId==id).toList()..sort((a,b)=>b.date.compareTo(a.date));
  double balance(String id){double n=0;for(final r in records.where((r)=>r.personId==id)){if(r.kind=='debt')n+=r.amount;else n-=r.amount;}return n;}
}
String money(double n)=>'${n.round()} افغانی';
String dt(DateTime d)=>DateFormat('yyyy/MM/dd').format(d);

Future<void> main() async {WidgetsFlutterBinding.ensureInitialized();runApp(const App());}

class App extends StatefulWidget{const App({super.key});@override State<App> createState()=>_AppState();}
class _AppState extends State<App>{
  final s=Store(); bool loading=true;
  @override void initState(){super.initState();s.load().then((_){setState(()=>loading=false);});}
  @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Mohasiba',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:primary),scaffoldBackgroundColor:const Color(0xFFF9F7FC)),home:Directionality(textDirection:TextDirection.rtl,child:loading?const Scaffold(body:Center(child:CircularProgressIndicator())):Home(s:s)));
}

class Home extends StatefulWidget{final Store s;const Home({super.key,required this.s});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
  String q='';
  Future addPerson()async{final c=TextEditingController();final n=await showDialog<String>(context:context,builder:(_)=>AlertDialog(title:const Text('قرض جدید'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(labelText:'نام شخص')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('لغو')),FilledButton(onPressed:()=>c.text.trim().isEmpty?null:Navigator.pop(context,c.text.trim()),child:const Text('ثبت'))]));if(n==null)return;final p=Person(DateTime.now().microsecondsSinceEpoch.toString(),n);widget.s.people.add(p);await widget.s.save();setState((){});open(p);}
  void open(Person p)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PersonPage(s:widget.s,p:p,onChanged:()=>setState((){}))));
  @override Widget build(BuildContext c){final ps=widget.s.people.where((p)=>p.name.contains(q)).toList();final me=widget.s.people.fold(0.0,(a,p)=>a+widget.s.balance(p.id));return Scaffold(appBar:AppBar(title:const Text('دفتر قرض',style:TextStyle(fontWeight:FontWeight.bold))),floatingActionButton:FloatingActionButton.extended(onPressed:addPerson,icon:const Icon(Icons.add),label:const Text('قرض جدید')),body:ListView(padding:const EdgeInsets.fromLTRB(18,8,18,100),children:[Row(children:[Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[const Text('طلب من'),Text(money(me>0?me:0),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))])))),const SizedBox(width:12),Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[const Text('بدهی من'),Text(money(me<0?-me:0),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))]))))]),const SizedBox(height:15),TextField(onChanged:(v)=>setState(()=>q=v),decoration:InputDecoration(hintText:'جستجوی نام یا توضیحات...',prefixIcon:const Icon(Icons.search),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(24),borderSide:BorderSide.none))),const SizedBox(height:15),...ps.map((p){final b=widget.s.balance(p.id);return Padding(padding:const EdgeInsets.only(bottom:12),child:Card(child:ListTile(onTap:()=>open(p),leading:CircleAvatar(backgroundColor:const Color(0xFFE6E8FF),child:Icon(b>=0?Icons.arrow_upward:Icons.arrow_downward,color:primary)),title:Text(p.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),subtitle:Text(b>0?'طلب از شخص · مانده: ${money(b)}':b<0?'بدهی به شخص · مانده: ${money(-b)}':'حساب تسویه است'),trailing:const Icon(Icons.chevron_left))));})]));}
}

class PersonPage extends StatefulWidget{final Store s;final Person p;final VoidCallback onChanged;const PersonPage({super.key,required this.s,required this.p,required this.onChanged});@override State<PersonPage> createState()=>_PersonPageState();}
class _PersonPageState extends State<PersonPage>{
  Future edit([Record? old])async{final a=TextEditingController(text:old==null?'':old.amount.round().toString()),n=TextEditingController(text:old?.note??'');var kind=old?.kind??'debt';var date=old?.date??DateTime.now();await showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(c,set)=>AlertDialog(title:Text(old==null?'رکورد جدید':'ویرایش رکورد جدید'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[Text('شخص: ${widget.p.name}'),TextField(controller:a,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ (افغانی)')),const SizedBox(height:10),SegmentedButton<String>(segments:const[ButtonSegment(value:'debt',label:Text('قرض')),ButtonSegment(value:'payment',label:Text('پرداخت')),ButtonSegment(value:'received',label:Text('من قرض گرفتم'))],selected:{kind},onSelectionChanged:(x)=>set(()=>kind=x.first)),ListTile(title:const Text('تاریخ'),subtitle:Text(dt(date)),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await showDatePicker(context:c,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null)set(()=>date=d);}),TextField(controller:n,decoration:const InputDecoration(labelText:'توضیحات (اختیاری)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('لغو')),FilledButton(onPressed:()async{final v=double.tryParse(a.text.replaceAll(',',''));if(v==null||v<=0)return;widget.s.records.add(Record(id:DateTime.now().microsecondsSinceEpoch.toString(),personId:widget.p.id,kind:kind,amount:v,date:date,createdAt:DateTime.now(),note:n.text.trim()));await widget.s.save();if(c.mounted)Navigator.pop(c);setState((){});widget.onChanged();},child:Text(old==null?'ثبت':'ثبت رکورد جدید'))]})));}
  @override Widget build(BuildContext c){final rs=widget.s.of(widget.p.id),b=widget.s.balance(widget.p.id);return Scaffold(appBar:AppBar(title:Text(widget.p.name,style:const TextStyle(fontWeight:FontWeight.bold))),floatingActionButton:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('رکورد جدید')),body:ListView(padding:const EdgeInsets.fromLTRB(18,8,18,100),children:[Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[const Text('وضعیت نهایی'),Text(b>0?'او به من بدهکار است':b<0?'من به او بدهکارم':'حساب تسویه است',style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),Text(money(b.abs()),style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold))]))),const SizedBox(height:15),...rs.map((r)=>Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(leading:CircleAvatar(child:Icon(r.kind=='debt'?Icons.arrow_upward:Icons.payments_outlined)),title:Text(r.kind=='debt'?'قرض گرفت':r.kind=='payment'?'قرض را پرداخت کرد':'من قرض گرفتم',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${dt(r.date)}${r.note.isEmpty?'':' · ${r.note}'}'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text(money(r.amount),style:const TextStyle(fontWeight:FontWeight.bold)),TextButton(onPressed:()=>edit(r),child:const Text('ویرایش'))])))]);}}
