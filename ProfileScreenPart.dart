class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _isUpdating = false;

  Future<void> _changeAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked != null) {
      setState(() => _isUpdating = true);
      try {
        final bytes = await picked.readAsBytes();
        final base64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
        final updated = await ApiService.updateProfile(profilePicture: base64);
        widget.session.user = updated;
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: widget.session.user.fullName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "Full Name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (saved == true) {
      setState(() => _isUpdating = true);
      try {
        final updated = await ApiService.updateProfile(fullName: ctrl.text.trim());
        widget.session.user = updated;
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final oldPass = TextEditingController();
    final newPass = TextEditingController();
    final confirmPass = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPass, obscureText: true, decoration: const InputDecoration(labelText: "Current Password")),
            const SizedBox(height: 12),
            TextField(controller: newPass, obscureText: true, decoration: const InputDecoration(labelText: "New Password")),
            const SizedBox(height: 12),
            TextField(controller: confirmPass, obscureText: true, decoration: const InputDecoration(labelText: "Confirm New Password")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (newPass.text != confirmPass.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New passwords do not match")));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text("Update", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (saved == true) {
      setState(() => _isUpdating = true);
      try {
        await ApiService.changePassword(oldPassword: oldPass.text, newPassword: newPass.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully!")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text("My Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 32),
        Center(
          child: Stack(
            children: [
              _buildAvatar(user.profilePicture),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _isUpdating ? null : _changeAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.camera_alt, size: 20, color: const Color(0xFF1E293B)),
                  ),
                ),
              ),
              if (_isUpdating)
                const Positioned.fill(child: CircularProgressIndicator(color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                    IconButton(onPressed: _editName, icon: const Icon(Icons.edit_outlined, color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(user.email, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Chip(
                  label: Text(user.role.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  side: BorderSide.none,
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                ListTile(
                  onTap: _changePassword,
                  leading: const Icon(Icons.lock_outline, color: Colors.white70),
                  title: const Text("Change Password", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.05),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            side: const BorderSide(color: AppTheme.glassBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String? url) {
    if (url != null && url.isNotEmpty) {
      if (url.startsWith("data:image")) {
        try {
          final bytes = base64Decode(url.split(',').last);
          return CircleAvatar(radius: 60, backgroundImage: MemoryImage(bytes));
        } catch (_) {}
      }
      return CircleAvatar(radius: 60, backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.white.withOpacity(0.1),
      child: const Icon(Icons.person, size: 60, color: Colors.white),
    );
  }
}
