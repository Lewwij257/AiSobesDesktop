import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const InterviewApp());
}

class InterviewApp extends StatelessWidget {
  const InterviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interview Templates',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class InterviewTemplate {
  String title;
  List<QuestionAnswer> questions = [];
  List<String>? assignedUsers; // ← Добавлено

  InterviewTemplate({required this.title, this.assignedUsers});
}

class QuestionAnswer {
  String question;
  String answer;

  QuestionAnswer({required this.question, required this.answer});
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  void _addTemplate() {
    showDialog(
      context: context,
      builder: (context) => const AddTemplateDialog(),
    );
  }

  void _showTemplateDetails(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final title = data['Title'] as String? ?? 'Без названия';
    final List<dynamic> qList = data['questions'] ?? [];
    final List<String> assigned =
        (data['assignedUsers'] as List<dynamic>?)?.cast<String>() ?? [];

    final questions = qList.map<QuestionAnswer>((q) {
      final map = q as Map<String, dynamic>;
      return QuestionAnswer(
        question: map['question'] as String? ?? '',
        answer: map['answer'] as String? ?? '',
      );
    }).toList();

    final template = InterviewTemplate(title: title, assignedUsers: assigned)
      ..questions.addAll(questions);

    showDialog(
      context: context,
      builder: (context) => TemplateDetailsDialog(
        template: template,
        interviewId: doc.id, // ← Передаём ID документа!
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AiSobes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _addTemplate,
              child: const Text('Добавить собеседование'),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('interviews')
                  .where('hrId', isEqualTo: '1')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Нет доступных собеседований'),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final title = data['Title'] as String? ?? 'Без названия';
                    final questions =
                        (data['questions'] as List<dynamic>?) ?? [];
                    final questionCount = questions.length;
                    return ListTile(
                      title: Text(title),
                      subtitle: Text(
                        'Вопросов: $questionCount • Назначено: ${data['assignedUsers']?.length ?? 0}',
                      ),
                      onTap: () => _showTemplateDetails(
                        docs[index],
                      ), // ← Теперь передаём DocumentSnapshot
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AddTemplateDialog extends StatefulWidget {
  const AddTemplateDialog({super.key});

  @override
  State<AddTemplateDialog> createState() => _AddTemplateDialogState();
}

class _AddTemplateDialogState extends State<AddTemplateDialog> {
  final _titleController = TextEditingController();
  final List<QuestionAnswer> _questions = [];

  void _addQuestion() {
    if (_questions.length >= 10) return;

    showDialog(
      context: context,
      builder: (context) => AddQuestionDialog(
        onSave: (question, answer) {
          setState(() {
            _questions.add(QuestionAnswer(question: question, answer: answer));
          });
        },
      ),
    );
  }

  void _saveTemplate() async {
    if (_titleController.text.isEmpty || _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните название и добавьте хотя бы один вопрос'),
        ),
      );
      return;
    }

    final questionsMap = _questions.map((qa) {
      return {'question': qa.question, 'answer': qa.answer};
    }).toList();

    try {
      await FirebaseFirestore.instance.collection('interviews').add({
        'Title': _titleController.text,
        'assignedUsers': <String>[],
        'createdAt': Timestamp.now(),
        'description': '',
        'hrId': '1',
        'questions': questionsMap,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Собеседование успешно сохранено!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новое собеседование'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название собеседования',
              ),
            ),
            const SizedBox(height: 20),
            ..._questions.asMap().entries.map(
              (entry) => ListTile(
                title: Text('${entry.key + 1}. ${entry.value.question}'),
                subtitle: Text(entry.value.answer),
              ),
            ),
            if (_questions.length < 10)
              TextButton(
                onPressed: _addQuestion,
                child: const Text('Добавить вопрос'),
              ),
            Text('Добавлено вопросов: ${_questions.length}/10'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _saveTemplate,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

// Остальные классы без изменений
class AddQuestionDialog extends StatefulWidget {
  final Function(String, String) onSave;

  const AddQuestionDialog({super.key, required this.onSave});

  @override
  State<AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<AddQuestionDialog> {
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();

  void _saveQuestion() {
    if (_questionController.text.isEmpty || _answerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните вопрос и эталонный ответ')),
      );
      return;
    }
    widget.onSave(_questionController.text, _answerController.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить вопрос'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(labelText: 'Вопрос'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _answerController,
            decoration: const InputDecoration(labelText: 'Эталонный ответ'),
            maxLines: 5,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(onPressed: _saveQuestion, child: const Text('Добавить')),
      ],
    );
  }
}

// Замени класс TemplateDetailsDialog на этот:
class TemplateDetailsDialog extends StatefulWidget {
  final InterviewTemplate template;
  final String interviewId; // Добавляем ID документа

  const TemplateDetailsDialog({
    super.key,
    required this.template,
    required this.interviewId,
  });

  @override
  State<TemplateDetailsDialog> createState() => _TemplateDetailsDialogState();
}

class _TemplateDetailsDialogState extends State<TemplateDetailsDialog> {
  late List<String> assignedUsers;
  final TextEditingController _userIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    assignedUsers = List.from(widget.template.assignedUsers ?? []);
  }

  void _showDeleteConfirmation(BuildContext context) {
    int countdown = 5;
    bool canConfirm = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Автоматический таймер
          if (countdown > 0) {
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                setStateDialog(() {
                  countdown--;
                  if (countdown == 0) canConfirm = true;
                });
              }
            });
          }

          return AlertDialog(
            backgroundColor: Colors.red[50],
            title: const Text(
              'Подтверждение удаления',
              style: TextStyle(color: Colors.red),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Вы собираетесь полностью удалить это собеседование.\n\n'
                  'Это действие необратимо!\n\n'
                  'Будут удалены:\n'
                  '• Само собеседование\n'
                  '• Все попытки прохождения от соискателей\n'
                  '• Все оценки и ответы',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(0, 255, 205, 210),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Подтверждение будет доступно через $countdown сек.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: countdown > 0
                          ? Colors.red[900]
                          : const Color.fromARGB(0, 248, 248, 248),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canConfirm ? Colors.red : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                onPressed: canConfirm
                    ? () {
                        Navigator.of(ctx).pop();
                        _deleteInterviewWithAttempts();
                        Navigator.of(context).pop(); // Закрываем детали
                      }
                    : null,
                child: Text(canConfirm ? 'Удалить навсегда' : 'Подождите...'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> _getUserName(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.data()?['NameAndSurname'] ?? userId;
      }
    } catch (e) {
      // ничего не делаем
    }
    return userId; // если что-то пошло не так — вернём просто ID
  }

  Future<void> _deleteInterviewWithAttempts() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // 1. Удаляем все попытки, связанные с этим interviewId
      final attemptsSnapshot = await FirebaseFirestore.instance
          .collection('attempts')
          .where('interviewId', isEqualTo: widget.interviewId)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in attemptsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 2. Удаляем само собеседование
      batch.delete(
        FirebaseFirestore.instance
            .collection('interviews')
            .doc(widget.interviewId),
      );

      // 3. Выполняем пакетное удаление
      await batch.commit();

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Собеседование и все связанные данные удалены'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  Future<void> _addUserToAssigned() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty || assignedUsers.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assignedUsers.contains(userId)
                ? 'Этот пользователь уже назначен'
                : 'Введите ID пользователя',
          ),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('interviews')
          .doc(widget.interviewId)
          .update({
            'assignedUsers': FieldValue.arrayUnion([userId]),
          });

      setState(() {
        assignedUsers.add(userId);
      });
      _userIdController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пользователь добавлен')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _removeUserFromAssigned(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('interviews')
          .doc(widget.interviewId)
          .update({
            'assignedUsers': FieldValue.arrayRemove([userId]),
          });

      setState(() {
        assignedUsers.remove(userId);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    }
  }

  Future<void> _showUserAttempt(String userId) async {
    final displayName = await _getUserName(userId); // ← получаем имя

    try {
      final attemptSnapshot = await FirebaseFirestore.instance
          .collection('attempts')
          .where('interviewId', isEqualTo: widget.interviewId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (attemptSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Попытка не найдена')));
        }
        return;
      }

      final attemptData = attemptSnapshot.docs.first.data();
      final answers = (attemptData['answers'] as List<dynamic>?) ?? [];
      final totalScore = attemptData['totalScore'] ?? '—';

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Результат: $displayName'), // ← теперь с именем!
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ответы пользователя:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ...answers.map((a) {
                  final map = a as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'В: ${map['question']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text('Ответ: ${map['answer'] ?? '—'}'),
                        Text(
                          'Ожидалось: ${map['expectedAnswer'] ?? '—'}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const Divider(),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[300]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Финальная оценка',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalScore',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Вопросы:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...widget.template.questions.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key + 1}. ${entry.value.question}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(entry.value.answer),
                      const Divider(),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),
              const Text(
                'Назначенные пользователи:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Поле ввода нового пользователя
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID пользователя',
                        hintText: 'Введите userId',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addUserToAssigned,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Список назначенных пользователей
              ...assignedUsers
                  .map(
                    (userId) => ListTile(
                      title: FutureBuilder<String>(
                        future: _getUserName(userId),
                        builder: (context, snapshot) {
                          final name = snapshot.data ?? userId;
                          return Text('$name ($userId)');
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeUserFromAssigned(userId),
                      ),
                      onTap: () => _showUserAttempt(userId),
                    ),
                  )
                  .toList(),

              if (assignedUsers.isEmpty)
                const Text(
                  'Нет назначенных пользователей',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => _showDeleteConfirmation(context),
          child: const Text(
            'Удалить собеседование',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
