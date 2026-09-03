import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import 'category_translations.dart';

extension CategoryLocalization on BuildContext {
  String getLocalizedCategory(String category) {
    final locale = Localizations.localeOf(this);
    final translated = CategoryTranslations.translate(category, locale.languageCode);
    if (translated != category) {
      return translated;
    }

    final l10n = AppLocalizations.of(this);
    if (l10n == null) return category;

    switch (category) {
      case 'Beverages': return l10n.catBeverages;
      case 'Rice & Grains': return l10n.catRiceGrains;
      case 'Dal & Pulses': return l10n.catDalPulses;
      case 'Cooking Oils & Fats': return l10n.catOilsFats;
      case 'Spices & Seasonings': return l10n.catSpicesSeasonings;
      case 'Canned & Preserved Foods': return l10n.catCannedFoods;
      case 'Snacks & Biscuits': return l10n.catSnacksBiscuits;
      case 'Confectionery & Sweets': return l10n.catConfectionerySweets;
      case 'Baby & Infant Products': return l10n.catBabyProducts;
      case 'Personal Care': return l10n.catPersonalCare;
      case 'Household Cleaning': return l10n.catHouseholdCleaning;
      case 'Stationery & Office': return l10n.catStationeryOffice;
      case 'Cigarettes & Tobacco': return l10n.catTobacco;
      case 'Firewood & Fuel': return l10n.catFuel;
      case 'Hardware & Tools': return l10n.catHardwareTools;
      case 'Farming & Garden': return l10n.catFarmingGarden;
      case 'Pet Food & Supplies': return l10n.catPetSupplies;
      case 'Electrical & Lighting': return l10n.catElectricalLighting;
      case 'Automotive': return l10n.catAutomotive;
      case 'Other': return l10n.catOther;
      default: return category;
    }
  }
}
