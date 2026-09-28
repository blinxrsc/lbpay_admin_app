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
  });

  factory DeviceParameters.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => v == null ? 0.0 : double.parse(v.toString());
    int asInt(dynamic v) => v == null ? 0 : int.parse(v.toString());

    return DeviceParameters(
      washerColdPrice: asDouble(json['washer_cold_price']),
      washerWarmPrice: asDouble(json['washer_warm_price']),
      washerHotPrice: asDouble(json['washer_hot_price']),
      dryerLowPrice: asDouble(json['dryer_low_price']),
      dryerMedPrice: asDouble(json['dryer_med_price']),
      dryerHiPrice: asDouble(json['dryer_hi_price']),
      pulsePrice: asDouble(json['pulse_price']),
      pulseAddMin: asInt(json['pulse_add_min']),
      pulseWidth: asInt(json['pulse_width']),
      pulseDelay: asInt(json['pulse_delay']),
      coinSignalWidth: asInt(json['coin_signal_width']),
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
      };

  DeviceParameters copyWith({
    double? washerColdPrice,
    double? washerWarmPrice,
    double? washerHotPrice,
    double? dryerLowPrice,
    double? dryerMedPrice,
    double? dryerHiPrice,
    double? pulsePrice,
    int? pulseAddMin,
    int? pulseWidth,
    int? pulseDelay,
    int? coinSignalWidth,
  }) {
    return DeviceParameters(
      washerColdPrice: washerColdPrice ?? this.washerColdPrice,
      washerWarmPrice: washerWarmPrice ?? this.washerWarmPrice,
      washerHotPrice: washerHotPrice ?? this.washerHotPrice,
      dryerLowPrice: dryerLowPrice ?? this.dryerLowPrice,
      dryerMedPrice: dryerMedPrice ?? this.dryerMedPrice,
      dryerHiPrice: dryerHiPrice ?? this.dryerHiPrice,
      pulsePrice: pulsePrice ?? this.pulsePrice,
      pulseAddMin: pulseAddMin ?? this.pulseAddMin,
      pulseWidth: pulseWidth ?? this.pulseWidth,
      pulseDelay: pulseDelay ?? this.pulseDelay,
      coinSignalWidth: coinSignalWidth ?? this.coinSignalWidth,
    );
  }
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
  final String? otaStatus;
  final DeviceOutletInfo? outlet;
  final DeviceParameters parameters;

  DeviceDetail({
    required this.serialNumber,
    this.model,
    this.otaStatus,
    this.outlet,
    required this.parameters,
  });

  factory DeviceDetail.fromJson(Map<String, dynamic> json) {
    DeviceOutletInfo? outletInfo;
    final outletJson = json['outlet'] as Map<String, dynamic>?;
    final machineJson = json['machine'] as Map<String, dynamic>?;

    if (outletJson != null || machineJson != null) {
      outletInfo = DeviceOutletInfo(
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
      otaStatus: json['ota_status'],
      outlet: outletInfo,
      parameters: DeviceParameters.fromJson(json['parameters'] ?? {}),
    );
  }
}
