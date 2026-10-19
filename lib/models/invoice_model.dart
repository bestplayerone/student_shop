class Invoice {
  const Invoice({required this.invoiceUrl, required this.externalId});
  final String invoiceUrl;
  final String externalId;
  factory Invoice.fromMap(Map<String, dynamic> map) {
    final url = map['invoice_url'];
    final reference = map['external_id'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (!isXenditCheckoutUri(uri) ||
        reference is! String ||
        reference.trim().isEmpty) {
      throw const FormatException(
        'The payment server returned an invalid checkout link.',
      );
    }
    return Invoice(invoiceUrl: url as String, externalId: reference);
  }
}

bool isXenditCheckoutUri(Uri? uri) =>
    uri != null &&
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    uri.port == 443 &&
    {'checkout.xendit.co', 'checkout-staging.xendit.co'}.contains(uri.host);
