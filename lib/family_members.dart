import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';
import 'mqtt_rfid_service.dart';
import 'rfid_card_api.dart';
import 'mqtt_settings.dart';

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.avatarId,
    this.birthDate,
    this.gender,
  });

  final String id;
  final String name;
  final String avatarId;
  final String? birthDate;
  final String? gender;

  Map<String, String> toJson() => {
    'id': id,
    'name': name,
    'avatarId': avatarId,
    if (birthDate != null) 'birthDate': birthDate!,
    if (gender != null) 'gender': gender!,
  };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: json['id'] as String? ?? 'member-${json['name'].hashCode}',
    name: json['name'] as String? ?? '',
    avatarId: json['avatarId'] as String? ?? 'person',
    birthDate: json['birthDate'] as String?,
    gender: json['gender'] as String?,
  );

  FamilyMember copyWith({String? birthDate, String? gender}) => FamilyMember(
    id: id,
    name: name,
    avatarId: avatarId,
    birthDate: birthDate ?? this.birthDate,
    gender: gender ?? this.gender,
  );
}

class FamilyMemberStore {
  static const _key = 'family_members';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<FamilyMember>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .whereType<Map<String, dynamic>>()
          .map(FamilyMember.fromJson)
          .where((member) => member.name.isNotEmpty)
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> save(List<FamilyMember> members) => _storage.write(
    key: _key,
    value: jsonEncode(members.map((member) => member.toJson()).toList()),
  );
}

class FamilyMembersPage extends StatefulWidget {
  const FamilyMembersPage({super.key, required this.settings});
  final MqttSettings settings;
  @override
  State<FamilyMembersPage> createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> {
  final _store = FamilyMemberStore();
  List<FamilyMember>? _members;
  late final MqttRfidService _rfid;
  late final RfidCardApi _cardApi;
  Map<String, RfidCard> _cardsByMember = {};

  @override
  void initState() {
    super.initState();
    _rfid = MqttRfidService(widget.settings);
    _cardApi = RfidCardApi(widget.settings);
    _rfid.event.addListener(_handleRfidEvent);
    _loadMembers();
    _loadCards();
  }

  @override
  void dispose() {
    _rfid.event.removeListener(_handleRfidEvent);
    _rfid.dispose();
    super.dispose();
  }

  void _handleRfidEvent() {
    final event = _rfid.event.value;
    if (!mounted || event == null) return;
    if (event.type == 'bound') {
      _loadCards();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${event.memberName ?? '成員'} 的 RFID 卡已綁定')),
      );
    }
  }

  Future<void> _loadMembers() async {
    final members = await _store.load();
    if (mounted) setState(() => _members = members);
  }

  Future<void> _loadCards() async {
    final cards = await _cardApi.listCards();
    if (mounted) setState(() => _cardsByMember = {for (final card in cards) card.memberId: card});
  }

  Future<void> _addMember() async {
    final member = await showModalBottomSheet<FamilyMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => const _AddFamilyMemberSheet(),
    );
    if (member == null || !mounted) return;
    final updated = [...?_members, member];
    setState(() => _members = updated);
    await _store.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭成員'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMember,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('新增成員'),
      ),
      body: members == null
          ? const Center(child: CircularProgressIndicator())
          : members.isEmpty
          ? _EmptyFamilyMembers(onAdd: _addMember)
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 104),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: members.length,
              itemBuilder: (context, index) => _MemberCard(
                member: members[index],
                card: _cardsByMember[members[index].id],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FamilyMemberDetailsPage(
                      member: members[index],
                      card: _cardsByMember[members[index].id],
                      onSave: (updated) async {
                        final all = [...members];
                        all[index] = updated;
                        setState(() => _members = all);
                        await _store.save(all);
                      },
                    ),
                  ),
                ),
                onBind: () async {
                  final started = await _rfid.startBinding(
                    memberId: members[index].id,
                    memberName: members[index].name,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(started ? '請在 60 秒內感應 ${members[index].name} 的卡片' : '無法連線到 MQTT'),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _EmptyFamilyMembers extends StatelessWidget {
  const _EmptyFamilyMembers({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AvatarBadge(avatarId: 'home', size: 96),
          const SizedBox(height: 24),
          const Text('建立你的家庭', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            '每位成員都能用自己的名稱與專屬頭像。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新增第一位成員'),
          ),
        ],
      ),
    ),
  );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.card, required this.onTap, required this.onBind});
  final FamilyMember member;
  final RfidCard? card;
  final VoidCallback onTap;
  final VoidCallback onBind;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AvatarBadge(avatarId: member.avatarId, size: 72),
          const SizedBox(height: 14),
          Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: card == null ? AppColors.surfaceRaised : AppColors.selectionSoft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(card == null ? '尚未綁定' : 'RFID 已啟用', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: card == null ? AppColors.muted : AppColors.text)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onBind,
            icon: const Icon(Icons.nfc_rounded, size: 18),
            label: const Text('綁定卡片'),
          ),
        ],
      ),
    ),
    ),
  );
}

class _AddFamilyMemberSheet extends StatefulWidget {
  const _AddFamilyMemberSheet();

  @override
  State<_AddFamilyMemberSheet> createState() => _AddFamilyMemberSheetState();
}

class _AddFamilyMemberSheetState extends State<_AddFamilyMemberSheet> {
  final _name = TextEditingController();
  String _avatarId = familyAvatars.first.id;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '請輸入成員名稱');
      return;
    }
    Navigator.pop(
      context,
      FamilyMember(
        id: 'member-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        avatarId: _avatarId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('新增家庭成員', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('輸入名稱，並選一個喜歡的預設頭像。', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: const InputDecoration(
                labelText: '成員名稱',
                hintText: '例如：媽媽、小明',
                prefixIcon: Icon(Icons.badge_outlined),
              ).copyWith(errorText: _nameError),
            ),
            const SizedBox(height: 22),
            const Text('選擇頭像', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: familyAvatars.length,
              itemBuilder: (context, index) {
                final avatar = familyAvatars[index];
                final selected = _avatarId == avatar.id;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: avatar.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: () => setState(() => _avatarId = avatar.id),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? AppColors.text : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: _AvatarBadge(avatarId: avatar.id, size: 54),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(onPressed: _submit, child: const Text('加入家庭')),
            ),
          ],
        ),
      ),
    ),
  );
}

class FamilyMemberDetailsPage extends StatefulWidget {
  const FamilyMemberDetailsPage({super.key, required this.member, required this.card, required this.onSave});
  final FamilyMember member;
  final RfidCard? card;
  final Future<void> Function(FamilyMember) onSave;

  @override
  State<FamilyMemberDetailsPage> createState() => _FamilyMemberDetailsPageState();
}

class _FamilyMemberDetailsPageState extends State<FamilyMemberDetailsPage> {
  late String? _birthDate = widget.member.birthDate;
  late String? _gender = widget.member.gender;

  int? get _age {
    if (_birthDate == null) return null;
    final date = DateTime.tryParse(_birthDate!);
    if (date == null) return null;
    final today = DateTime.now();
    return today.year - date.year - ((today.month < date.month || (today.month == date.month && today.day < date.day)) ? 1 : 0);
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_birthDate ?? '') ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked.toIso8601String().substring(0, 10));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.member.name), actions: [
      TextButton(
        onPressed: () async {
          await widget.onSave(widget.member.copyWith(birthDate: _birthDate, gender: _gender));
          if (mounted) Navigator.pop(context);
        },
        child: const Text('儲存'),
      ),
    ]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: _AvatarBadge(avatarId: widget.member.avatarId, size: 96)),
      const SizedBox(height: 24),
      const Text('RFID 卡片', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 8),
      _DetailRow('綁定狀態', widget.card == null ? '尚未綁定' : '已綁定'),
      _DetailRow('卡號', widget.card?.uid ?? '尚未綁定'),
      const SizedBox(height: 24),
      const Text('個人資料', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.cake_outlined),
        title: const Text('出生日期'),
        subtitle: Text(_birthDate ?? '尚未填寫'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _pickBirthDate,
      ),
      _DetailRow('年齡', _age == null ? '尚未填寫出生日期' : '$_age 歲'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _gender,
        decoration: const InputDecoration(labelText: '性別', prefixIcon: Icon(Icons.person_outline)),
        items: const [
          DropdownMenuItem(value: '女性', child: Text('女性')),
          DropdownMenuItem(value: '男性', child: Text('男性')),
          DropdownMenuItem(value: '其他', child: Text('其他')),
        ],
        onChanged: (value) => setState(() => _gender = value),
      ),
    ]),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      SizedBox(width: 88, child: Text(label, style: const TextStyle(color: AppColors.muted))),
      Expanded(child: SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  );
}

class FamilyAvatar {
  const FamilyAvatar(this.id, this.label, this.icon, this.color);
  final String id, label;
  final IconData icon;
  final Color color;
}

const familyAvatars = [
  FamilyAvatar('person', '人物', Icons.face_rounded, Color(0xFF806BFF)),
  FamilyAvatar('woman', '女生', Icons.face_3_rounded, Color(0xFFFF7E9A)),
  FamilyAvatar('child', '小孩', Icons.sentiment_very_satisfied_rounded, Color(0xFFFFA63D)),
  FamilyAvatar('cat', '貓咪', Icons.pets_rounded, Color(0xFFFF9F80)),
  FamilyAvatar('dog', '小狗', Icons.cruelty_free_rounded, Color(0xFFAE7B50)),
  FamilyAvatar('rabbit', '兔子', Icons.emoji_nature_rounded, Color(0xFF8E9AAF)),
  FamilyAvatar('forest', '森林', Icons.forest_rounded, Color(0xFF52A87D)),
  FamilyAvatar('beach', '海灘', Icons.beach_access_rounded, Color(0xFF4FA8E6)),
  FamilyAvatar('sunset', '夕陽', Icons.wb_twilight_rounded, Color(0xFFE87949)),
  FamilyAvatar('home', '小屋', Icons.cottage_rounded, Color(0xFF5E9CA0)),
];

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.avatarId, required this.size});
  final String avatarId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = familyAvatars.firstWhere(
      (item) => item.id == avatarId,
      orElse: () => familyAvatars.first,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: avatar.color.withValues(alpha: .18), shape: BoxShape.circle),
      child: Icon(avatar.icon, color: avatar.color, size: size * .56),
    );
  }
}
