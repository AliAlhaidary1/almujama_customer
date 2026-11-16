/// Customer checkout delivery-fee label logic.
///
/// `total_delivery_charge` (the amount actually charged) is authoritative.
/// The backend's `is_free_delivery` flag means a free-delivery benefit
/// *applies* — not that the customer pays zero (a capped offer may
/// subsidize only part of the trip). "Free" may be claimed only when the
/// effective charge is actually zero.
library;

enum DeliveryFeeBadge { free, discountApplied, none }

DeliveryFeeBadge deliveryFeeBadge({
  required double fee,
  required bool isFreeDeliveryBenefit,
}) {
  if (fee <= 0) return DeliveryFeeBadge.free;
  if (isFreeDeliveryBenefit) return DeliveryFeeBadge.discountApplied;
  return DeliveryFeeBadge.none;
}

String deliveryFeeSuffix({
  required double fee,
  required bool isFreeDeliveryBenefit,
  required String Function(String key) t,
}) {
  switch (deliveryFeeBadge(fee: fee, isFreeDeliveryBenefit: isFreeDeliveryBenefit)) {
    case DeliveryFeeBadge.free:
      return ' (${t('free_delivery')})';
    case DeliveryFeeBadge.discountApplied:
      return ' (${t('delivery_discount_applied')})';
    case DeliveryFeeBadge.none:
      return '';
  }
}
