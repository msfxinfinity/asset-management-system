import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/admin.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../main.dart'; // To access AppTheme, AddressData, etc.

class AssetEditSheet extends StatefulWidget {
  final AppSession session;
  final Asset asset;
  final List<DepartmentFieldDefinition> fields;
  final AssetDropdowns? dropdowns;
  final List<Department> departments;
  final Future<Position?> Function() getCurrentPosition;
  final Future<AddressData?> Function(Position) getCityFromPos;

  const AssetEditSheet({
    super.key,
    required this.session,
    required this.asset,
    required this.fields,
    required this.dropdowns,
    required this.departments,
    required this.getCurrentPosition,
    required this.getCityFromPos,
  });

  @override
  State<AssetEditSheet> createState() => _AssetEditSheetState();
}

class _AssetEditSheetState extends State<AssetEditSheet> {
  late int? selectedDeptId;
  late TextEditingController nameController;
  late TextEditingController cityController;
  late TextEditingController buildingController;
  late TextEditingController floorController;
  late TextEditingController roomController;
  late TextEditingController streetController;
  late TextEditingController localityController;
  late TextEditingController postalCodeController;
  double? latitude;
  double? longitude;
  bool isUpdatingGps = false;
  final Map<String, TextEditingController> dynamicControllers = {};

  @override
  void initState() {
    super.initState();
    selectedDeptId = widget.asset.departmentId;
    nameController = TextEditingController(text: widget.asset.assetName);
    cityController = TextEditingController(text: widget.asset.city);
    buildingController = TextEditingController(text: widget.asset.building);
    floorController = TextEditingController(text: widget.asset.floor);
    roomController = TextEditingController(text: widget.asset.room);
    streetController = TextEditingController(text: widget.asset.street);
    localityController = TextEditingController(text: widget.asset.locality);
    postalCodeController = TextEditingController(text: widget.asset.postalCode);
    latitude = widget.asset.latitude;
    longitude = widget.asset.longitude;

    for (final field in widget.fields) {
      if (!_isBaseField(field.fieldKey)) {
        dynamicControllers[field.fieldKey] = TextEditingController(text: _getInitialValue(field.fieldKey));
      }
    }
  }

  bool _isBaseField(String key) {
    return {"asset_name", "city", "building", "floor", "room", "street", "locality", "postal_code", "latitude", "longitude"}.contains(key);
  }

  String _getInitialValue(String key) {
    return widget.asset.attributes[key]?.toString() ?? "";
  }

  @override
  void dispose() {
    nameController.dispose();
    cityController.dispose();
    buildingController.dispose();
    floorController.dispose();
    roomController.dispose();
    streetController.dispose();
    localityController.dispose();
    postalCodeController.dispose();
    for (var controller in dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _triggerGps() async {
    if (isUpdatingGps) return;
    setState(() => isUpdatingGps = true);
    final pos = await widget.getCurrentPosition();
    if (pos != null) {
      latitude = pos.latitude;
      longitude = pos.longitude;
      final addr = await widget.getCityFromPos(pos);
      if (addr != null && mounted) {
        setState(() {
          if (addr.city != null) cityController.text = addr.city!.toUpperCase();
          if (addr.street != null) streetController.text = addr.street!;
          if (addr.locality != null) localityController.text = addr.locality!;
          if (addr.postalCode != null) postalCodeController.text = addr.postalCode!;
        });
      }
    }
    if (mounted) setState(() => isUpdatingGps = false);
  }

  bool _isFormValid() {
    if (selectedDeptId == null) return false;
    if (nameController.text.trim().isEmpty) return false;
    if (cityController.text.trim().isEmpty) return false;
    if (buildingController.text.trim().isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Edit Asset", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(onPressed: _triggerGps, icon: Icon(Icons.my_location, color: isUpdatingGps ? Colors.blueAccent : Colors.white70)),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: selectedDeptId,
              dropdownColor: const Color(0xFF1E293B),
              items: widget.departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) => setState(() => selectedDeptId = v),
              decoration: const InputDecoration(labelText: "Department *"),
            ),
            TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Asset Name *")),
            const SizedBox(height: 8),
            _buildSearchableField("City *", cityController, widget.dropdowns?.cities ?? []),
            _buildSearchableField("Building *", buildingController, widget.dropdowns?.buildings ?? []),
            Row(children: [
              Expanded(child: _buildSearchableField("Floor", floorController, widget.dropdowns?.floors ?? [])),
              const SizedBox(width: 8),
              Expanded(child: _buildSearchableField("Room", roomController, widget.dropdowns?.rooms ?? [])),
            ]),
            const SizedBox(height: 16),
            const Text("Additional Fields", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
            for (final field in widget.fields) if (!_isBaseField(field.fieldKey))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildDynamicField(field),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isFormValid() ? _handleSave : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchableField(String label, TextEditingController ctrl, List<String> options) {
    return RawAutocomplete<String>(
      textEditingController: ctrl,
      focusNode: FocusNode(),
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return options;
        return options.where((o) => o.toLowerCase().contains(textValue.text.toLowerCase()));
      },
      onSelected: (selection) => ctrl.text = selection,
      fieldViewBuilder: (ctx, textCtrl, node, onSubmitted) {
        return TextField(
          controller: textCtrl,
          focusNode: node,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: label),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: const Color(0xFF1E293B),
            child: SizedBox(
              width: 300,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final opt = options.elementAt(i);
                  return ListTile(title: Text(opt, style: const TextStyle(color: Colors.white)), onTap: () => onSelected(opt));
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDynamicField(DepartmentFieldDefinition field) {
    List<String> options = [];
    if (field.fieldKey == "project_name") options = widget.dropdowns?.projectNames ?? [];
    else if (field.fieldKey == "asset_status") options = widget.dropdowns?.statuses ?? [];
    else if (field.fieldKey == "asset_condition") options = widget.dropdowns?.conditions ?? [];
    else options = widget.dropdowns?.customAttributes[field.fieldKey] ?? [];

    return _buildSearchableField(field.label, dynamicControllers[field.fieldKey]!, options);
  }

  void _handleSave() {
    final Map<String, dynamic> attrs = {};
    for (var entry in dynamicControllers.entries) {
      attrs[entry.key] = entry.value.text.trim();
    }

    final data = {
      "department_id": selectedDeptId,
      "asset_name": nameController.text.trim(),
      "city": cityController.text.trim().toUpperCase(),
      "building": buildingController.text.trim().toUpperCase(),
      "floor": floorController.text.trim().toUpperCase(),
      "room": roomController.text.trim().toUpperCase(),
      "street": streetController.text.trim(),
      "locality": localityController.text.trim(),
      "postal_code": postalCodeController.text.trim(),
      "latitude": latitude,
      "longitude": longitude,
      "attributes": attrs,
    };

    Navigator.pop(context, data);
  }
}
