class OutletSummary {
  final int id;
  final String name;
  final String? city;
  final int deviceCount;
  final int onlineCount;

  OutletSummary({
    required this.id,
    required this.name,
    this.city,
    required this.deviceCount,
    required this.onlineCount,
  });

  factory OutletSummary.fromJson(Map<String, dynamic> json) => OutletSummary(
        id: json['id'],
        name: json['name'] ?? '',
        city: json['city'],
        deviceCount: json['device_count'] ?? 0,
        onlineCount: json['online_count'] ?? 0,
      );
}

class OutletDeviceSummary {
  final String serialNumber;
  final String? machineType;
  final String? machineNum;
  final String? machineName;
  final bool isOnline;
  final bool availability;

  OutletDeviceSummary({
    required this.serialNumber,
    this.machineType,
    this.machineNum,
    this.machineName,
    required this.isOnline,
    required this.availability,
  });

  factory OutletDeviceSummary.fromJson(Map<String, dynamic> json) => OutletDeviceSummary(
        serialNumber: json['serial_number'],
        machineType: json['machine_type'],
        machineNum: json['machine_num']?.toString(),
        machineName: json['machine_name'],
        isOnline: json['is_online'] == true,
        availability: json['availability'] == true,
      );
}

class DeviceParameters {
  final double washerColdPrice;
  final double washerWarmPrice;
  final double washerHotPrice;
  final double dryerLowPrice;
  final double dryerMedPrice;
  final double dryerHiPrice;
  final double pulsePrice;
  final int pulseAddMin;
  final int pulseWidth;
  final int pulseDelay;
  final int coinSignalWidth;
  final double? maxVendPrice;
  final bool pulsePullUp;
  final bool coinSignalIdleHigh;
  final int coinSignalSensitivity;
  final bool pulseActiveLow;

  DeviceParameters({
    required this.washerColdPrice,
    required this.washerWarmPrice,
    required this.washerHotPrice,
    required this.dryerLowPrice,
    required this.dryerMedPrice,
    required this.dryerHiPrice,
    required this.pulsePrice,
    required this.pulseAddMin,
    required this.pulseWidth,
    required this.pulseDelay,
    required this.coinSignalWidth,
    this.maxVendPrice,
    required this.pulsePullUp,
    required this.coinSignalIdleHigh,
    required this.coinSignalSensitivity,
    required this.pulseActiveLow,
  });

  factory DeviceParameters.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v == null ? 0.0 : double.parse(v.toString());
    int i(dynamic v) => v == null ? 0 : int.parse(v.toString());
    return DeviceParameters(
      washerColdPrice: d(json['washer_cold_price']),
      washerWarmPrice: d(json['washer_warm_price']),
      washerHotPrice: d(json['washer_hot_price']),
      dryerLowPrice: d(json['dryer_low_price']),
      dryerMedPrice: d(json['dryer_med_price']),
      dryerHiPrice: d(json['dryer_hi_price']),
      pulsePrice: d(json['pulse_price']),
      pulseAddMin: i(json['pulse_add_min']),
      pulseWidth: i(json['pulse_width']),
      pulseDelay: i(json['pulse_delay']),
      coinSignalWidth: i(json['coin_signal_width']),
      maxVendPrice: json['max_vend_price'] == null ? null : d(json['max_vend_price']),
      pulsePullUp: json['pulse_pull_up'] == true,
      coinSignalIdleHigh: json['coin_signal_idle_high'] == true,
      coinSignalSensitivity: i(json['coin_signal_sensitivity']),
      pulseActiveLow: json['pulse_active_low'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'washer_cold_price': washerColdPrice,
        'washer_warm_price': washerWarmPrice,
        'washer_hot_price': washerHotPrice,
        'dryer_low_price': dryerLowPrice,
        'dryer_med_price': dryerMedPrice,
        'dryer_hi_price': dryerHiPrice,
        'pulse_price': pulsePrice,
        'pulse_add_min': pulseAddMin,
        'pulse_width': pulseWidth,
        'pulse_delay': pulseDelay,
        'coin_signal_width': coinSignalWidth,
        'max_vend_price': maxVendPrice,
        'pulse_pull_up': pulsePullUp,
        'coin_signal_idle_high': coinSignalIdleHigh,
        'coin_signal_sensitivity': coinSignalSensitivity,
        'pulse_active_low': pulseActiveLow,
      };
}

class DeviceOutletInfo {
  final int? outletId;
  final String? outletName;
  final String? machineType;
  final String? machineNum;
  final String? machineName;
  final bool isOnline;
  final bool availability;

  DeviceOutletInfo({
    this.outletId,
    this.outletName,
    this.machineType,
    this.machineNum,
    this.machineName,
    required this.isOnline,
    required this.availability,
  });
}

class DeviceDetail {
  final String serialNumber;
  final String? model;
  final DeviceOutletInfo? outlet;
  final DeviceParameters parameters;

  DeviceDetail({required this.serialNumber, this.model, this.outlet, required this.parameters});

  factory DeviceDetail.fromJson(Map<String, dynamic> json) {
    final outletJson = json['outlet'] as Map<String, dynamic>?;
    final machineJson = json['machine'] as Map<String, dynamic>?;
    DeviceOutletInfo? info;
    if (outletJson != null || machineJson != null) {
      info = DeviceOutletInfo(
        outletId: outletJson?['id'],
        outletName: outletJson?['name'],
        machineType: machineJson?['type'],
        machineNum: machineJson?['num']?.toString(),
        machineName: machineJson?['name'],
        isOnline: machineJson?['is_online'] == true,
        availability: machineJson?['availability'] == true,
      );
    }
    return DeviceDetail(
      serialNumber: json['serial_number'],
      model: json['model'],
      outlet: info,
      parameters: DeviceParameters.fromJson(json['parameters'] ?? {}),
    );
  }
}
