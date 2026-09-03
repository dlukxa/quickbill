import 'package:flutter/material.dart';

enum AppRegion {
  sriLanka,
  india,
  maldives,
  bangladesh,
  unitedStates,
  unitedKingdom,
  eurozone,
  uae,
  saudiArabia,
  qatar,
  oman,
  kuwait,
  singapore,
  malaysia,
  australia,
  canada,
  japan,
  china,
  pakistan,
  nepal,
}

extension AppRegionExtension on AppRegion {
  String get code {
    switch (this) {
      case AppRegion.sriLanka:
        return 'LK';
      case AppRegion.india:
        return 'IN';
      case AppRegion.maldives:
        return 'MV';
      case AppRegion.bangladesh:
        return 'BD';
      case AppRegion.unitedStates:
        return 'US';
      case AppRegion.unitedKingdom:
        return 'GB';
      case AppRegion.eurozone:
        return 'EU';
      case AppRegion.uae:
        return 'AE';
      case AppRegion.saudiArabia:
        return 'SA';
      case AppRegion.qatar:
        return 'QA';
      case AppRegion.oman:
        return 'OM';
      case AppRegion.kuwait:
        return 'KW';
      case AppRegion.singapore:
        return 'SG';
      case AppRegion.malaysia:
        return 'MY';
      case AppRegion.australia:
        return 'AU';
      case AppRegion.canada:
        return 'CA';
      case AppRegion.japan:
        return 'JP';
      case AppRegion.china:
        return 'CN';
      case AppRegion.pakistan:
        return 'PK';
      case AppRegion.nepal:
        return 'NP';
    }
  }

  String get displayName {
    switch (this) {
      case AppRegion.sriLanka:
        return 'Sri Lanka (Rs. / LKR)';
      case AppRegion.india:
        return 'India (₹ / INR)';
      case AppRegion.maldives:
        return 'Maldives (Rf. / MVR)';
      case AppRegion.bangladesh:
        return 'Bangladesh (৳ / BDT)';
      case AppRegion.unitedStates:
        return 'United States (\$ / USD)';
      case AppRegion.unitedKingdom:
        return 'United Kingdom (£ / GBP)';
      case AppRegion.eurozone:
        return 'Europe (€ / EUR)';
      case AppRegion.uae:
        return 'United Arab Emirates (AED)';
      case AppRegion.saudiArabia:
        return 'Saudi Arabia (SAR)';
      case AppRegion.qatar:
        return 'Qatar (QAR)';
      case AppRegion.oman:
        return 'Oman (OMR)';
      case AppRegion.kuwait:
        return 'Kuwait (KWD)';
      case AppRegion.singapore:
        return 'Singapore (S\$ / SGD)';
      case AppRegion.malaysia:
        return 'Malaysia (RM / MYR)';
      case AppRegion.australia:
        return 'Australia (A\$ / AUD)';
      case AppRegion.canada:
        return 'Canada (CA\$ / CAD)';
      case AppRegion.japan:
        return 'Japan (¥ / JPY)';
      case AppRegion.china:
        return 'China (¥ / CNY)';
      case AppRegion.pakistan:
        return 'Pakistan (PKR)';
      case AppRegion.nepal:
        return 'Nepal (NPR)';
    }
  }

  String get currencySymbol {
    switch (this) {
      case AppRegion.sriLanka:
        return 'Rs.';
      case AppRegion.india:
        return '₹';
      case AppRegion.maldives:
        return 'Rf.';
      case AppRegion.bangladesh:
        return '৳';
      case AppRegion.unitedStates:
        return '\$';
      case AppRegion.unitedKingdom:
        return '£';
      case AppRegion.eurozone:
        return '€';
      case AppRegion.uae:
        return 'AED';
      case AppRegion.saudiArabia:
        return 'SAR';
      case AppRegion.qatar:
        return 'QAR';
      case AppRegion.oman:
        return 'OMR';
      case AppRegion.kuwait:
        return 'KWD';
      case AppRegion.singapore:
        return 'S\$';
      case AppRegion.malaysia:
        return 'RM';
      case AppRegion.australia:
        return 'A\$';
      case AppRegion.canada:
        return 'CA\$';
      case AppRegion.japan:
        return '¥';
      case AppRegion.china:
        return '¥';
      case AppRegion.pakistan:
        return 'PKR';
      case AppRegion.nepal:
        return 'NPR';
    }
  }

  String get currencyCode {
    switch (this) {
      case AppRegion.sriLanka:
        return 'LKR';
      case AppRegion.india:
        return 'INR';
      case AppRegion.maldives:
        return 'MVR';
      case AppRegion.bangladesh:
        return 'BDT';
      case AppRegion.unitedStates:
        return 'USD';
      case AppRegion.unitedKingdom:
        return 'GBP';
      case AppRegion.eurozone:
        return 'EUR';
      case AppRegion.uae:
        return 'AED';
      case AppRegion.saudiArabia:
        return 'SAR';
      case AppRegion.qatar:
        return 'QAR';
      case AppRegion.oman:
        return 'OMR';
      case AppRegion.kuwait:
        return 'KWD';
      case AppRegion.singapore:
        return 'SGD';
      case AppRegion.malaysia:
        return 'MYR';
      case AppRegion.australia:
        return 'AUD';
      case AppRegion.canada:
        return 'CAD';
      case AppRegion.japan:
        return 'JPY';
      case AppRegion.china:
        return 'CNY';
      case AppRegion.pakistan:
        return 'PKR';
      case AppRegion.nepal:
        return 'NPR';
    }
  }

  String get phonePrefix {
    switch (this) {
      case AppRegion.sriLanka:
        return '+94';
      case AppRegion.india:
        return '+91';
      case AppRegion.maldives:
        return '+960';
      case AppRegion.bangladesh:
        return '+880';
      case AppRegion.unitedStates:
        return '+1';
      case AppRegion.unitedKingdom:
        return '+44';
      case AppRegion.eurozone:
        return '+49';
      case AppRegion.uae:
        return '+971';
      case AppRegion.saudiArabia:
        return '+966';
      case AppRegion.qatar:
        return '+974';
      case AppRegion.oman:
        return '+968';
      case AppRegion.kuwait:
        return '+965';
      case AppRegion.singapore:
        return '+65';
      case AppRegion.malaysia:
        return '+60';
      case AppRegion.australia:
        return '+61';
      case AppRegion.canada:
        return '+1';
      case AppRegion.japan:
        return '+81';
      case AppRegion.china:
        return '+86';
      case AppRegion.pakistan:
        return '+92';
      case AppRegion.nepal:
        return '+977';
    }
  }
}

// Global reference for static methods and services that don't have access to Riverpod Ref.
// This is updated by AppSettingsNotifier upon initialization and when the region is changed.
AppRegion globalAppRegion = AppRegion.sriLanka;

class RegionUtils {
  static AppRegion fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'LK':
        return AppRegion.sriLanka;
      case 'IN':
        return AppRegion.india;
      case 'MV':
        return AppRegion.maldives;
      case 'BD':
        return AppRegion.bangladesh;
      case 'US':
        return AppRegion.unitedStates;
      case 'GB':
        return AppRegion.unitedKingdom;
      case 'EU':
        return AppRegion.eurozone;
      case 'AE':
        return AppRegion.uae;
      case 'SA':
        return AppRegion.saudiArabia;
      case 'QA':
        return AppRegion.qatar;
      case 'OM':
        return AppRegion.oman;
      case 'KW':
        return AppRegion.kuwait;
      case 'SG':
        return AppRegion.singapore;
      case 'MY':
        return AppRegion.malaysia;
      case 'AU':
        return AppRegion.australia;
      case 'CA':
        return AppRegion.canada;
      case 'JP':
        return AppRegion.japan;
      case 'CN':
        return AppRegion.china;
      case 'PK':
        return AppRegion.pakistan;
      case 'NP':
        return AppRegion.nepal;
      default:
        return AppRegion.sriLanka;
    }
  }
}

extension CurrencyFormatExtension on double {
  String toCurrency(AppRegion region) {
    return '${region.currencySymbol} ${toStringAsFixed(2)}';
  }
}

