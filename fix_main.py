import os
path = "frontend/lib/main.dart"
with open(path, "r") as f:
    content = f.read()

# Fix 1: _pickImageAndScan logic (using _resolveToken instead of undefined _onTokenScanned)
old_pick = """           if (val != null) _onTokenScanned(val);"""
new_pick = """           if (val != null) _resolveToken(val);"""

if old_pick in content:
    content = content.replace(old_pick, new_pick)
    print("Fixed _pickImageAndScan - second pass")

# Fix 2: Manual register logic around line 1791
old_man_reg = """      try {
        final res = await ApiService.fetchAssetByQr(token);
        if (!mounted) return;
        if (!res.isNew) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("QR already exists. Opening asset details...")));
        }
        await Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(session: widget.session, initialAsset: res.asset, autoOpenEdit: true)));
        _loadStats();
        _loadAssets();
      } catch (e) {"""

new_man_reg = """      try {
        final asset = await ApiService.fetchAssetByQr(token);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("QR already exists. Opening asset details...")));
        await Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(session: widget.session, initialAsset: asset)));
        _loadStats();
        _loadAssets();
      } catch (e) {"""

if old_man_reg in content:
    content = content.replace(old_man_reg, new_man_reg)
    print("Fixed manual register fetchAssetByQr usage")

with open(path, "w") as f:
    f.write(content)
