import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/robot_component.dart';
import '../../services/control/component_controller.dart';
import '../../shared/widgets/ui.dart';
import 'component_button.dart';

/// Lists the robot's components and lets the user add, edit and remove them.
void showComponentsEditor(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const FractionallySizedBox(heightFactor: 0.7, child: _ComponentsEditor()),
  );
}

class _ComponentsEditor extends StatelessWidget {
  const _ComponentsEditor();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ComponentController>();
    final components = controller.components;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Components', style: AppText.title.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            'Buttons for lights, horns, fans and other parts. Each one switches a digital output pin.',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: components.isEmpty
                ? Center(child: Text('No components yet.', style: AppText.caption))
                : SingleChildScrollView(
                    child: GroupedList(
                      children: [
                        for (final (i, c) in components.indexed)
                          ListRow(
                            title: c.name,
                            subtitle: 'GPIO ${c.pin} · ${c.momentary ? 'Hold' : 'Toggle'}',
                            leading: componentIcons[c.icon],
                            trailing: const Icon(Icons.chevron_right, color: AppColors.text3),
                            onTap: () => _edit(context, index: i, initial: c),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Add component',
            icon: Icons.add,
            variant: ButtonVariant.primary,
            height: 48,
            expand: true,
            onPressed: () => _edit(context),
          ),
        ],
      ),
    );
  }
}

Future<void> _edit(BuildContext context, {int? index, RobotComponent? initial}) async {
  final controller = context.read<ComponentController>();
  final result = await showModalBottomSheet<_EditResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ComponentForm(initial: initial),
  );
  switch (result) {
    case _Save(:final component):
      index == null ? controller.add(component) : controller.replace(index, component);
    case _Delete() when index != null:
      controller.remove(index);
    case _:
      break;
  }
}

sealed class _EditResult {
  const _EditResult();
}

class _Save extends _EditResult {
  const _Save(this.component);
  final RobotComponent component;
}

class _Delete extends _EditResult {
  const _Delete();
}

class _ComponentForm extends StatefulWidget {
  const _ComponentForm({this.initial});

  final RobotComponent? initial;

  @override
  State<_ComponentForm> createState() => _ComponentFormState();
}

class _ComponentFormState extends State<_ComponentForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _pin = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.pin}');
  late bool _momentary = widget.initial?.momentary ?? false;
  late ComponentIcon _icon = widget.initial?.icon ?? ComponentIcon.generic;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final pin = int.tryParse(_pin.text.trim());
    if (name.isEmpty) return setState(() => _error = 'Give it a name.');
    if (pin == null || pin < 0 || pin > 99) return setState(() => _error = 'Pin must be a number from 0 to 99.');
    Navigator.pop(context, _Save(RobotComponent(name: name, pin: pin, momentary: _momentary, icon: _icon)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? 'New component' : 'Edit component',
            style: AppText.title.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _name,
                  autofocus: widget.initial == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'Headlights'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _pin,
                  style: AppText.mono.copyWith(fontSize: 16),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'GPIO pin'),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Segmented<bool>(
            options: const {false: 'Toggle on tap', true: 'On while held'},
            value: _momentary,
            onChanged: (v) => setState(() => _momentary = v),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in componentIcons.entries)
                AppIconButton(
                  icon: e.value,
                  tooltip: e.key.name,
                  selected: e.key == _icon,
                  onTap: () => setState(() => _icon = e.key),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.initial != null) ...[
                Expanded(
                  child: AppButton(
                    label: 'Delete',
                    variant: ButtonVariant.danger,
                    height: 48,
                    expand: true,
                    onPressed: () => Navigator.pop(context, const _Delete()),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: AppButton(
                  label: 'Save',
                  variant: ButtonVariant.primary,
                  height: 48,
                  expand: true,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
