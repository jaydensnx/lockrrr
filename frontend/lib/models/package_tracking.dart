class PackageTracking {
  PackageTracking({
    required this.trackingNumber,
    required this.status,
    required this.latestLocation,
    required this.latestDescription,
    required this.deliveryDate,
  });

  final String trackingNumber;
  final String status;
  final String? latestLocation;
  final String? latestDescription;
  final String? deliveryDate;

  factory PackageTracking.fromJson(Map<String, dynamic> json) {
    return PackageTracking(
      trackingNumber: json['trackingNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Unknown',
      latestLocation: json['latestLocation']?.toString(),
      latestDescription: json['latestDescription']?.toString(),
      deliveryDate: json['deliveryDate']?.toString(),
    );
  }
}