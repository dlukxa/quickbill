class BusinessModules {
  final bool enableProducts;
  final bool enableServices;
  final bool enableAppointments;
  final bool enableCustomOrders;

  const BusinessModules({
    this.enableProducts = true,
    this.enableServices = false,
    this.enableAppointments = false,
    this.enableCustomOrders = false,
  });

  BusinessModules copyWith({
    bool? enableProducts,
    bool? enableServices,
    bool? enableAppointments,
    bool? enableCustomOrders,
  }) {
    return BusinessModules(
      enableProducts: enableProducts ?? this.enableProducts,
      enableServices: enableServices ?? this.enableServices,
      enableAppointments: enableAppointments ?? this.enableAppointments,
      enableCustomOrders: enableCustomOrders ?? this.enableCustomOrders,
    );
  }
}
