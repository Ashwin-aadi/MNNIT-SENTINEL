import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:local_auth/local_auth.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

enum SafeFileType { pdf, photo, excel }

class SafeFile {
  final String name;
  final String path;
  final SafeFileType type;
  final int size;

  SafeFile({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
  });
}

class SafePage extends StatefulWidget {
  const SafePage({super.key});

  @override
  State<SafePage> createState() => _SafePageState();
}

class _SafePageState extends State<SafePage> {
  List<SafeFile> files = [];
  bool isLoading = false;

  final LocalAuthentication _auth = LocalAuthentication();
  enc.Key? _aesKey;
  bool _unlocked = false;

  // =========================
  // INIT
  // =========================
  @override
  void initState() {
    super.initState();
    _initSecurity();
  }

  Future<void> _initSecurity() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey('pin_hash')) {
      await _setupPin();
    }

    final ok = await _auth.authenticate(
      localizedReason: 'Unlock File Safe',
      options: const AuthenticationOptions(biometricOnly: true),
    );
    if (!ok) return;

    await _loadFiles();
  }

  // =========================
  // PIN SETUP
  // =========================
  Future<void> _setupPin() async {
    final controller = TextEditingController();
    final prefs = await SharedPreferences.getInstance();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Set File Safe PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '4–6 digit PIN'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final pin = controller.text;
              if (pin.length < 4) return;

              final salt = _randomBytes(16);
              final hash = _hash(pin, salt);

              await prefs.setString('pin_salt', base64Encode(salt));
              await prefs.setString('pin_hash', base64Encode(hash));

              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // =========================
  // VERIFY PIN + DERIVE KEY
  // =========================
  Future<void> _deriveKey() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = base64Decode(prefs.getString('pin_hash')!);
    final salt = base64Decode(prefs.getString('pin_salt')!);

    final controller = TextEditingController();
    String? pin;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Enter PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              pin = controller.text;
              Navigator.pop(context);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (pin == null || pin!.length < 4) {
      throw Exception('PIN cancelled');
    }

    final enteredHash = _hash(pin!, salt);

    if (!const ListEquality().equals(enteredHash, storedHash)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
      throw Exception('Wrong PIN');
    }

    _aesKey = enc.Key(Uint8List.fromList(enteredHash));
    _unlocked = true;
  }

  // =========================
  // HASH HELPERS
  // =========================
  List<int> _hash(String pin, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    return hmac.convert([...salt, ...utf8.encode(pin)]).bytes;
  }

  List<int> _randomBytes(int len) =>
      List.generate(len, (_) => Random.secure().nextInt(256));

  // =========================
  // STORAGE
  // =========================
  Future<Directory> _safeDir() async {
    final dir = await getApplicationSupportDirectory();
    final safe = Directory('${dir.path}/file_safe');
    if (!await safe.exists()) await safe.create(recursive: true);
    return safe;
  }

  // =========================
  // LOAD FILES
  // =========================
  Future<void> _loadFiles() async {
    setState(() => isLoading = true);
    files.clear();

    final dir = await _safeDir();
    for (final f in dir.listSync()) {
      if (f is! File || !f.path.endsWith('.enc')) continue;

      final name = f.path.split('/').last.replaceAll('.enc', '');
      final ext = name.split('.').last.toLowerCase();

      SafeFileType? type;
      if (ext == 'pdf') type = SafeFileType.pdf;
      if (['jpg', 'jpeg', 'png'].contains(ext)) type = SafeFileType.photo;
      if (['xls', 'xlsx', 'csv'].contains(ext)) type = SafeFileType.excel;

      if (type != null) {
        files.add(SafeFile(
          name: name,
          path: f.path,
          type: type,
          size: await f.length(),
        ));
      }
    }

    setState(() => isLoading = false);
  }

  // =========================
  // PICK + ENCRYPT
  // =========================
  Future<void> pickFiles() async {
    if (!_unlocked) await _deriveKey();

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    final dir = await _safeDir();
    final encrypter = enc.Encrypter(enc.AES(_aesKey!));
    final iv = enc.IV.fromLength(16);

    for (final f in result.files) {
      final bytes = await File(f.path!).readAsBytes();
      final encrypted = encrypter.encryptBytes(bytes, iv: iv);

      final out =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${f.name}.enc';
      await File(out).writeAsBytes(encrypted.bytes, flush: true);
    }

    await _loadFiles();
  }

  // =========================
  // DECRYPT → OPEN → CLEANUP
  // =========================
  Future<void> openFile(SafeFile file) async {
    try {
      if (!_unlocked) await _deriveKey();

      final iv = enc.IV.fromLength(16);
      final encrypter = enc.Encrypter(enc.AES(_aesKey!));

      final encryptedBytes = await File(file.path).readAsBytes();
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(encryptedBytes),
        iv: iv,
      );

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${file.name}';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(decrypted, flush: true);

      final mime = switch (file.type) {
        SafeFileType.pdf => 'application/pdf',
        SafeFileType.photo => 'image/*',
        SafeFileType.excel => 'application/vnd.ms-excel',
      };

      final result = await OpenFilex.open(tempPath, type: mime);

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open file')),
        );
      }

      // delete later (IMPORTANT)
      Future.delayed(const Duration(seconds: 45), () {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });
    } catch (_) {
      // already handled
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('File Safe')),
      floatingActionButton:
      FloatingActionButton(onPressed: pickFiles, child: const Icon(Icons.add)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: files.length,
        itemBuilder: (_, i) {
          final f = files[i];
          return ListTile(
            title: Text(f.name),
            subtitle: Text(f.type.name),
            onTap: () => openFile(f),
          );
        },
      ),
    );
  }
}
