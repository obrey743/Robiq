/// Looks a component's button can take. Stored by name.
enum ComponentIcon { light, horn, fan, pump, gripper, laser, power, generic }

/// An extra part on the robot (lights, horn, fan, gripper…) driven from a
/// digital output pin.
class RobotComponent {
  const RobotComponent({
    required this.name,
    required this.pin,
    this.momentary = false,
    this.icon = ComponentIcon.generic,
  });

  final String name;
  final int pin;

  /// On only while the button is held (e.g. a horn), instead of toggling.
  final bool momentary;
  final ComponentIcon icon;

  /// Shown until the user sets up their own. Pin 2 is the on-board LED on
  /// most ESP32 dev boards, so "Lights" does something out of the box.
  static const defaults = [
    RobotComponent(name: 'Lights', pin: 2, icon: ComponentIcon.light),
    RobotComponent(name: 'Horn', pin: 4, momentary: true, icon: ComponentIcon.horn),
  ];

  Map<String, dynamic> toJson() => {'name': name, 'pin': pin, 'momentary': momentary, 'icon': icon.name};

  factory RobotComponent.fromJson(Map<String, dynamic> json) => RobotComponent(
    name: json['name'] as String,
    pin: json['pin'] as int,
    momentary: json['momentary'] as bool? ?? false,
    icon: ComponentIcon.values.asNameMap()[json['icon']] ?? ComponentIcon.generic,
  );
}
