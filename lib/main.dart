import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const primary = Color(0xFF5963A6);

class Person {
  String id;
  String name;

  Person(this.id, this.name);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory Person.fromJson(Map<String, dynamic> x) {
    return Person(
      '${x['id']}',
      '${x['name']}',
    );
  }
}

class Record {
  String id;
  String personId;
  String kind;
  String note;
  double amount;
  DateTime date;
  DateTime createdAt;

  Record({
    required this.id,
    required this.personId,
    required this.kind,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'kind': kind,
        'amount': amount,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory Record.fromJson(Map<String, dynamic> x) {
    return Record(
      id: '${x['id']}',
      personId: '${x['personId']}',
      kind: '${x['kind']}',
      amount: (x['amount'] as num).toDouble(),
      date: DateTime.parse('${x['date']}'),
      createdAt: DateTime.parse('${x['createdAt']}'),
      note: '${x['note'] ?? ''}',
    );
  }
}

class Store {
  List<Person> people = [];
  List<Record> records = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final peopleJson = prefs.getString('people');
    final recordsJson = prefs.getString('records');

    if (peopleJson != null) {
      people = (jsonDecode(peopleJson) as List)
          .map(
            (x) => Person.fromJson(
              Map<String, dynamic>.from(x),
            ),
          )
          .toList();
    }

    if (recordsJson != null) {
      records = (jsonDecode(recordsJson) as List)
          .map(
            (x) => Record.fromJson(
              Map<String, dynamic>.from(x),
            ),
          )
          .toList();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'people',
      jsonEncode(
        people.map((x) => x.toJson()).toList(),
      ),
    );

    await prefs.setString(
      'records',
      jsonEncode(
        records.map((x) => x.toJson()).toList(),
      ),
    );
  }

  List<Record> of(String id) {
    final result =
        records.where((r) => r.personId == id).toList();

    result.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return result;
  }

  double balance(String id) {
    double total = 0;

    for (final record in records.where((r) => r.personId == id)) {
      if (record.kind == 'debt') {
        total += record.amount;
      } else {
        total -= record.amount;
      }
    }

    return total;
  }
}

String money(double n) => '${n.round()} افغانی';

String dt(DateTime d) => DateFormat('yyyy/MM/dd').format(d);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final Store store = Store();
  bool loading = true;

  @override
  void initState() {
    super.initState();

    store.load().then((_) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mohasiba',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F7FC),
      ),
      home: Directionality(
        textDirection: TextDirection.values[1],
        child: loading
            ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : Home(s: store),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final Store s;

  const Home({
    super.key,
    required this.s,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String q = '';

  Future<void> addPerson() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('قرض جدید'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'نام شخص',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: const Text('ثبت'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name == null) return;

    final person = Person(
      DateTime.now().microsecondsSinceEpoch.toString(),
      name,
    );

    widget.s.people.add(person);
    await widget.s.save();

    if (!mounted) return;

    setState(() {});
    open(person);
  }

  void open(Person person) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonPage(
          s: widget.s,
          p: person,
          onChanged: () => setState(() {}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final persons = widget.s.people
        .where(
          (person) => person.name.contains(q),
        )
        .toList();

    final totalBalance = widget.s.people.fold<double>(
      0,
      (sum, person) => sum + widget.s.balance(person.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'دفتر قرض',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addPerson,
        icon: const Icon(Icons.add),
        label: const Text('قرض جدید'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          8,
          18,
          100,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('طلب من'),
                        Text(
                          money(
                            totalBalance > 0
                                ? totalBalance
                                : 0,
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('بدهی من'),
                        Text(
                          money(
                            totalBalance < 0
                                ? -totalBalance
                                : 0,
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            onChanged: (value) {
              setState(() {
                q = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'جستجوی نام یا توضیحات...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 15),
          ...persons.map(
            (person) {
              final balance = widget.s.balance(person.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    onTap: () => open(person),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE6E8FF),
                      child: Icon(
                        balance >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: primary,
                      ),
                    ),
                    title: Text(
                      person.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      balance > 0
                          ? 'طلب از شخص · مانده: ${money(balance)}'
                          : balance < 0
                              ? 'بدهی به شخص · مانده: ${money(-balance)}'
                              : 'حساب تسویه است',
                    ),
                    trailing: const Icon(
                      Icons.chevron_left,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PersonPage extends StatefulWidget {
  final Store s;
  final Person p;
  final VoidCallback onChanged;

  const PersonPage({
    super.key,
    required this.s,
    required this.p,
    required this.onChanged,
  });

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  Future<void> edit([Record? old]) async {
    final amountController = TextEditingController(
      text: old == null
          ? ''
          : old.amount.round().toString(),
    );

    final noteController = TextEditingController(
      text: old?.note ?? '',
    );

    var kind = old?.kind ?? 'debt';
    var date = old?.date ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                old == null
                    ? 'رکورد جدید'
                    : 'ویرایش رکورد جدید',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'شخص: ${widget.p.name}',
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText: 'مبلغ (افغانی)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'debt',
                          label: Text('قرض'),
                        ),
                        ButtonSegment(
                          value: 'payment',
                          label: Text('پرداخت'),
                        ),
                        ButtonSegment(
                          value: 'received',
                          label: Text(
                            'من قرض گرفتم',
                          ),
                        ),
                      ],
                      selected: {kind},
                      onSelectionChanged: (values) {
                        setDialogState(() {
                          kind = values.first;
                        });
                      },
                    ),
                    ListTile(
                      title: const Text('تاریخ'),
                      subtitle: Text(dt(date)),
                      trailing: const Icon(
                        Icons.calendar_month,
                      ),
                      onTap: () async {
                        final selected =
                            await showDatePicker(
                          context: dialogContext,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          setDialogState(() {
                            date = selected;
                          });
                        }
                      },
                    ),
                    TextField(
                      controller: noteController,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'توضیحات (اختیاری)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                  child: const Text('لغو'),
                ),
                FilledButton(
                  onPressed: () async {
                    final value = double.tryParse(
                      amountController.text
                          .replaceAll(',', '')
                          .trim(),
                    );

                    if (value == null || value <= 0) {
                      return;
                    }

                    // هنگام ویرایش، رکورد قبلی تغییر نمی‌کند؛
                    // یک رکورد جدید به تاریخچه اضافه می‌شود.
                    widget.s.records.add(
                      Record(
                        id: DateTime.now()
                            .microsecondsSinceEpoch
                            .toString(),
                        personId: widget.p.id,
                        kind: kind,
                        amount: value,
                        date: date,
                        createdAt: DateTime.now(),
                        note: noteController.text.trim(),
                      ),
                    );

                    await widget.s.save();

                    if (!mounted) return;

                    Navigator.pop(dialogContext);
                    setState(() {});
                    widget.onChanged();
                  },
                  child: Text(
                    old == null
                        ? 'ثبت'
                        : 'ثبت رکورد جدید',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.s.of(widget.p.id);
    final balance = widget.s.balance(widget.p.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.p.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('رکورد جدید'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          8,
          18,
          100,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('وضعیت نهایی'),
                  Text(
                    balance > 0
                        ? 'او به من بدهکار است'
                        : balance < 0
                            ? 'من به او بدهکارم'
                            : 'حساب تسویه است',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    money(balance.abs()),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          ...records.map(
            (record) {
              final title = record.kind == 'debt'
                  ? 'قرض گرفت'
                  : record.kind == 'payment'
                      ? 'قرض را پرداخت کرد'
                      : 'من قرض گرفتم';

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      record.kind == 'debt'
                          ? Icons.arrow_upward
                          : Icons.payments_outlined,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${dt(record.date)}'
                    '${record.note.isEmpty ? '' : ' · ${record.note}'}',
                  ),
                  trailing: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(record.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => edit(record),
                        child: const Text('ویرایش'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
